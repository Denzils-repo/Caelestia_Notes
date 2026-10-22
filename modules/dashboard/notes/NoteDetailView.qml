pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import M3Shapes
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

StyledRect {
    id: root

    signal backRequested()

    readonly property var activeNote: NotesStore.activeNote

    // Local state for snappy typing without tearing
    property string localTitle: ""
    property string localBody: ""
    property bool localPinned: false
    property string localColor: "none"
    property bool confirmDelete: false
    property bool isEditing: false
    property var localListShapes: ({})

    readonly property bool isNoteEmpty: {
        const title = (root.localTitle || "").trim();
        const body = (root.localBody || "").trim();
        const hasTitle = title.length > 0 && title !== "Untitled";
        const hasBody = body.length > 0;
        return !hasTitle && !hasBody;
    }

    readonly property bool hasCustomColor: !!(localColor && localColor !== "none")

    readonly property color accentColor: {
        if (!localColor || localColor === "none") return Colours.palette.m3primary;
        switch (localColor) {
            case "secondary": return Colours.palette.m3secondary;
            case "tertiary": return Colours.palette.m3tertiary;
            case "pink": return Colours.palette.m3error;
            case "surface": return Colours.palette.m3outline;
            default: return Colours.palette.m3primary;
        }
    }

    radius: Tokens.rounding.large
    color: "transparent"

    readonly property FileView customPromptsFile: FileView {
        path: `${Quickshell.env("HOME")}/.config/caelestia/note_prompts.json`
        watchChanges: true
        printErrors: false
        onLoaded: root.reloadPrompts()
    }

    readonly property FileView defaultPromptsFile: FileView {
        path: Qt.resolvedUrl("note_prompts.json").toString().replace(/^file:\/\//, "")
        watchChanges: true
        printErrors: false
        onLoaded: root.reloadPrompts()
    }

    property var cachedPrompts: [
        qsTr("Capture a fleeting thought…"),
        qsTr("Write something worth remembering…"),
        qsTr("What's on your mind today?"),
        qsTr("Ideas are fragile — write them down…"),
        qsTr("Draft a masterpiece or just a quick reminder…"),
        qsTr("Start writing… (Markdown supported)"),
        qsTr("Every great journey begins with a single note…"),
        qsTr("Got a sudden spark of inspiration?"),
        qsTr("Turn chaos into clarity…"),
        qsTr("Jot down your daily reflections…"),
        qsTr("Clear your mind, one line at a time…")
    ]

    property string currentPlaceholder: qsTr("Take a note… (Markdown supported)")

    function reloadPrompts() {
        let loaded = null;
        if (customPromptsFile) {
            try {
                const txt = customPromptsFile.text();
                if (txt && txt.trim().length > 0) {
                    const parsed = JSON.parse(txt);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        loaded = parsed.map(item => (typeof item === "string" ? item : (item.text || item.prompt || ""))).filter(s => s && s.trim().length > 0);
                    }
                }
            } catch (e) {
                // Ignore parse errors
            }
        }
        if ((!loaded || loaded.length === 0) && defaultPromptsFile) {
            try {
                const txt = defaultPromptsFile.text();
                if (txt && txt.trim().length > 0) {
                    const parsed = JSON.parse(txt);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        loaded = parsed.map(item => (typeof item === "string" ? item : (item.text || item.prompt || ""))).filter(s => s && s.trim().length > 0);
                    }
                }
            } catch (e) {
                // Ignore parse errors
            }
        }
        if (loaded && loaded.length > 0) {
            root.cachedPrompts = loaded;
        }
    }

    function pickRandomPlaceholder() {
        if (!cachedPrompts || cachedPrompts.length === 0) {
            root.reloadPrompts();
        }
        const list = (cachedPrompts && cachedPrompts.length > 0) ? cachedPrompts : [qsTr("Take a note… (Markdown supported)")];
        const idx = Math.floor(Math.random() * list.length);
        root.currentPlaceholder = list[idx];
    }

    Timer {
        id: confirmDeleteTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmDelete = false
    }

    property string currentNoteId: ""

    function resetScroll() {
        if (markdownLoader && markdownLoader.item && typeof markdownLoader.item.resetScroll === "function") {
            markdownLoader.item.resetScroll();
        }
        if (bodyScrollView && bodyScrollView.contentItem) {
            bodyScrollView.contentItem.contentY = 0;
            if (typeof bodyScrollView.contentItem.returnToBounds === "function") {
                bodyScrollView.contentItem.returnToBounds();
            }
        }
        if (bodyScrollView && bodyScrollView.ScrollBar && bodyScrollView.ScrollBar.vertical) {
            bodyScrollView.ScrollBar.vertical.position = 0;
        }
    }

    function getCompleteNoteText(): string {
        const title = (root.localTitle || "").trim();
        const body = (root.localBody || "").trim();
        if (title.length > 0 && title !== "Untitled") {
            if (body.length > 0) {
                return title + "\n\n" + body;
            }
            return title;
        }
        return body;
    }

    function focusBody() {
        if (bodyArea && root.isEditing) {
            if (!bodyArea.activeFocus) {
                bodyArea.forceActiveFocus();
            }
        }
    }

    property int pendingCursorIndex: -1

    Timer {
        id: editCursorTimer
        interval: 35
        repeat: false
        onTriggered: {
            root.applyCursorPosition();
            root.pendingCursorIndex = -1;
        }
    }

    function applyCursorPosition(): void {
        if (!bodyArea || root.pendingCursorIndex < 0) return;
        bodyArea.forceActiveFocus();
        const maxLen = root.localBody ? root.localBody.length : (bodyArea ? bodyArea.length : 0);
        const targetPos = Math.max(0, Math.min(maxLen, root.pendingCursorIndex));
        bodyArea.deselect();
        bodyArea.cursorPosition = targetPos;
        if (bodyScrollView && bodyScrollView.flickable) {
            const flick = bodyScrollView.flickable;
            const curY = bodyArea.cursorRectangle.y;
            if (curY < flick.contentY || curY + bodyArea.cursorRectangle.height > flick.contentY + flick.height) {
                flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), curY - flick.height / 3));
            }
        }
    }

    function switchToEditAt(targetIndex: int): void {
        const maxLen = root.localBody ? root.localBody.length : (bodyArea ? bodyArea.length : 0);
        root.pendingCursorIndex = Math.max(0, Math.min(maxLen, targetIndex));
        root.isEditing = true;
        if (bodyArea) {
            bodyArea.cursorPosition = root.pendingCursorIndex;
        }
        Qt.callLater(root.applyCursorPosition);
        editCursorTimer.restart();
    }

    Timer {
        id: focusBodyTimer
        interval: 60
        repeat: true
        property int attempts: 0
        onTriggered: {
            attempts++;
            if (bodyArea && root.isEditing) {
                if (!bodyArea.activeFocus) {
                    bodyArea.forceActiveFocus();
                }
                if (bodyArea.activeFocus || attempts >= 10) {
                    attempts = 0;
                    stop();
                }
            } else if (attempts >= 10) {
                attempts = 0;
                stop();
            }
        }
    }

    function triggerFocusBody() {
        focusBodyTimer.attempts = 0;
        focusBodyTimer.restart();
        Qt.callLater(root.focusBody);
    }

    Connections {
        target: NotesStore
        function onRequestFocusBody(): void {
            root.triggerFocusBody();
        }
        function onNoteOpened(noteId: string): void {
            if (markdownLoader && markdownLoader.item && typeof markdownLoader.item.triggerPopIn === "function") {
                markdownLoader.item.triggerPopIn();
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.resetScroll();
            Qt.callLater(root.resetScroll);
            if (!localTitle && !localBody) {
                root.triggerFocusBody();
            }
        } else {
            root.syncNow();
            if (root.activeNote) {
                const curTitle = titleField ? titleField.text.trim() : (root.localTitle || "").trim();
                const curBody = bodyArea ? bodyArea.text.trim() : (root.localBody || "").trim();
                if (curTitle.length === 0 && curBody.length === 0) {
                    NotesStore.closeNote(false);
                }
            }
        }
    }

    onActiveNoteChanged: {
        confirmDeleteTimer.stop();
        confirmDelete = false;
        if (!activeNote) {
            currentNoteId = "";
            return;
        }

        const newId = activeNote.id || "";
        if (newId !== currentNoteId) {
            currentNoteId = newId;
            localTitle = activeNote.title || "";
            localBody = activeNote.body || "";
            localPinned = !!activeNote.pinned;
            localColor = activeNote.color || "none";
            localListShapes = Object.assign({}, activeNote.listShapes || {});
            isEditing = (!localTitle && !localBody);
            if (titleField) titleField.text = localTitle;
            if (bodyArea) bodyArea.text = localBody;
            root.resetScroll();
            Qt.callLater(root.resetScroll);
            if (!localTitle && !localBody) {
                root.pickRandomPlaceholder();
                root.triggerFocusBody();
            }
        }
    }

    Component.onCompleted: {
        confirmDeleteTimer.stop();
        confirmDelete = false;
        root.reloadPrompts();
        if (activeNote) {
            currentNoteId = activeNote.id || "";
            localTitle = activeNote.title || "";
            localBody = activeNote.body || "";
            localPinned = !!activeNote.pinned;
            localColor = activeNote.color || "none";
            localListShapes = Object.assign({}, activeNote.listShapes || {});
            isEditing = (!localTitle && !localBody);
            if (titleField) titleField.text = localTitle;
            if (bodyArea) bodyArea.text = localBody;
            root.resetScroll();
            Qt.callLater(root.resetScroll);
            if (!localTitle && !localBody) {
                root.pickRandomPlaceholder();
                root.triggerFocusBody();
            }
        } else {
            root.pickRandomPlaceholder();
        }
    }

    Timer {
        id: autoSyncTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (root.activeNote) {
                const curTitle = titleField ? titleField.text : root.localTitle;
                const curBody = bodyArea ? bodyArea.text : root.localBody;
                root.localTitle = curTitle;
                root.localBody = curBody;
                NotesStore.updateNote(root.activeNote.id, curTitle, curBody, root.localPinned, root.localColor, root.localListShapes);
            }
        }
    }

    function syncNow() {
        autoSyncTimer.stop();
        if (root.activeNote) {
            const curTitle = titleField ? titleField.text : root.localTitle;
            const curBody = bodyArea ? bodyArea.text : root.localBody;
            root.localTitle = curTitle;
            root.localBody = curBody;
            NotesStore.updateNote(root.activeNote.id, curTitle, curBody, root.localPinned, root.localColor, root.localListShapes);
            NotesStore.flushSave();
        }
    }

    function handleBack() {
        confirmDeleteTimer.stop();
        confirmDelete = false;
        autoSyncTimer.stop();
        const curTitle = titleField ? titleField.text : root.localTitle;
        const curBody = bodyArea ? bodyArea.text : root.localBody;
        root.localTitle = curTitle;
        root.localBody = curBody;
        if (root.activeNote) {
            NotesStore.updateNote(root.activeNote.id, curTitle, curBody, root.localPinned, root.localColor, root.localListShapes);
        }
        NotesStore.closeNote(true, curTitle, curBody, root.localListShapes);
        root.currentNoteId = "";
        root.backRequested();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // Top Header Section: Back + Title on left, Pin + Delete with Color Selector directly underneath on right
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            // Left: Back button + Title field
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Tokens.spacing.small

                IconButton {
                    icon: "arrow_back"
                    type: ButtonBase.Tonal
                    onClicked: root.handleBack()
                }

                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.localTitle
                    placeholderText: qsTr("Title")
                    placeholderTextColor: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                    background: null
                    padding: 0
                    selectByMouse: true

                    Keys.onEscapePressed: root.handleBack()

                    onTextChanged: {
                        root.localTitle = text;
                        autoSyncTimer.restart();
                    }

                    onAccepted: bodyArea.forceActiveFocus()
                }
            }

            // Right: Pin & Delete on top, Color selector dots directly beneath
            ColumnLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignTop
                spacing: 6

                // Top: View/Edit toggle, Pin & Delete action buttons
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        id: editToggleBtn
                        icon: root.isEditing ? "visibility" : "edit"
                        type: ButtonBase.Tonal
                        onClicked: {
                            if (root.isEditing) {
                                root.syncNow();
                                root.isEditing = false;
                            } else {
                                root.isEditing = true;
                                bodyArea.forceActiveFocus();
                            }
                        }
                    }

                    IconButton {
                        id: copyBtn
                        icon: copyFeedbackTimer.running ? "check" : "content_copy"
                        type: copyFeedbackTimer.running ? ButtonBase.Filled : ButtonBase.Tonal
                        disabled: root.isNoteEmpty
                        opacity: root.isNoteEmpty ? 0.38 : 1.0
                        activeColour: Colours.palette.m3primary
                        activeOnColour: Colours.palette.m3onPrimary

                        Behavior on opacity {
                            Anim { type: Anim.FastEffects }
                        }

                        onClicked: {
                            if (root.isNoteEmpty)
                                return;
                            root.syncNow();
                            const textToCopy = root.getCompleteNoteText();
                            if (textToCopy.length === 0)
                                return;
                            Quickshell.clipboardText = textToCopy;
                            Toaster.toast(qsTr("Copied to clipboard"), (root.localTitle && root.localTitle.trim() !== "Untitled" ? root.localTitle : qsTr("Note")), "content_copy");
                            copyFeedbackTimer.restart();
                        }

                        Timer {
                            id: copyFeedbackTimer
                            interval: 1500
                            repeat: false
                        }
                    }

                    IconButton {
                        icon: "push_pin"
                        type: root.localPinned ? ButtonBase.Filled : ButtonBase.Tonal
                        onClicked: {
                            root.localPinned = !root.localPinned;
                            root.syncNow();
                        }
                    }

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
                                if (root.activeNote) {
                                    NotesStore.deleteNote(root.activeNote.id);
                                    root.backRequested();
                                }
                            }
                        }
                    }
                }

                // Bottom: Color selector dots directly below pin & delete
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "none", color: Colours.palette.m3surfaceContainerHighest },
                            { id: "primary", color: Colours.palette.m3primary },
                            { id: "secondary", color: Colours.palette.m3secondary },
                            { id: "tertiary", color: Colours.palette.m3tertiary },
                            { id: "pink", color: Colours.palette.m3error }
                        ]

                        delegate: CustomMouseArea {
                            id: colorDot
                            required property var modelData

                            readonly property bool isSelected: (root.localColor === modelData.id) ||
                                                               (modelData.id === "none" && (!root.localColor || root.localColor === "none"))

                            implicitWidth: 18
                            implicitHeight: 18
                            cursorShape: Qt.PointingHandCursor

                            // Unified M3 Shape morphing (Circle <-> Gem) for all items including default
                            MaterialShape {
                                id: colorShape
                                anchors.centerIn: parent
                                implicitSize: 16

                                shape: colorDot.isSelected ? MaterialShape.Gem : MaterialShape.Circle

                                color: colorDot.modelData.color
                                strokeColor: colorDot.isSelected ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
                                strokeWidth: colorDot.isSelected ? 1.5 : 1

                                scale: colorDot.containsMouse ? 1.18 : 1.0

                                animationEasing: Tokens.anim.expressiveDefaultSpatial
                                animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

                                Behavior on scale {
                                    Anim { type: Anim.DefaultSpatial }
                                }
                                Behavior on strokeWidth {
                                    Anim { type: Anim.FastEffects }
                                }
                                Behavior on strokeColor {
                                    CAnim {}
                                }

                                // Centered subtle X mark for the default "none" button
                                MaterialIcon {
                                    visible: colorDot.modelData.id === "none"
                                    anchors.centerIn: parent
                                    text: "close"
                                    font: Tokens.font.icon.size(9).build()
                                    color: colorDot.isSelected ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant

                                    Behavior on color {
                                        CAnim {}
                                    }
                                }
                            }

                            onClicked: {
                                root.localColor = colorDot.modelData.id;
                                root.syncNow();
                            }
                        }
                    }
                }
            }
        }

        // Dedicated Tinted Description Card (Only description receives the note color)
        StyledRect {
            id: descContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            clip: true

            color: root.hasCustomColor
                   ? Qt.tint(Colours.tPalette.m3surfaceContainerHigh, Qt.alpha(root.accentColor, 0.22))
                   : Colours.tPalette.m3surfaceContainerHigh

            border.width: 1
            border.color: root.hasCustomColor
                          ? Qt.alpha(root.accentColor, 0.45)
                          : Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

            Behavior on color {
                CAnim {}
            }

            Behavior on border.color {
                CAnim {}
            }

            // Rendered Markdown View (Only active and loaded when in View Mode)
            Loader {
                id: markdownLoader
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                active: !root.isEditing
                visible: opacity > 0.001
                opacity: !root.isEditing ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                sourceComponent: MarkdownNoteView {
                    rawText: root.localBody
                    accentColor: root.accentColor
                    hasCustomColor: root.hasCustomColor
                    listShapes: root.localListShapes
                    onShapesChanged: (shapes) => {
                        root.localListShapes = Object.assign({}, shapes);
                        if (root.activeNote) {
                            NotesStore.updateNote(root.activeNote.id, root.localTitle, root.localBody, root.localPinned, root.localColor, root.localListShapes);
                        }
                    }
                    onEditRequested: (targetIndex) => {
                        root.switchToEditAt(targetIndex);
                    }
                }
            }

            // Raw Text Editor Mode
            ScrollView {
                id: bodyScrollView
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                visible: opacity > 0.001
                opacity: root.isEditing ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                clip: true

                readonly property real fadeAmount: 0.08
                readonly property Flickable flickable: contentItem as Flickable

                property real topFadeOpacity: fadeShouldBeActive(true) ? 0 : 1
                property real bottomFadeOpacity: fadeShouldBeActive(false) ? 0 : 1

                function fadeShouldBeActive(isStart: bool): bool {
                    if (!flickable || !flickable.visibleArea)
                        return false;

                    if (flickable.contentHeight <= flickable.height)
                        return false;

                    if (isStart)
                        return flickable.visibleArea.yPosition > 0.001;
                    return flickable.visibleArea.yPosition + flickable.visibleArea.heightRatio < 0.999;
                }

                Behavior on topFadeOpacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }

                Behavior on bottomFadeOpacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }

                layer.enabled: true
                layer.effect: Mask {
                    maskSource: bodyScrollMask

                    Rectangle {
                        id: bodyScrollMask

                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        gradient: Gradient {
                            orientation: Gradient.Vertical

                            GradientStop {
                                position: 0
                                color: Qt.rgba(0, 0, 0, bodyScrollView.topFadeOpacity)
                            }
                            GradientStop {
                                position: bodyScrollView.fadeAmount
                                color: Qt.rgba(0, 0, 0, 1)
                            }
                            GradientStop {
                                position: 1 - bodyScrollView.fadeAmount
                                color: Qt.rgba(0, 0, 0, 1)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.rgba(0, 0, 0, bodyScrollView.bottomFadeOpacity)
                            }
                        }
                    }
                }

                TextArea {
                    id: bodyArea
                    width: bodyScrollView.availableWidth
                    text: root.localBody
                    placeholderText: root.currentPlaceholder
                    placeholderTextColor: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurface
                    wrapMode: TextEdit.Wrap
                    background: null
                    padding: 0
                    selectByMouse: true

                    Keys.onEscapePressed: {
                        root.syncNow();
                        root.isEditing = false;
                    }

                    onTextChanged: {
                        root.localBody = text;
                        autoSyncTimer.restart();
                    }
                }
            }
        }
    }
}
