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

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    implicitHeight: 480
    clip: true

    property string sectionFilter: "all" // "all" | "pinned" | "others"

    readonly property var pinnedNotes: NotesStore.getPinnedNotes()
    readonly property var otherNotes: NotesStore.getOtherNotes()
    readonly property int totalNotesCount: (NotesStore.notes || []).length

    readonly property var displayedPinnedNotes: {
        if (root.sectionFilter === "all" && root.pinnedNotes.length > 4) {
            return root.pinnedNotes.slice(0, 3);
        }
        return root.pinnedNotes;
    }
    readonly property bool showPinnedStack: root.sectionFilter === "all" && root.pinnedNotes.length > 4

    readonly property var displayedOtherNotes: {
        if (root.sectionFilter === "all" && root.otherNotes.length > 4) {
            return root.otherNotes.slice(0, 3);
        }
        return root.otherNotes;
    }
    readonly property bool showOtherStack: root.sectionFilter === "all" && root.otherNotes.length > 4

    onPinnedNotesChanged: {
        if (root.sectionFilter === "pinned" && root.pinnedNotes.length === 0) {
            root.sectionFilter = "all";
        }
    }

    onOtherNotesChanged: {
        if (root.sectionFilter === "others" && root.otherNotes.length === 0) {
            root.sectionFilter = "all";
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large

        // Normal View (Grid or List of Notes)
        ColumnLayout { 
            id: listViewContainer
            anchors.fill: parent
            spacing: Tokens.spacing.small
            visible: !NotesStore.isEditingNote

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                // Back button when filtered into a specific section
                IconButton {
                    visible: root.sectionFilter !== "all"
                    icon: "arrow_back"
                    type: ButtonBase.Tonal
                    onClicked: root.sectionFilter = "all"
                }

                StyledText {
                    text: {
                        if (root.sectionFilter === "pinned") return qsTr("Pinned Notes");
                        if (root.sectionFilter === "others") return qsTr("Other Notes");
                        return qsTr("Notes");
                    }
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }

                StyledRect {
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHigh
                    implicitHeight: 20
                    implicitWidth: countText.implicitWidth + 12

                    StyledText {
                        id: countText
                        anchors.centerIn: parent
                        text: {
                            if (root.sectionFilter === "pinned") return `${root.pinnedNotes.length}`;
                            if (root.sectionFilter === "others") return `${root.otherNotes.length}`;
                            return `${root.totalNotesCount}`;
                        }
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                // View Toggle Button (highlighted when Grid is active)
                IconButton {
                    icon: NotesStore.viewMode === "grid" ? "grid_view" : "view_list"
                    type: NotesStore.viewMode === "grid" ? ButtonBase.Filled : ButtonBase.Tonal
                    onClicked: NotesStore.toggleViewMode()
                }

                // Add Note
                IconButton {
                    icon: "add"
                    type: ButtonBase.Filled
                    onClicked: NotesStore.createAndOpenNewNote()
                }
            }

            // Scrollable Content
            ScrollView {
                id: notesScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout { 
                    width: notesScrollView.availableWidth
                    spacing: Tokens.spacing.medium

                    // Empty State
                    ColumnLayout { 
                        Layout.fillWidth: true
                        Layout.topMargin: 40
                        visible: root.totalNotesCount === 0
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "sticky_note_2"
                            fontStyle: Tokens.font.icon.extraLarge
                            color: Colours.palette.m3primary
                            opacity: 0.8
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("No notes yet")
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Tokens.padding.medium
                            Layout.rightMargin: Tokens.padding.medium
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("Click + to jot down thoughts, ideas, or reminders")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }
                    }

                    // PINNED SECTION
                    ColumnLayout { 
                        Layout.fillWidth: true
                        visible: root.sectionFilter !== "others" && root.pinnedNotes.length > 0
                        spacing: Tokens.spacing.small

                        RowLayout {
                            visible: root.sectionFilter === "all"
                            spacing: 4
                            MaterialIcon {
                                text: "push_pin"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3primary
                            }
                            StyledText {
                                text: qsTr("PINNED")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        // List Mode for Pinned
                        ColumnLayout { 
                            Layout.fillWidth: true
                            visible: NotesStore.viewMode === "list"
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: NotesStore.viewMode === "list" ? root.displayedPinnedNotes : []
                                delegate: NoteCardItem {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    note: modelData
                                    viewMode: "list"
                                    onClicked: NotesStore.openNote(modelData)
                                }
                            }

                            NoteStackCard {
                                visible: root.showPinnedStack
                                Layout.fillWidth: true
                                note: root.pinnedNotes.length > 3 ? root.pinnedNotes[3] : null
                                remainingCount: Math.max(0, root.pinnedNotes.length - 4)
                                sectionType: "pinned"
                                viewMode: "list"
                                onClicked: root.sectionFilter = "pinned"
                            }
                        }

                        // Grid Mode for Pinned (Fixed 50% width 2-column Grid)
                        Grid {
                            columns: 2
                            columnSpacing: Tokens.spacing.small
                            rowSpacing: Tokens.spacing.small
                            Layout.fillWidth: true
                            width: notesScrollView.availableWidth
                            visible: NotesStore.viewMode === "grid"

                            Repeater {
                                model: NotesStore.viewMode === "grid" ? root.displayedPinnedNotes : []
                                delegate: NoteCardItem {
                                    required property var modelData
                                    width: parent.width > 0 ? Math.floor((parent.width - parent.columnSpacing) / 2) : 200
                                    note: modelData
                                    viewMode: "grid"
                                    onClicked: NotesStore.openNote(modelData)
                                }
                            }

                            NoteStackCard {
                                visible: root.showPinnedStack
                                width: parent.width > 0 ? Math.floor((parent.width - parent.columnSpacing) / 2) : 200
                                note: root.pinnedNotes.length > 3 ? root.pinnedNotes[3] : null
                                remainingCount: Math.max(0, root.pinnedNotes.length - 4)
                                sectionType: "pinned"
                                viewMode: "grid"
                                onClicked: root.sectionFilter = "pinned"
                            }
                        }
                    }

                    // OTHERS SECTION
                    ColumnLayout { 
                        Layout.fillWidth: true
                        visible: root.sectionFilter !== "pinned" && root.otherNotes.length > 0
                        spacing: Tokens.spacing.small

                        StyledText {
                            visible: root.sectionFilter === "all" && root.pinnedNotes.length > 0
                            text: qsTr("OTHERS")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        // List Mode for Others
                        ColumnLayout { 
                            Layout.fillWidth: true
                            visible: NotesStore.viewMode === "list"
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: NotesStore.viewMode === "list" ? root.displayedOtherNotes : []
                                delegate: NoteCardItem {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    note: modelData
                                    viewMode: "list"
                                    onClicked: NotesStore.openNote(modelData)
                                }
                            }

                            NoteStackCard {
                                visible: root.showOtherStack
                                Layout.fillWidth: true
                                note: root.otherNotes.length > 3 ? root.otherNotes[3] : null
                                remainingCount: Math.max(0, root.otherNotes.length - 4)
                                sectionType: "others"
                                viewMode: "list"
                                onClicked: root.sectionFilter = "others"
                            }
                        }

                        // Grid Mode for Others (Fixed 50% width 2-column Grid)
                        Grid {
                            columns: 2
                            columnSpacing: Tokens.spacing.small
                            rowSpacing: Tokens.spacing.small
                            Layout.fillWidth: true
                            width: notesScrollView.availableWidth
                            visible: NotesStore.viewMode === "grid"

                            Repeater {
                                model: NotesStore.viewMode === "grid" ? root.displayedOtherNotes : []
                                delegate: NoteCardItem {
                                    required property var modelData
                                    width: parent.width > 0 ? Math.floor((parent.width - parent.columnSpacing) / 2) : 200
                                    note: modelData
                                    viewMode: "grid"
                                    onClicked: NotesStore.openNote(modelData)
                                }
                            }

                            NoteStackCard {
                                visible: root.showOtherStack
                                width: parent.width > 0 ? Math.floor((parent.width - parent.columnSpacing) / 2) : 200
                                note: root.otherNotes.length > 3 ? root.otherNotes[3] : null
                                remainingCount: Math.max(0, root.otherNotes.length - 4)
                                sectionType: "others"
                                viewMode: "grid"
                                onClicked: root.sectionFilter = "others"
                            }
                        }
                    }

                    // Bottom padding so bottom cards never feel cut off when scrolled
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: Tokens.padding.medium
                    }
                }
            }
        }

        // Takeover Detail Editor
        NoteDetailView {
            id: detailView
            anchors.fill: parent
            visible: NotesStore.isEditingNote
        }
    }
}
