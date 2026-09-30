pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    readonly property list<int> morphShapeList: [
        MaterialShape.Cookie4Sided,
        MaterialShape.Cookie6Sided,
        MaterialShape.Cookie9Sided,
        MaterialShape.Cookie12Sided,
        MaterialShape.Clover4Leaf,
        MaterialShape.Sunny,
        MaterialShape.VerySunny,
        MaterialShape.SoftBurst,
        MaterialShape.Ghostish,
        MaterialShape.Gem,
        MaterialShape.Pentagon,
        MaterialShape.Diamond,
        MaterialShape.Oval,
        MaterialShape.Pill,
        MaterialShape.Slanted
    ]

    function getTaskShape(task): int {
        if (!task) return morphShapeList[0];
        let idx = 0;
        if (task.shapeIndex !== undefined && typeof task.shapeIndex === "number") {
            idx = Math.abs(task.shapeIndex);
        } else {
            const str = String(task.id || task.title || "todo");
            let hash = 0;
            for (let i = 0; i < str.length; i++) {
                hash = ((hash << 5) - hash) + str.charCodeAt(i);
                hash |= 0;
            }
            idx = Math.abs(hash);
        }
        return morphShapeList[idx % morphShapeList.length];
    }

    readonly property int taskShape: getTaskShape(root.activeTodo)

    readonly property var activeTodo: NotesStore.activeTodo
    readonly property int maxTitleLength: 300

    property string localTitle: ""
    property string localDue: ""
    property bool localDone: false
    property bool localRepeating: false
    property bool calendarOpen: false
    property bool confirmDelete: false

    Timer {
        id: confirmDeleteTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmDelete = false
    }

    property string currentTodoId: ""

    onActiveTodoChanged: {
        confirmDeleteTimer.stop();
        confirmDelete = false;
        if (activeTodo) {
            const newId = activeTodo.id || "";
            if (newId !== currentTodoId) {
                currentTodoId = newId;
                localTitle = activeTodo.title || "";
                localDue = activeTodo.due || "";
                localDone = !!activeTodo.done;
                localRepeating = !!activeTodo.repeating;
                if (todoTextArea) {
                    todoTextArea.text = localTitle;
                    todoTextArea.cursorPosition = todoTextArea.length;
                }
            } else {
                localDue = activeTodo.due || "";
                localDone = !!activeTodo.done;
                localRepeating = !!activeTodo.repeating;
            }
        } else {
            currentTodoId = "";
        }
    }

    Component.onCompleted: {
        confirmDeleteTimer.stop();
        confirmDelete = false;
        if (activeTodo) {
            currentTodoId = activeTodo.id || "";
            localTitle = activeTodo.title || "";
            localDue = activeTodo.due || "";
            localDone = !!activeTodo.done;
            localRepeating = !!activeTodo.repeating;
            if (todoTextArea) {
                todoTextArea.text = localTitle;
                todoTextArea.cursorPosition = todoTextArea.length;
            }
        }
    }

    Timer {
        id: autoSyncTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (root.activeTodo) {
                NotesStore.updateTodo(root.activeTodo.id, root.localTitle, root.localDue, root.localRepeating);
            }
        }
    }

    function syncNow() {
        autoSyncTimer.stop();
        if (root.activeTodo) {
            NotesStore.updateTodo(root.activeTodo.id, root.localTitle, root.localDue, root.localRepeating);
        }
    }

    function handleBack() {
        confirmDeleteTimer.stop();
        confirmDelete = false;
        syncNow();
        root.calendarOpen = false;
        NotesStore.closeTodo(true);
    }

    readonly property var currentDuePill: NotesStore.formatDuePill(root.localDue)

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        // Header Row: Back button, status checkbox, title, delete button
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconButton {
                icon: "arrow_back"
                type: ButtonBase.Tonal
                onClicked: root.handleBack()
            }

            // Checkbox status toggle with M3Shapes Morphing Animation
            CustomMouseArea {
                id: detailCheckMouse
                implicitWidth: 24
                implicitHeight: 24
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.activeTodo) {
                        root.localDone = !root.localDone;
                        NotesStore.toggleTodo(root.activeTodo.id);
                    }
                }

                MaterialShape {
                    id: detailCheckShape
                    anchors.centerIn: parent
                    implicitSize: 18

                    shape: root.localDone ? root.taskShape : MaterialShape.Square

                    color: root.localDone ? Colours.palette.m3primary : "transparent"
                    strokeColor: root.localDone ? Colours.palette.m3primary : (detailCheckMouse.containsMouse ? Colours.palette.m3primary : Colours.palette.m3outline)
                    strokeWidth: root.localDone ? 0 : 1.5

                    scale: detailCheckMouse.pressed ? 0.88 : (detailCheckMouse.containsMouse ? 1.08 : 1.0)

                    animationEasing: Tokens.anim.expressiveDefaultSpatial
                    animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

                    Behavior on color {
                        CAnim {}
                    }

                    Behavior on strokeColor {
                        CAnim {}
                    }

                    Behavior on scale {
                        Anim { type: Anim.FastSpatial }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "check"
                        fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3onPrimary
                        visible: opacity > 0
                        opacity: root.localDone ? 1 : 0
                        scale: root.localDone ? 1.0 : 0.4

                        Behavior on opacity {
                            Anim { type: Anim.FastEffects }
                        }

                        Behavior on scale {
                            Anim { type: Anim.DefaultSpatial }
                        }
                    }
                }
            }

            StyledText {
                text: root.localDone ? qsTr("Completed") : qsTr("Task Details")
                font: Tokens.font.title.small
                color: root.localDone ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: root.confirmDelete ? "check" : "delete"
                type: root.confirmDelete ? ButtonBase.Filled : ButtonBase.Tonal
                activeColour: root.confirmDelete ? Colours.palette.m3error : Colours.palette.m3secondary
                inactiveColour: root.confirmDelete ? Colours.palette.m3error : Colours.palette.m3secondaryContainer
                activeOnColour: root.confirmDelete ? Colours.palette.m3onError : Colours.palette.m3onSecondary
                inactiveOnColour: root.confirmDelete ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                onClicked: {
                    if (!root.confirmDelete) {
                        root.confirmDelete = true;
                        confirmDeleteTimer.restart();
                    } else {
                        confirmDeleteTimer.stop();
                        root.confirmDelete = false;
                        if (root.activeTodo) {
                            NotesStore.deleteTodo(root.activeTodo.id);
                        }
                    }
                }
            }
        }

        // Thin divider
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.5
        }

        // Due date / Repeat row
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: root.localRepeating ? "repeat" : "event"
                fontStyle: Tokens.font.icon.small
                color: root.localRepeating ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                text: root.localRepeating ? qsTr("Repeat:") : qsTr("Due:")
                font: Tokens.font.label.medium
                color: root.localRepeating ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
            }


            // Active Due Pill (if set and not repeating)
            StyledRect {
                visible: !root.localRepeating && root.currentDuePill !== null
                radius: Tokens.rounding.full
                implicitHeight: 20
                implicitWidth: currentDueText.implicitWidth + 12
                color: {
                    if (!root.currentDuePill) return Colours.palette.m3surfaceContainerHigh;
                    switch (root.currentDuePill.status) {
                        case "overdue": return Colours.palette.m3error;
                        case "today": return Colours.palette.m3tertiary;
                        case "tomorrow": return Colours.palette.m3secondaryContainer;
                        default: return Colours.palette.m3surfaceContainerHighest;
                    }
                }

                StyledText {
                    id: currentDueText
                    anchors.centerIn: parent
                    text: root.currentDuePill ? root.currentDuePill.label : ""
                    font: Tokens.font.label.small
                    color: {
                        if (!root.currentDuePill) return Colours.palette.m3onSurfaceVariant;
                        switch (root.currentDuePill.status) {
                            case "overdue": return Colours.palette.m3onError;
                            case "today": return Colours.palette.m3onTertiary;
                            case "tomorrow": return Colours.palette.m3onSecondaryContainer;
                            default: return Colours.palette.m3onSurface;
                        }
                    }
                }
            }

            IconButton {
                icon: root.calendarOpen ? "expand_less" : "calendar_month"
                type: root.calendarOpen ? ButtonBase.Filled : ButtonBase.Text
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                opacity: root.localRepeating ? 0.35 : 1.0
                onClicked: {
                    if (root.localRepeating) {
                        root.localRepeating = false;
                    }
                    root.calendarOpen = !root.calendarOpen;
                }

                Behavior on opacity {
                    Anim { type: Anim.FastEffects }
                }
            }

            // Repeat toggle button
            IconButton {
                icon: "repeat"
                type: root.localRepeating ? ButtonBase.Filled : ButtonBase.Tonal
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                opacity: (root.calendarOpen || root.localDue.length > 0) ? 0.35 : 1.0
                onClicked: {
                    root.localRepeating = !root.localRepeating;
                    if (root.localRepeating) {
                        root.localDue = "";
                        root.calendarOpen = false;
                    }
                    autoSyncTimer.restart();
                }

                Behavior on opacity {
                    Anim { type: Anim.FastEffects }
                }
            }

            Item { Layout.fillWidth: true }

            // Character count badge (current/300)
            StyledRect {
                radius: Tokens.rounding.full
                implicitHeight: 20
                implicitWidth: charCountText.implicitWidth + 14
                color: {
                    const len = todoTextArea ? todoTextArea.length : (root.localTitle ? root.localTitle.length : 0);
                    if (len >= root.maxTitleLength) return Qt.alpha(Colours.palette.m3error, 0.22);
                    if (len >= root.maxTitleLength - 30) return Qt.alpha(Colours.palette.m3tertiary, 0.22);
                    return Colours.palette.m3surfaceContainerHigh;
                }

                Behavior on color {
                    CAnim {}
                }

                StyledText {
                    id: charCountText
                    anchors.centerIn: parent
                    text: `${todoTextArea ? todoTextArea.length : (root.localTitle ? root.localTitle.length : 0)}/${root.maxTitleLength}`
                    font: Tokens.font.label.small
                    color: {
                        const len = todoTextArea ? todoTextArea.length : (root.localTitle ? root.localTitle.length : 0);
                        if (len >= root.maxTitleLength) return Colours.palette.m3error;
                        if (len >= root.maxTitleLength - 30) return Colours.palette.m3tertiary;
                        return Colours.palette.m3onSurfaceVariant;
                    }

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }

        // Thin divider
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.35
        }

        // Content Area: Calendar Takeover OR Description TextArea
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // When picking date: Full-size 1:1 Dashboard Calendar Takeover
            TodoDatePicker {
                anchors.fill: parent
                visible: root.calendarOpen
                currentDateStr: root.localDue
                onDateSelected: (dateStr) => {
                    root.localDue = (root.localDue === dateStr ? "" : dateStr);
                    root.localRepeating = false;
                    root.syncNow();
                }
                onCancelled: {
                    root.calendarOpen = false;
                }
            }

            // Scrollable full text area: strictly disabled and hidden while selecting date
            ScrollView {
                id: textScrollView
                anchors.fill: parent
                visible: !root.calendarOpen
                clip: true

                TextArea {
                    id: todoTextArea
                    width: textScrollView.availableWidth
                    enabled: !root.calendarOpen
                    text: root.localTitle
                    placeholderText: qsTr("Task description…")
                    placeholderTextColor: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                    color: root.localDone ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                    wrapMode: TextEdit.Wrap
                    background: null
                    padding: 0
                    selectByMouse: true

                    onTextChanged: {
                        if (length > root.maxTitleLength) {
                            const cursor = cursorPosition;
                            text = text.slice(0, root.maxTitleLength);
                            cursorPosition = Math.min(cursor, root.maxTitleLength);
                        }
                        if (root.localTitle !== text) {
                            root.localTitle = text;
                            autoSyncTimer.restart();
                        }
                    }
                }
            }
        }
    }
}
