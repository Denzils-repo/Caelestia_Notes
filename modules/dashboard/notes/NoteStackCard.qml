pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property var note: null
    property int remainingCount: 1
    property string sectionType: "pinned" // "pinned" | "others"
    property string viewMode: "grid"      // "grid" | "list"
    signal clicked()

    implicitHeight: viewMode === "list" ? 70 : 118
    height: implicitHeight

    readonly property bool isList: viewMode === "list"
    readonly property bool hasCustomColor: !!(note && note.color && note.color !== "none")
    readonly property bool isHovered: stateLayer.containsMouse || rootHoverHandler.hovered

    HoverHandler {
        id: rootHoverHandler
    }

    TapHandler {
        onTapped: root.clicked()
    }

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

    // Background Card 2 (Furthest back layer, peeking highest to top-right)
    StyledRect {
        id: bgCard2
        visible: root.remainingCount > 1
        width: frontCard.width
        height: frontCard.height
        radius: Tokens.rounding.medium
        color: root.hasCustomColor
               ? Qt.tint(Colours.tPalette.m3surfaceContainerHighest, Qt.alpha(root.accentColor, 0.14))
               : Colours.tPalette.m3surfaceContainerHighest
        border.width: 1
        border.color: root.hasCustomColor
                      ? Qt.alpha(root.accentColor, 0.35)
                      : Qt.alpha(Colours.palette.m3outlineVariant, 0.40)

        x: frontCard.x + (root.isList
           ? (root.isHovered ? 9 : 6)
           : (root.isHovered ? 12 : 8))
        y: frontCard.y - (root.isList
           ? (root.isHovered ? 5.5 : 3.8)
           : (root.isHovered ? 9 : 6))
        rotation: root.isList
           ? (root.isHovered ? 3.0 : 1.8)
           : (root.isHovered ? 5.8 : 3.6)
        transformOrigin: Item.BottomLeft

        Behavior on x { Anim { type: Anim.DefaultSpatial } }
        Behavior on y { Anim { type: Anim.DefaultSpatial } }
        Behavior on rotation { Anim { type: Anim.DefaultSpatial } }
    }

    // Background Card 1 (Middle layer, matching reference tilt)
    StyledRect {
        id: bgCard1
        width: frontCard.width
        height: frontCard.height
        radius: Tokens.rounding.medium
        color: root.hasCustomColor
               ? Qt.tint(Colours.tPalette.m3surfaceContainerHighest, Qt.alpha(root.accentColor, 0.18))
               : Colours.tPalette.m3surfaceContainerHighest
        border.width: 1
        border.color: root.hasCustomColor
                      ? Qt.alpha(root.accentColor, 0.40)
                      : Qt.alpha(Colours.palette.m3outlineVariant, 0.55)

        x: frontCard.x + (root.isList
           ? (root.isHovered ? 4.5 : 3)
           : (root.isHovered ? 6 : 4))
        y: frontCard.y - (root.isList
           ? (root.isHovered ? 3 : 2)
           : (root.isHovered ? 4.5 : 3))
        rotation: root.isList
           ? (root.isHovered ? 1.6 : 1.0)
           : (root.isHovered ? 3.0 : 1.8)
        transformOrigin: Item.BottomLeft

        Behavior on x { Anim { type: Anim.DefaultSpatial } }
        Behavior on y { Anim { type: Anim.DefaultSpatial } }
        Behavior on rotation { Anim { type: Anim.DefaultSpatial } }
    }

    // Front Card Soft Paper Shadow (subtle depth)
    RectangularShadow {
        anchors.fill: frontCard
        radius: frontCard.radius
        color: Qt.alpha(Colours.palette.m3shadow, root.isHovered ? 0.22 : 0.12)
        blur: root.isHovered ? 8 : 4
        offset.y: root.isHovered ? 2.5 : 1.2
        offset.x: root.isHovered ? 1.2 : 0.5

        Behavior on color { CAnim {} }
        Behavior on blur { Anim { type: Anim.DefaultSpatial } }
        Behavior on offset.y { Anim { type: Anim.DefaultSpatial } }
    }

    // Front Card (Upright, interactive, rendering real note content)
    StyledRect {
        id: frontCard
        x: 4
        y: root.isList ? 9 : 16
        width: Math.max(0, root.width - (root.isList ? 22 : 28))
        height: Math.max(0, root.height - (root.isList ? 13 : 20))
        radius: Tokens.rounding.medium
        clip: true

        readonly property color frontBaseColor: root.isHovered
            ? Colours.tPalette.m3surfaceContainerHighest
            : Colours.tPalette.m3surfaceContainerHigh

        color: root.hasCustomColor
               ? Qt.tint(frontBaseColor, Qt.alpha(root.accentColor, 0.22))
               : frontBaseColor
        border.width: 1
        border.color: root.isHovered
                      ? Colours.palette.m3primary
                      : (root.hasCustomColor
                         ? Qt.alpha(root.accentColor, 0.45)
                         : Qt.alpha(Colours.palette.m3outlineVariant, 0.45))

        Behavior on color { CAnim {} }
        Behavior on border.color { CAnim {} }

        // GRID CONTENT (118px)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            visible: !root.isList
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: (root.note && root.note.title && root.note.title.trim().length > 0)
                          ? root.note.title
                          : qsTr("Untitled")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: (root.note && root.note.title && root.note.title.trim().length > 0)
                           ? Colours.palette.m3onSurface
                           : Colours.palette.m3onSurfaceVariant
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
                Layout.fillHeight: true
                text: root.cleanSnippet
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                opacity: 0.85
            }
        }

        // GRID FROSTED GRADIENT SCRIM & VIEW ALL BADGE
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            anchors.bottomMargin: 1
            height: 38
            color: "transparent"
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Math.max(0, frontCard.radius - 1)
            bottomRightRadius: Math.max(0, frontCard.radius - 1)
            visible: !root.isList
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.45; color: Qt.alpha(frontCard.color, 0.88) }
                GradientStop { position: 1.0; color: frontCard.color }
            }

            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                spacing: 4

                StyledText {
                    text: root.remainingCount > 0
                          ? qsTr("View all (+%1)").arg(root.remainingCount)
                          : qsTr("View all")
                    font: Tokens.font.label.small
                    color: root.isHovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                }

                MaterialIcon {
                    text: "arrow_forward"
                    fontStyle: Tokens.font.icon.builders.small.scale(0.8).build()
                    color: root.isHovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // LIST CONTENT (70px)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            visible: root.isList
            spacing: Tokens.spacing.small

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        text: (root.note && root.note.title && root.note.title.trim().length > 0)
                              ? root.note.title
                              : qsTr("Untitled")
                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                        color: (root.note && root.note.title && root.note.title.trim().length > 0)
                               ? Colours.palette.m3onSurface
                               : Colours.palette.m3onSurfaceVariant
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
                    text: root.cleanSnippet
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: 0.85
                }
            }
        }

        // LIST TRAILING GRADIENT SCRIM & BADGE
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            anchors.rightMargin: 1
            width: 125
            color: "transparent"
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: Math.max(0, frontCard.radius - 1)
            bottomRightRadius: Math.max(0, frontCard.radius - 1)
            visible: root.isList
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: Qt.alpha(frontCard.color, 0.88) }
                GradientStop { position: 1.0; color: frontCard.color }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.medium
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                StyledText {
                    text: root.remainingCount > 0
                          ? qsTr("View all (+%1)").arg(root.remainingCount)
                          : qsTr("View all")
                    font: Tokens.font.label.small
                    color: root.isHovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                }

                MaterialIcon {
                    text: "arrow_forward"
                    fontStyle: Tokens.font.icon.builders.small.scale(0.8).build()
                    color: root.isHovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // StateLayer on top with z: 10 to guarantee seamless hover detection across the entire card
        StateLayer {
            id: stateLayer
            anchors.fill: parent
            radius: frontCard.radius
            color: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
            z: 10
            onClicked: root.clicked()
        }
    }
}
