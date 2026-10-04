pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

Singleton {
    id: root

    property var notes: []
    property var todos: []
    property var trashTodos: []
    property string viewMode: "grid" // "grid" | "list"
    property string todoSortMode: "latest" // "latest" | "date"
    property bool loaded: false
    property int version: 0

    // Takeover / editing state for Notes detail view
    property var activeNote: null
    property bool isEditingNote: false

    // Takeover / editing state for Todo detail view
    property var activeTodo: null
    property bool isEditingTodo: false

    // Undo buffer
    property var lastDeletedNote: null
    property var lastDeletedTodo: null

    readonly property FileView stateFile: FileView {
        path: `${Quickshell.env("HOME")}/.local/state/caelestia/notes.json`
        watchChanges: true
        printErrors: false
        onLoaded: root.loadData(text())
    }

    readonly property FileView fallbackFile: FileView {
        path: `${Quickshell.env("HOME")}/.config/caelestia/notes.default.json`
        printErrors: false
        onLoaded: {
            // First run (no notes file yet): load the starter notes from this template.
            // A notes file that exists but is empty means the user cleared their board: leave it alone.
            if (root.notes.length === 0 && root.todos.length === 0 && stateFile.text().trim().length === 0) {
                root.loadData();
            }
        }
    }

    readonly property FileView backupFile: FileView {
        path: `${Quickshell.env("HOME")}/.local/state/caelestia/notes.json.bak`
        printErrors: false
    }

    Timer {
        id: saveDebounceTimer
        interval: 400
        repeat: false
        onTriggered: root.flushSave()
    }

    property int minuteTick: 0

    Timer {
        id: repeatingRolloverTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root.checkRepeatingRollover();
            root.minuteTick++;
        }
    }

    function loadData(content) {
        let raw = content !== undefined ? content : (stateFile ? stateFile.text() : "");
        let loadedNotes = null;
        let loadedTodos = null;
        let loadedTrash = null;
        let loadedMode = "grid";
        let loadedSortMode = "latest";

        let hadMissingShape = false;
        const todayStr = root.getTodayString();
        function ensureTaskShape(item) {
            if (!item) return item;
            let copy = item;
            if (item.shapeIndex === undefined || typeof item.shapeIndex !== "number") {
                const str = String(item.id || item.title || "todo");
                let hash = 0;
                for (let i = 0; i < str.length; i++) {
                    hash = ((hash << 5) - hash) + str.charCodeAt(i);
                    hash |= 0;
                }
                copy = Object.assign({}, copy);
                copy.shapeIndex = Math.abs(hash);
                hadMissingShape = true;
            }
            if (copy.repeating && copy.done && copy.lastCompletedDate && copy.lastCompletedDate !== todayStr) {
                copy = Object.assign({}, copy);
                copy.done = false;
                hadMissingShape = true;
            }
            return copy;
        }

        if (raw && typeof raw === "string" && raw.trim().length > 0) {
            try {
                const data = JSON.parse(raw);
                if (data && typeof data === "object") {
                    if (Array.isArray(data.notes)) loadedNotes = data.notes;
                    if (Array.isArray(data.todos)) loadedTodos = data.todos.map(ensureTaskShape);
                    if (Array.isArray(data.trashTodos)) loadedTrash = data.trashTodos.map(ensureTaskShape);
                    if (data.settings) {
                        if (data.settings.viewMode) loadedMode = data.settings.viewMode;
                        if (data.settings.todoSortMode) loadedSortMode = data.settings.todoSortMode;
                    }
                }
            } catch (e) {
                console.warn("[NotesStore] Failed to parse notes.json, attempting fallback:", e);
            }
        }

        // Auto-heal / fallback from notes.default.json
        if ((!loadedNotes || !loadedTodos) && fallbackFile) {
            try {
                const fbText = fallbackFile.text();
                if (fbText && fbText.trim().length > 0) {
                    const fbData = JSON.parse(fbText);
                    if (fbData && typeof fbData === "object") {
                        if (!loadedNotes && Array.isArray(fbData.notes)) loadedNotes = fbData.notes;
                        if (!loadedTodos && Array.isArray(fbData.todos)) loadedTodos = fbData.todos;
                        if (!loadedTrash && Array.isArray(fbData.trashTodos)) loadedTrash = fbData.trashTodos;
                        if (fbData.settings) {
                            if (fbData.settings.viewMode) loadedMode = fbData.settings.viewMode;
                            if (fbData.settings.todoSortMode) loadedSortMode = fbData.settings.todoSortMode;
                        }
                        console.info("[NotesStore] Auto-recovered notes/todos from notes.default.json");
                    }
                }
            } catch (e) {
                console.warn("[NotesStore] Failed to load fallback data:", e);
            }
        }

        root.notes = loadedNotes || [];
        root.todos = loadedTodos || [];
        root.trashTodos = loadedTrash || [];
        root.viewMode = loadedMode || "grid";
        root.todoSortMode = loadedSortMode || "latest";
        root.loaded = true;
        root.version++;
        root.checkRepeatingRollover();
        if (hadMissingShape) root.requestSave();
    }

    function requestSave() {
        if (saveDebounceTimer.running) {
            saveDebounceTimer.restart();
        } else {
            saveDebounceTimer.start();
        }
    }

    function flushSave() {
        if (!stateFile) return;
        saveDebounceTimer.stop();

        const currentText = stateFile.text();
        if (backupFile && currentText && currentText.trim().length > 0) {
            backupFile.setText(currentText);
        }

        const payload = {
            "notes": root.notes,
            "todos": root.todos,
            "trashTodos": root.trashTodos,
            "settings": {
                "viewMode": root.viewMode,
                "todoSortMode": root.todoSortMode
            }
        };

        stateFile.setText(JSON.stringify(payload, null, 2));
        root.version++;
    }

    // ==========================================
    // NOTES API
    // ==========================================

    function getPinnedNotes() {
        root.version;
        if (!root.notes) return [];
        return root.notes.filter(n => n && n.pinned);
    }

    function getOtherNotes() {
        root.version;
        if (!root.notes) return [];
        return root.notes.filter(n => n && !n.pinned);
    }

    function addNote(title, body, pinned, color, listShapes) {
        const now = Date.now();
        const newNote = {
            "id": "note_" + now + "_" + Math.floor(Math.random() * 1000),
            "title": title || "",
            "body": body || "",
            "pinned": !!pinned,
            "color": color || "none",
            "listShapes": listShapes || {},
            "type": "note",
            "createdAt": now,
            "updatedAt": now
        };

        const updated = Array.from(root.notes || []);
        updated.unshift(newNote);
        root.notes = updated;
        root.flushSave();
        return newNote;
    }

    function updateNote(id, title, body, pinned, color, listShapes) {
        if (!id) return false;
        let found = false;
        const now = Date.now();
        const updated = (root.notes || []).map(n => {
            if (n && n.id === id) {
                found = true;
                const copy = Object.assign({}, n);
                if (title !== undefined) copy.title = title;
                if (body !== undefined) copy.body = body;
                if (pinned !== undefined) copy.pinned = !!pinned;
                if (color !== undefined) copy.color = color;
                if (listShapes !== undefined) copy.listShapes = listShapes;
                copy.updatedAt = now;
                return copy;
            }
            return n;
        });

        if (found) {
            root.notes = updated;
            if (root.activeNote && root.activeNote.id === id) {
                const activeCopy = Object.assign({}, root.activeNote);
                if (title !== undefined) activeCopy.title = title;
                if (body !== undefined) activeCopy.body = body;
                if (pinned !== undefined) activeCopy.pinned = !!pinned;
                if (color !== undefined) activeCopy.color = color;
                if (listShapes !== undefined) activeCopy.listShapes = listShapes;
                activeCopy.updatedAt = now;
                root.activeNote = activeCopy;
            }
            root.requestSave();
            return true;
        }
        return false;
    }

    function togglePin(id) {
        if (!id) return false;
        let found = false;
        const updated = (root.notes || []).map(n => {
            if (n && n.id === id) {
                found = true;
                const copy = Object.assign({}, n);
                copy.pinned = !copy.pinned;
                copy.updatedAt = Date.now();
                return copy;
            }
            return n;
        });

        if (found) {
            root.notes = updated;
            root.flushSave();
            return true;
        }
        return false;
    }

    function deleteNote(id) {
        if (!id) return false;
        const target = (root.notes || []).find(n => n && n.id === id);
        if (!target) return false;

        root.lastDeletedNote = target;
        root.notes = (root.notes || []).filter(n => n && n.id !== id);
        if (root.activeNote && root.activeNote.id === id) {
            root.activeNote = null;
            root.isEditingNote = false;
        }
        root.flushSave();
        return true;
    }

    function openNote(note) {
        root.activeNote = note;
        root.isEditingNote = true;
    }

    function createAndOpenNewNote() {
        const newNote = addNote("", "", false, "none");
        openNote(newNote);
        return newNote;
    }

    function closeNote(autosave, directTitle, directBody, directShapes) {
        if (!root.activeNote) {
            root.isEditingNote = false;
            return;
        }

        const noteId = root.activeNote.id;

        // Apply direct values if provided
        if (directTitle !== undefined || directBody !== undefined || directShapes !== undefined) {
            root.updateNote(noteId, directTitle, directBody, root.activeNote.pinned, root.activeNote.color, directShapes !== undefined ? directShapes : root.activeNote.listShapes);
        }

        // Check the latest saved state in root.notes
        const target = (root.notes || []).find(n => n && n.id === noteId) || root.activeNote;
        const finalTitle = ((target && target.title !== undefined) ? target.title : (directTitle || "")).trim();
        const finalBody = ((target && target.body !== undefined) ? target.body : (directBody || "")).trim();

        // Discard ONLY if BOTH title AND description are completely blank!
        // If EITHER title OR description has content, SAVE IT!
        if (finalTitle.length === 0 && finalBody.length === 0) {
            root.notes = (root.notes || []).filter(n => n && n.id !== noteId);
            root.flushSave();
        } else {
            root.flushSave();
        }

        root.activeNote = null;
        root.isEditingNote = false;
    }

    function setViewMode(mode) {
        if (mode === "grid" || mode === "list") {
            root.viewMode = mode;
            root.requestSave();
        }
    }

    function toggleViewMode() {
        root.setViewMode(root.viewMode === "grid" ? "list" : "grid");
    }

    // ==========================================
    // TODOS API
    // ==========================================

    function getTodos() {
        root.version;
        if (!root.todos) return [];
        return root.todos.filter(t => t && !t.done);
    }

    function getActiveTodos() {
        return root.getTodos();
    }

    // Returns active todos sorted according to the current todoSortMode:
    //   "latest"  → newest createdAt first (default insertion order)
    //   "date"    → overdue → today → tomorrow → in N days (asc) → no date
    function getSortedTodos() {
        root.version;
        const base = root.getTodos();
        if (root.todoSortMode === "date") {
            const now = new Date();
            const todayMs = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();

            function dueBucket(t) {
                const due = t && t.due ? t.due.trim() : "";
                if (!due || due === "none" || due === "") return 999999; // no date → last
                const clean = due.toLowerCase();
                if (clean === "overdue") return -1;
                if (clean === "today") return 0;
                if (clean === "tomorrow") return 1;
                const parts = due.split("-");
                let target;
                if (parts.length === 3) {
                    target = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
                } else {
                    target = new Date(due);
                }
                if (!target || isNaN(target.getTime())) return 999999;
                const targetMs = new Date(target.getFullYear(), target.getMonth(), target.getDate()).getTime();
                const diffDays = Math.round((targetMs - todayMs) / 86400000);
                if (diffDays < 0) return -1;   // overdue
                return diffDays;               // 0 = today, 1 = tomorrow, N = in N days
            }

            return base.slice().sort((a, b) => {
                const da = dueBucket(a);
                const db = dueBucket(b);
                if (da !== db) return da - db;
                // secondary: newest createdAt first within same bucket
                return (b.createdAt || 0) - (a.createdAt || 0);
            });
        }
        // "latest": sort by createdAt descending (newest first)
        return base.slice().sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
    }

    function toggleTodoSort() {
        root.todoSortMode = root.todoSortMode === "latest" ? "date" : "latest";
        root.version++;
        root.requestSave();
    }

    function getRemainingTodosCount() {
        root.version;
        if (!root.todos) return 0;
        return root.todos.filter(t => t && !t.done).length;
    }

    function getRepeatingTrashTodos() {
        root.version;
        return (root.todos || []).filter(t => t && t.done && t.repeating);
    }

    function getGeneralTrashTodos() {
        root.version;
        const generalCompleted = (root.todos || []).filter(t => t && t.done && !t.repeating);
        const trashed = root.trashTodos || [];
        return generalCompleted.concat(trashed);
    }

    function getCompletedAndTrashTodos() {
        return root.getRepeatingTrashTodos().concat(root.getGeneralTrashTodos());
    }

    function getTrashCount() {
        root.version;
        return root.getCompletedAndTrashTodos().length;
    }

    function getGeneralTrashCount() {
        root.version;
        return root.getGeneralTrashTodos().length;
    }

    function getResettingTimeText() {
        root.minuteTick;
        root.version;
        const now = new Date();
        const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0);
        const diffMs = midnight.getTime() - now.getTime();
        const diffHours = Math.floor(diffMs / 3600000);
        const diffMins = Math.floor((diffMs % 3600000) / 60000);
        if (diffHours > 0) {
            return qsTr(`Resetting in ${diffHours}h`);
        }
        return qsTr(`Resetting in ${Math.max(1, diffMins)}m`);
    }

    function getRestingTimeText() {
        return root.getResettingTimeText();
    }

    function checkRepeatingRollover() {
        const todayStr = root.getTodayString();
        let changed = false;
        const updated = (root.todos || []).map(t => {
            if (t && t.repeating && t.done) {
                if (!t.lastCompletedDate || t.lastCompletedDate !== todayStr) {
                    const copy = Object.assign({}, t);
                    copy.done = false;
                    changed = true;
                    return copy;
                }
            }
            return t;
        });
        if (changed) {
            root.todos = updated;
            root.flushSave();
            root.version++;
        }
    }

    function addTodo(title, due, repeating) {
        const cleanTitle = (title || "").trim().slice(0, 300);
        if (cleanTitle.length === 0) return null;

        const now = Date.now();
        const newTodo = {
            "id": "todo_" + now + "_" + Math.floor(Math.random() * 1000),
            "title": cleanTitle,
            "done": false,
            "due": due || "",
            "repeating": !!repeating,
            "streak": 0,
            "lastCompletedDate": "",
            "type": "task",
            "createdAt": now,
            "shapeIndex": Math.floor(Math.random() * 1000)
        };

        const updated = Array.from(root.todos || []);
        updated.unshift(newTodo);
        root.todos = updated;
        root.flushSave();
        return newTodo;
    }

    function toggleTodo(id) {
        if (!id) return false;
        let found = false;
        const todayStr = root.getTodayString();
        const updated = (root.todos || []).map(t => {
            if (t && t.id === id) {
                found = true;
                const copy = Object.assign({}, t);
                const nextDone = !copy.done;
                copy.done = nextDone;
                if (copy.repeating) {
                    if (nextDone) {
                        if (copy.lastCompletedDate !== todayStr) {
                            copy.streak = (copy.streak || 0) + 1;
                            copy.lastCompletedDate = todayStr;
                        }
                    }
                }
                return copy;
            }
            return t;
        });

        if (found) {
            root.todos = updated;
            root.flushSave();
            return true;
        }
        return false;
    }

    function updateTodo(id, title, due, repeating) {
        if (!id) return false;
        let found = false;
        const updated = (root.todos || []).map(t => {
            if (t && t.id === id) {
                found = true;
                const copy = Object.assign({}, t);
                if (title !== undefined) copy.title = title.slice(0, 300);
                if (due !== undefined) copy.due = due;
                if (repeating !== undefined) copy.repeating = !!repeating;
                return copy;
            }
            return t;
        });

        if (found) {
            root.todos = updated;
            if (root.activeTodo && root.activeTodo.id === id) {
                root.activeTodo = Object.assign({}, root.activeTodo, {
                    title: title !== undefined ? title.slice(0, 300) : root.activeTodo.title,
                    due: due !== undefined ? due : root.activeTodo.due,
                    repeating: repeating !== undefined ? !!repeating : root.activeTodo.repeating
                });
            }
            root.flushSave();
            return true;
        }
        return false;
    }

    function deleteTodo(id) {
        if (!id) return false;
        const target = (root.todos || []).find(t => t && t.id === id);
        if (!target) return false;

        const trashedItem = Object.assign({}, target, {
            done: true,
            deletedAt: Date.now()
        });

        const updatedTrash = Array.from(root.trashTodos || []);
        updatedTrash.unshift(trashedItem);
        root.trashTodos = updatedTrash;

        root.lastDeletedTodo = target;
        root.todos = (root.todos || []).filter(t => t && t.id !== id);
        if (root.activeTodo && root.activeTodo.id === id) {
            root.activeTodo = null;
            root.isEditingTodo = false;
        }
        root.flushSave();
        return true;
    }

    function openTodo(todo) {
        root.activeTodo = todo;
        root.isEditingTodo = true;
    }

    function closeTodo(autosave) {
        if (!root.activeTodo) {
            root.isEditingTodo = false;
            return;
        }
        if (autosave) {
            root.flushSave();
        }
        root.activeTodo = null;
        root.isEditingTodo = false;
    }

    function getTodayString() {
        const d = new Date();
        const y = d.getFullYear();
        const m = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1);
        const day = (d.getDate() < 10 ? "0" : "") + d.getDate();
        return y + "-" + m + "-" + day;
    }

    function getOffsetDateString(days) {
        const d = new Date();
        d.setDate(d.getDate() + days);
        const y = d.getFullYear();
        const m = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1);
        const day = (d.getDate() < 10 ? "0" : "") + d.getDate();
        return y + "-" + m + "-" + day;
    }

    function formatDuePill(dueStr) {
        if (!dueStr || typeof dueStr !== "string" || dueStr.trim().length === 0 || dueStr === "none") {
            return null;
        }

        const clean = dueStr.trim().toLowerCase();
        if (clean === "today") return { label: qsTr("Today"), status: "today" };
        if (clean === "tomorrow") return { label: qsTr("Tomorrow"), status: "tomorrow" };
        if (clean === "overdue") return { label: qsTr("Overdue"), status: "overdue" };

        let target = null;
        const parts = dueStr.split("-");
        if (parts.length === 3) {
            target = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
        } else {
            target = new Date(dueStr);
        }

        if (!target || isNaN(target.getTime())) {
            return { label: dueStr, status: "upcoming" };
        }

        const now = new Date();
        const todayMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const targetMidnight = new Date(target.getFullYear(), target.getMonth(), target.getDate()).getTime();
        const diffMs = targetMidnight - todayMidnight;
        const diffDays = Math.round(diffMs / 86400000);

        if (diffDays < 0) {
            return { label: qsTr("Overdue"), status: "overdue" };
        } else if (diffDays === 0) {
            return { label: qsTr("Today"), status: "today" };
        } else if (diffDays === 1) {
            return { label: qsTr("Tomorrow"), status: "tomorrow" };
        } else {
            return { label: qsTr("in " + diffDays + " days"), status: "upcoming" };
        }
    }

    function restoreTodo(id) {
        if (!id) return false;
        // Check if in trashTodos
        const inTrash = (root.trashTodos || []).find(t => t && t.id === id);
        if (inTrash) {
            const restored = Object.assign({}, inTrash, {
                done: false
            });
            delete restored.deletedAt;
            root.trashTodos = (root.trashTodos || []).filter(t => t && t.id !== id);
            const updated = Array.from(root.todos || []);
            updated.unshift(restored);
            root.todos = updated;
            root.flushSave();
            return true;
        }

        // Check if in todos (completed)
        const inTodos = (root.todos || []).find(t => t && t.id === id);
        if (inTodos) {
            root.todos = (root.todos || []).map(t => {
                if (t && t.id === id) {
                    const copy = Object.assign({}, t);
                    copy.done = false;
                    return copy;
                }
                return t;
            });
            root.flushSave();
            return true;
        }
        return false;
    }

    function permanentlyDeleteTodo(id) {
        if (!id) return false;
        root.trashTodos = (root.trashTodos || []).filter(t => t && t.id !== id);
        root.todos = (root.todos || []).filter(t => t && t.id !== id);
        root.flushSave();
        return true;
    }

    function emptyAllTrash() {
        root.trashTodos = [];
        // Keep active todos AND completed repeating todos. Only purge completed non-repeating todos.
        root.todos = (root.todos || []).filter(t => !t.done || t.repeating);
        root.flushSave();
        return true;
    }
}
