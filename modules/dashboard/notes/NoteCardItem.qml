pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property var note
    required property string viewMode // "grid" | "list"
    signal clicked()

    readonly property bool hasCustomColor: !!(note && note.color && note.color !== "none")

    readonly property color accentColor: {
        if (!note || !note.color || note.color === "none") return Colours.palette.m3primary;
        switch (note.color) {
            case "secondary": return Colours.palette.m3secondary;
            case "tertiary": return Colours.palette.m3tertiary;
            case "pink": return Colours.palette.m3error;
            case "surface": return Colours.palette.m3outline;
            default: return Colours.palette.m3primary;
        }
    }

    readonly property color baseColor: stateLayer.containsMouse
        ? Colours.tPalette.m3surfaceContainerHighest
        : Colours.tPalette.m3surfaceContainerHigh

    radius: Tokens.rounding.medium
    color: root.hasCustomColor
           ? Qt.tint(baseColor, Qt.alpha(root.accentColor, 0.22))
           : baseColor
    border.width: 1
    border.color: stateLayer.containsMouse
                  ? (root.hasCustomColor ? root.accentColor : Colours.palette.m3primary)
                  : (root.hasCustomColor
                     ? Qt.alpha(root.accentColor, 0.45)
                     : Qt.alpha(Colours.palette.m3outlineVariant, 0.45))
    implicitHeight: viewMode === "list" ? 70 : 118
    height: implicitHeight
    clip: true

    Behavior on color {
        CAnim {}
    }

    Behavior on border.color {
        CAnim {}
    }

    readonly property string cleanSnippet: {
        if (!root.note || !root.note.body) return "";
        return root.note.body
            .replace(/^#+\s+/gm, "")
            .replace(/^[\*\-\+]\s*/gm, "• ")
            .replace(/^\d+\.\s+/gm, "")
            .replace(/\*\*([^*]+)\*\*/g, "$1")
            .replace(/\*([^*]+)\*/g, "$1")
            .replace(/~~([^~]+)~~/g, "$1")
            .replace(/`([^`]+)`/g, "$1")
            .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
            .trim();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: (root.note && root.note.title && root.note.title.trim().length > 0) ? root.note.title : qsTr("Untitled")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: (root.note && root.note.title && root.note.title.trim().length > 0) ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            MaterialIcon {
                visible: !!(root.note && root.note.pinned)
                text: "push_pin"
                fontStyle: Tokens.font.icon.small
                color: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: root.viewMode === "grid"
            text: root.cleanSnippet
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: root.viewMode === "list" ? 1 : 3
            opacity: 0.85
        }
    }

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        radius: root.radius
        color: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
        z: 10
        onClicked: root.clicked()
    }
}
