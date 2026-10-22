pragma ComponentBehavior: Bound

import "notes"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: 840
    implicitHeight: 480

    RowLayout {
        anchors.fill: parent
        spacing: NotesStore.isEditingNote ? 0 : Tokens.spacing.medium

        Behavior on spacing {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        // To-do Panel (fluidly expands to 58% when calendar date picker is open; collapses to 0% in note view mode)
        TodoPanel {
            id: todoPanel
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: NotesStore.isEditingNote
                                   ? 0
                                   : ((root.width - (NotesStore.isEditingNote ? 0 : Tokens.spacing.medium)) * (todoPanel.isDatePicking ? 0.58 : 0.40))
            opacity: NotesStore.isEditingNote ? 0 : 1
            enabled: !NotesStore.isEditingNote

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Notes Panel (absorbs remaining width smoothly, expanding to 100% in view mode)
        NotesPanel {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }
}
