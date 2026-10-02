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

    property string rawText: ""
    property color accentColor: Colours.palette.m3primary
    property bool hasCustomColor: false
    property var listShapes: ({})

    signal shapesChanged(var shapes)
    signal doubleClicked()

    readonly property list<int> shapePool: [
        MaterialShape.Circle,
        MaterialShape.Cookie4Sided,
        MaterialShape.Cookie6Sided,
        MaterialShape.Cookie7Sided,
        MaterialShape.Cookie9Sided,
        MaterialShape.Cookie12Sided,
        MaterialShape.SoftBurst,
        MaterialShape.Sunny,
        MaterialShape.VerySunny,
        MaterialShape.Pentagon,
        MaterialShape.Gem,
        MaterialShape.Arch,
        MaterialShape.Fan,
        MaterialShape.Oval,
        MaterialShape.Ghostish,
        MaterialShape.Slanted,
        MaterialShape.Triangle,
        MaterialShape.Diamond,
        MaterialShape.ClamShell
    ]

    function getShapeForKey(key, savedShapes) {
        if (savedShapes && savedShapes[key] !== undefined) {
            return savedShapes[key];
        }
        let hash = 0;
        for (let i = 0; i < key.length; i++) {
            hash = ((hash << 5) - hash) + key.charCodeAt(i);
            hash |= 0;
        }
        return shapePool[(hash >>> 0) % shapePool.length];
    }

    function parseMarkdown(text, savedShapes) {
        if (!text || text.trim().length === 0) return [];
        const lines = text.split("\n");
        const blocks = [];

        let inCodeBlock = false;
        let codeLines = [];
        let codeStartIdx = 0;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const trimmed = line.trim();

            if (inCodeBlock) {
                if (trimmed.startsWith("```")) {
                    inCodeBlock = false;
                    blocks.push({
                        type: "code",
                        content: codeLines.join("\n"),
                        key: "code_" + codeStartIdx
                    });
                    codeLines = [];
                } else {
                    codeLines.push(line);
                }
                continue;
            }

            if (trimmed.startsWith("```")) {
                inCodeBlock = true;
                codeLines = [];
                codeStartIdx = i;
                continue;
            }

            if (trimmed.length === 0) {
                blocks.push({ type: "spacer", content: "", key: "sp_" + i });
                continue;
            }

            if (trimmed.startsWith("### ")) {
                blocks.push({ type: "h3", content: trimmed.substring(4), key: "h3_" + i });
            } else if (trimmed.startsWith("## ")) {
                blocks.push({ type: "h2", content: trimmed.substring(3), key: "h2_" + i });
            } else if (trimmed.startsWith("# ")) {
                blocks.push({ type: "h1", content: trimmed.substring(2), key: "h1_" + i });
            } else if (trimmed === "---" || trimmed === "***" || trimmed === "___" || trimmed === "- - -" || trimmed === "* * *") {
                blocks.push({ type: "hr", content: "", key: "hr_" + i });
            } else if (/^\d+[\.\)]\s+/.test(trimmed)) {
                const match = trimmed.match(/^(\d+)[\.\)]\s+(.*)/);
                const num = match ? match[1] : "1";
                const itemText = match ? match[2] : trimmed;
                const key = "o_" + num + "_" + itemText.trim().toLowerCase();
                const itemShape = getShapeForKey(key, savedShapes);
                blocks.push({ type: "ordered_item", number: num, content: itemText, key: key, shape: itemShape });
            } else if (/^[\*\-\+]\s+/.test(trimmed)) {
                const itemText = trimmed.replace(/^[\*\-\+]\s+/, "");
                const key = "u_" + itemText.trim().toLowerCase();
                const itemShape = getShapeForKey(key, savedShapes);
                blocks.push({ type: "unordered_item", content: itemText, key: key, shape: itemShape });
            } else if (trimmed.startsWith("> ") || trimmed === ">") {
                blocks.push({ type: "quote", content: trimmed.length > 2 ? trimmed.substring(2) : "", key: "q_" + i });
            } else {
                blocks.push({ type: "p", content: line, key: "p_" + i });
            }
        }

        if (inCodeBlock && codeLines.length > 0) {
            blocks.push({
                type: "code",
                content: codeLines.join("\n"),
                key: "code_" + codeStartIdx
            });
        }

        return blocks;
    }

    readonly property var blocks: parseMarkdown(root.rawText, root.listShapes)

    function resetScroll() {
        if (scrollView) {
            if (scrollView.contentItem) {
                scrollView.contentItem.contentY = 0;
                if (typeof scrollView.contentItem.returnToBounds === "function") {
                    scrollView.contentItem.returnToBounds();
                }
                if (typeof scrollView.contentItem.cancelFlick === "function") {
                    scrollView.contentItem.cancelFlick();
                }
            }
            if (scrollView.ScrollBar && scrollView.ScrollBar.vertical) {
                scrollView.ScrollBar.vertical.position = 0;
            }
        }
    }

    onRawTextChanged: {
        resetScroll();
        Qt.callLater(resetScroll);
    }

    Component.onCompleted: {
        resetScroll();
        Qt.callLater(resetScroll);
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onDoubleClicked: root.doubleClicked()
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ColumnLayout {
            id: contentCol
            width: scrollView.availableWidth
            spacing: 8

            // Empty note placeholder
            Item {
                Layout.fillWidth: true
                implicitHeight: 140
                visible: root.blocks.length === 0

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onDoubleClicked: root.doubleClicked()
                    onClicked: root.doubleClicked()
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "edit_note"
                        fontStyle: Tokens.font.icon.large
                        color: Colours.palette.m3outlineVariant
                        opacity: 0.6
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Double-click to start writing in Markdown…")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                        opacity: 0.7
                    }
                }
            }

            // Blocks Repeater
            Repeater {
                model: root.blocks

                delegate: Item {
                    id: blockItem
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: blockCol.implicitHeight

                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: root.doubleClicked()
                    }

                    ColumnLayout {
                        id: blockCol
                        width: parent.width
                        spacing: 0

                        // H1
                        StyledText {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "h1")
                            Layout.fillWidth: true
                            text: (blockItem.modelData && blockItem.modelData.content) || ""
                            font: Tokens.font.headline.small
                            color: Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                            textFormat: Text.MarkdownText
                            linkColor: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                            onLinkActivated: url => Qt.openUrlExternally(url)
                        }

                        // H2
                        StyledText {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "h2")
                            Layout.fillWidth: true
                            text: (blockItem.modelData && blockItem.modelData.content) || ""
                            font: Tokens.font.title.large
                            color: Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                            textFormat: Text.MarkdownText
                            linkColor: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                            onLinkActivated: url => Qt.openUrlExternally(url)
                        }

                        // H3
                        StyledText {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "h3")
                            Layout.fillWidth: true
                            text: (blockItem.modelData && blockItem.modelData.content) || ""
                            font: Tokens.font.title.medium
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                            textFormat: Text.MarkdownText
                            linkColor: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                            onLinkActivated: url => Qt.openUrlExternally(url)
                        }

                        // HR
                        Item {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "hr")
                            Layout.fillWidth: true
                            implicitHeight: 16

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 1
                                color: Colours.palette.m3outlineVariant
                                opacity: 0.5
                            }
                        }

                        // Blockquote
                        Rectangle {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "quote")
                            Layout.fillWidth: true
                            implicitHeight: quoteText.implicitHeight + 8
                            color: Qt.alpha(root.accentColor, 0.08)
                            radius: Tokens.rounding.small

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 3
                                color: root.accentColor
                                radius: 1.5
                            }

                            StyledText {
                                id: quoteText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                anchors.topMargin: 4
                                text: (blockItem.modelData && blockItem.modelData.content) || ""
                                font: Tokens.font.body.builders.medium.italic(true).build()
                                color: Colours.palette.m3onSurfaceVariant
                                wrapMode: Text.Wrap
                                textFormat: Text.MarkdownText
                                linkColor: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                                onLinkActivated: url => Qt.openUrlExternally(url)
                            }
                        }

                        // Code Block
                        Rectangle {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "code")
                            Layout.fillWidth: true
                            implicitHeight: codeText.implicitHeight + 16
                            color: Colours.palette.m3surfaceContainerLowest
                            border.color: Colours.palette.m3outlineVariant
                            border.width: 1
                            radius: Tokens.rounding.small

                            StyledText {
                                id: codeText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                text: (blockItem.modelData && blockItem.modelData.content) || ""
                                font.family: "Monospace"
                                font.pixelSize: 12
                                color: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }

                        // Spacer
                        Item {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "spacer")
                            Layout.fillWidth: true
                            implicitHeight: 6
                        }

                        // Unordered List Item
                        RowLayout {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "unordered_item")
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2

                            MaterialShape {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 1
                                implicitSize: 22
                                shape: (blockItem.modelData && blockItem.modelData.shape !== undefined) ? blockItem.modelData.shape : MaterialShape.Circle
                                color: root.accentColor
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: (blockItem.modelData && blockItem.modelData.content) || ""
                                font: Tokens.font.body.medium
                                color: Colours.palette.m3onSurface
                                wrapMode: Text.Wrap
                                textFormat: Text.MarkdownText
                                linkColor: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                                onLinkActivated: url => Qt.openUrlExternally(url)
                            }
                        }

                        // Ordered List Item
                        RowLayout {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "ordered_item")
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2

                            MaterialShape {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 1
                                implicitSize: 22
                                shape: (blockItem.modelData && blockItem.modelData.shape !== undefined) ? blockItem.modelData.shape : MaterialShape.Circle
                                color: root.hasCustomColor ? Qt.alpha(root.accentColor, 0.28) : Colours.palette.m3secondaryContainer

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (blockItem.modelData && blockItem.modelData.number) || "1"
                                    font: Tokens.font.label.small
                                    color: root.hasCustomColor ? root.accentColor : Colours.palette.m3onSecondaryContainer
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: (blockItem.modelData && blockItem.modelData.content) || ""
                                font: Tokens.font.body.medium
                                color: Colours.palette.m3onSurface
                                wrapMode: Text.Wrap
                                textFormat: Text.MarkdownText
                                linkColor: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                                onLinkActivated: url => Qt.openUrlExternally(url)
                            }
                        }

                        // Standard Paragraph
                        StyledText {
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "p")
                            Layout.fillWidth: true
                            text: (blockItem.modelData && blockItem.modelData.content) || ""
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                            textFormat: Text.MarkdownText
                            linkColor: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                            onLinkActivated: url => Qt.openUrlExternally(url)
                        }
                    }
                }
            }

            // Bottom empty space for double-click
            Item {
                Layout.fillWidth: true
                Layout.minimumHeight: 120

                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: root.doubleClicked()
                }
            }
        }
    }
}
