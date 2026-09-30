pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
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

    Timer {
        id: confirmDeleteTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmDelete = false
    }

    property string currentNoteId: ""

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
        }
    }

    Component.onCompleted: {
        confirmDeleteTimer.stop();
        confirmDelete = false;
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

                            implicitWidth: 16
                            implicitHeight: 16
                            cursorShape: Qt.PointingHandCursor

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: colorDot.modelData.color
                                border.width: colorDot.isSelected ? 2 : 1
                                border.color: colorDot.isSelected ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

                                scale: colorDot.containsMouse ? 1.18 : 1.0

                                Behavior on border.width {
                                    Anim {}
                                }

                                Behavior on scale {
                                    Anim {
                                        type: Anim.DefaultSpatial
                                    }
                                }

                                MaterialIcon {
                                    visible: colorDot.modelData.id === "none"
                                    anchors.centerIn: parent
                                    text: "block"
                                    font: Tokens.font.icon.size(9).build()
                                    color: Colours.palette.m3onSurfaceVariant
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
                visible: !root.isEditing

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
                    onDoubleClicked: {
                        root.isEditing = true;
                        bodyArea.forceActiveFocus();
                    }
                }
            }

            // Raw Text Editor Mode
            ScrollView {
                id: bodyScrollView
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                visible: root.isEditing
                clip: true

                TextArea {
                    id: bodyArea
                    width: bodyScrollView.availableWidth
                    text: root.localBody
                    placeholderText: qsTr("Take a note… (Markdown supported)")
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
                        autoSyncTimer.restart();
                    }
                }
            }
        }
    }
}
