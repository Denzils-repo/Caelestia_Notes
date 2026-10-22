pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    property string rawText: ""
    property color accentColor: Colours.palette.m3primary
    property bool hasCustomColor: false
    property var listShapes: ({})

    signal shapesChanged(var shapes)
    signal editRequested(int charIndex)
    signal doubleClicked()

    function requestEditAt(charIndex) {
        root.editRequested(charIndex !== undefined ? charIndex : 0);
        root.doubleClicked();
    }

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
        hash ^= hash >>> 16;
        hash = Math.imul(hash, 0x85ebca6b);
        hash ^= hash >>> 13;
        hash = Math.imul(hash, 0xc2b2ae35);
        hash ^= hash >>> 16;
        return shapePool[(hash >>> 0) % shapePool.length];
    }

    function parseMarkdown(text, savedShapes) {
        if (!text || text.trim().length === 0) return [];
        const lines = text.split("\n");
        const blocks = [];

        let inCodeBlock = false;
        let codeLines = [];
        let codeStartIdx = 0;
        let codeCharOffset = 0;
        let codeFenceLen = 4;
        let currentOffset = 0;

        function isTableDelimiter(delimLine) {
            if (!delimLine || !delimLine.includes("-") || !delimLine.includes("|")) return false;
            let s = delimLine.trim();
            if (s.startsWith("|")) s = s.substring(1);
            if (s.endsWith("|")) s = s.substring(0, s.length - 1);
            const cells = s.split("|");
            if (cells.length < 1) return false;
            return cells.every(c => {
                const trimmedCell = c.trim();
                return trimmedCell.length > 0 && /^:?-+:?$/.test(trimmedCell);
            });
        }

        function splitTableRow(rowStr) {
            let s = rowStr.trim();
            if (s.startsWith("|")) s = s.substring(1);
            if (s.endsWith("|")) s = s.substring(0, s.length - 1);
            const escaped = s.replace(/\\\|/g, "\uE000");
            return escaped.split("|").map(c => c.replace(/\uE000/g, "|").trim());
        }

        function parseAlignments(delimStr) {
            const cells = splitTableRow(delimStr);
            return cells.map(c => {
                const left = c.startsWith(":");
                const right = c.endsWith(":");
                if (left && right) return "center";
                if (right) return "right";
                return "left";
            });
        }

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const trimmed = line.trim();

            if (inCodeBlock) {
                if (trimmed.startsWith("```")) {
                    inCodeBlock = false;
                    blocks.push({
                        type: "code",
                        content: codeLines.join("\n"),
                        key: "code_" + codeStartIdx,
                        charOffset: codeCharOffset,
                        fenceLen: codeFenceLen,
                        lineIndex: codeStartIdx
                    });
                    codeLines = [];
                } else {
                    codeLines.push(line);
                }
                currentOffset += line.length + 1;
                continue;
            }

            if (trimmed.startsWith("```")) {
                inCodeBlock = true;
                codeLines = [];
                codeStartIdx = i;
                codeCharOffset = currentOffset;
                codeFenceLen = line.length + 1;
                currentOffset += line.length + 1;
                continue;
            }

            const endOffset = currentOffset + line.length;

            if (trimmed.length === 0) {
                blocks.push({ type: "spacer", content: "", key: "sp_" + i, charOffset: currentOffset, endOffset: endOffset, lineIndex: i });
                currentOffset += line.length + 1;
                continue;
            }

            if (trimmed.startsWith("### ")) {
                blocks.push({ type: "h3", content: trimmed.substring(4), key: "h3_" + i, charOffset: currentOffset, endOffset: endOffset, prefixLen: 4, lineIndex: i });
            } else if (trimmed.startsWith("## ")) {
                blocks.push({ type: "h2", content: trimmed.substring(3), key: "h2_" + i, charOffset: currentOffset, endOffset: endOffset, prefixLen: 3, lineIndex: i });
            } else if (trimmed.startsWith("# ")) {
                blocks.push({ type: "h1", content: trimmed.substring(2), key: "h1_" + i, charOffset: currentOffset, endOffset: endOffset, prefixLen: 2, lineIndex: i });
            } else if (trimmed === "---" || trimmed === "***" || trimmed === "___" || trimmed === "- - -" || trimmed === "* * *") {
                blocks.push({ type: "hr", content: "", key: "hr_" + i, charOffset: currentOffset, endOffset: endOffset, prefixLen: 0, lineIndex: i });
            } else if (/^\d+[\.\)]\s+/.test(trimmed)) {
                const match = trimmed.match(/^(\d+)[\.\)]\s+(.*)/);
                const num = match ? match[1] : "1";
                const itemText = match ? match[2] : trimmed;
                const key = "o_" + num + "_" + itemText.trim().toLowerCase();
                const itemShape = getShapeForKey(key, savedShapes);
                const prefixMatch = line.match(/^\s*\d+[\.\)]\s+/);
                const pLen = prefixMatch ? prefixMatch[0].length : (num.length + 2);
                blocks.push({ type: "ordered_item", number: num, content: itemText, key: key, shape: itemShape, charOffset: currentOffset, endOffset: endOffset, prefixLen: pLen, lineIndex: i });
            } else if (/^[\*\-\+]\s+/.test(trimmed)) {
                const itemText = trimmed.replace(/^[\*\-\+]\s+/, "");
                const key = "u_" + itemText.trim().toLowerCase();
                const itemShape = getShapeForKey(key, savedShapes);
                const prefixMatch = line.match(/^\s*[\*\-\+]\s+/);
                const pLen = prefixMatch ? prefixMatch[0].length : 2;
                blocks.push({ type: "unordered_item", content: itemText, key: key, shape: itemShape, charOffset: currentOffset, endOffset: endOffset, prefixLen: pLen, lineIndex: i });
            } else if (trimmed.startsWith("> ") || trimmed === ">") {
                const pLen = trimmed.startsWith("> ") ? 2 : 1;
                blocks.push({ type: "quote", content: trimmed.length > 2 ? trimmed.substring(2) : "", key: "q_" + i, charOffset: currentOffset, endOffset: endOffset, prefixLen: pLen, lineIndex: i });
            } else if (line.includes("|") && i + 1 < lines.length && isTableDelimiter(lines[i + 1])) {
                const rawHeaders = splitTableRow(line);
                const rawAlignments = parseAlignments(lines[i + 1]);
                const alignments = [];
                for (let c = 0; c < rawHeaders.length; c++) {
                    alignments.push(rawAlignments[c] || "left");
                }

                const tableStartOffset = currentOffset;
                const tableRows = [];
                const rowOffsets = [];

                // Header row offset
                rowOffsets.push({
                    start: currentOffset,
                    end: currentOffset + line.length
                });
                currentOffset += line.length + 1;

                // Delimiter line offset
                const delimLine = lines[i + 1];
                rowOffsets.push({
                    start: currentOffset,
                    end: currentOffset + delimLine.length
                });
                currentOffset += delimLine.length + 1;

                let j = i + 2;
                while (j < lines.length) {
                    const dataLine = lines[j];
                    const trimmedData = dataLine.trim();
                    if (trimmedData.length === 0 || !dataLine.includes("|")) {
                        break;
                    }
                    if (trimmedData.startsWith("```") || trimmedData.startsWith("#") || trimmedData === "---") {
                        break;
                    }

                    const rawCells = splitTableRow(dataLine);
                    const cells = [];
                    for (let c = 0; c < rawHeaders.length; c++) {
                        cells.push(rawCells[c] !== undefined ? rawCells[c] : "");
                    }
                    tableRows.push(cells);

                    rowOffsets.push({
                        start: currentOffset,
                        end: currentOffset + dataLine.length
                    });
                    currentOffset += dataLine.length + 1;
                    j++;
                }

                const lastOffsetObj = rowOffsets[rowOffsets.length - 1];
                const tableEndOffset = lastOffsetObj ? lastOffsetObj.end : currentOffset;

                const colWidths = [];
                for (let c = 0; c < rawHeaders.length; c++) {
                    let maxLen = (rawHeaders[c] || "").length;
                    for (let r = 0; r < tableRows.length; r++) {
                        const cellLen = (tableRows[r][c] || "").length;
                        if (cellLen > maxLen) maxLen = cellLen;
                    }
                    const w = Math.max(130, Math.min(420, maxLen * 12 + 48));
                    colWidths.push(w);
                }

                blocks.push({
                    type: "table",
                    headers: rawHeaders,
                    alignments: alignments,
                    rows: tableRows,
                    colWidths: colWidths,
                    rowOffsets: rowOffsets,
                    key: "tbl_" + i,
                    charOffset: tableStartOffset,
                    endOffset: tableEndOffset,
                    lineIndex: i
                });

                i = j - 1;
                continue;
            } else {
                blocks.push({ type: "p", content: line, key: "p_" + i, charOffset: currentOffset, endOffset: endOffset, prefixLen: 0, lineIndex: i });
            }
            currentOffset += line.length + 1;
        }

        if (inCodeBlock && codeLines.length > 0) {
            blocks.push({
                type: "code",
                content: codeLines.join("\n"),
                key: "code_" + codeStartIdx,
                charOffset: codeCharOffset,
                fenceLen: codeFenceLen,
                lineIndex: codeStartIdx
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

    property bool shouldAnimate: NotesStore.shouldAnimateNoteOpen
    property bool contentReady: !shouldAnimate

    Timer {
        id: popInTimer
        interval: 260
        repeat: false
        onTriggered: {
            root.contentReady = true;
            if (NotesStore.shouldAnimateNoteOpen) {
                NotesStore.shouldAnimateNoteOpen = false;
            }
            resetShouldAnimateTimer.restart();
        }
    }

    Timer {
        id: resetShouldAnimateTimer
        interval: 600
        repeat: false
        onTriggered: {
            root.shouldAnimate = false;
        }
    }

    function triggerPopIn() {
        root.shouldAnimate = true;
        root.contentReady = false;
        popInTimer.restart();
    }

    onRawTextChanged: {
        resetScroll();
        Qt.callLater(resetScroll);
    }

    Component.onCompleted: {
        resetScroll();
        Qt.callLater(resetScroll);
        if (root.shouldAnimate) {
            triggerPopIn();
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onDoubleClicked: root.requestEditAt(root.rawText.length)
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
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
            maskSource: markdownScrollMask

            Rectangle {
                id: markdownScrollMask

                anchors.fill: parent
                visible: false
                layer.enabled: true

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        position: 0
                        color: Qt.rgba(0, 0, 0, scrollView.topFadeOpacity)
                    }
                    GradientStop {
                        position: scrollView.fadeAmount
                        color: Qt.rgba(0, 0, 0, 1)
                    }
                    GradientStop {
                        position: 1 - scrollView.fadeAmount
                        color: Qt.rgba(0, 0, 0, 1)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, scrollView.bottomFadeOpacity)
                    }
                }
            }
        }

        ColumnLayout {
            id: contentCol
            width: scrollView.availableWidth
            spacing: 8

            // Empty note placeholder
            Item {
                Layout.fillWidth: true
                implicitHeight: 140
                visible: root.blocks.length === 0

                opacity: root.contentReady ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: root.contentReady && root.shouldAnimate
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onDoubleClicked: root.requestEditAt(0)
                    onClicked: root.requestEditAt(0)
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
                    required property int index

                    property bool revealed: !root.shouldAnimate

                    Connections {
                        target: root
                        function onContentReadyChanged() {
                            if (!root.contentReady) {
                                blockItem.revealed = false;
                            }
                        }
                    }

                    Timer {
                        id: revealTimer
                        interval: Math.min(blockItem.index * 16, 120)
                        running: root.contentReady && !blockItem.revealed
                        repeat: false
                        onTriggered: {
                            blockItem.revealed = true;
                        }
                    }

                    Layout.fillWidth: true
                    implicitHeight: blockCol.implicitHeight

                    opacity: (root.contentReady && blockItem.revealed) ? 1.0 : 0.0

                    transform: Translate {
                        y: (root.contentReady && blockItem.revealed) ? 0 : 4
                        Behavior on y {
                            enabled: root.contentReady && root.shouldAnimate
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Behavior on opacity {
                        enabled: root.contentReady && root.shouldAnimate
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    function calculateTargetOffset(mouseY) {
                        const data = blockItem.modelData;
                        if (!data) return 0;
                        const baseOffset = data.charOffset !== undefined ? data.charOffset : 0;
                        const endOffset = data.endOffset !== undefined ? data.endOffset : (baseOffset + (data.content || "").length);
                        const content = data.content || "";

                        if (data.type === "code") {
                            const cLines = content.split("\n");
                            const numLines = Math.max(1, cLines.length);
                            const lineIdx = Math.max(0, Math.min(numLines - 1, Math.floor((mouseY / Math.max(1, blockItem.height)) * numLines)));
                            let codeOffset = 0;
                            for (let k = 0; k < lineIdx; k++) {
                                codeOffset += cLines[k].length + 1;
                            }
                            const fenceLen = data.fenceLen !== undefined ? data.fenceLen : 4;
                            const lineLen = (cLines[lineIdx] || "").length;
                            return baseOffset + fenceLen + codeOffset + lineLen;
                        }

                        if (data.type === "table") {
                            const rOffsets = data.rowOffsets || [];
                            if (rOffsets.length > 0) {
                                const numRows = rOffsets.length;
                                const rIdx = Math.max(0, Math.min(numRows - 1, Math.floor((mouseY / Math.max(1, blockItem.height)) * numRows)));
                                return rOffsets[rIdx].end;
                            }
                            return endOffset;
                        }

                        if (data.type === "p" && pText && pText.lineCount > 1) {
                            const lines = pText.lineCount;
                            const lineIdx = Math.max(0, Math.min(lines - 1, Math.floor((mouseY / Math.max(1, blockItem.height)) * lines)));
                            if (lineIdx === lines - 1) return endOffset;
                            return baseOffset + Math.min(content.length, Math.floor(((lineIdx + 1) / lines) * content.length));
                        }

                        return endOffset;
                    }

                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: (mouse) => {
                            root.requestEditAt(blockItem.calculateTargetOffset(mouse.y));
                        }
                    }

                    ColumnLayout {
                        id: blockCol
                        width: parent.width
                        spacing: 0

                        // H1
                        StyledText {
                            id: h1Text
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
                            id: h2Text
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
                            id: h3Text
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
                        StyledRect {
                            id: codeBlockRect
                            clip: true
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "code")
                            Layout.fillWidth: true
                            implicitHeight: codeBlockCol.implicitHeight
                            height: implicitHeight
                            radius: Tokens.rounding.medium
                            color: root.hasCustomColor
                                   ? Qt.tint(Colours.palette.m3surfaceContainerLowest, Qt.alpha(root.accentColor, 0.12))
                                   : Colours.palette.m3surfaceContainerLowest
                            border.width: 1
                            border.color: codeBlockHover.hovered
                                          ? (root.hasCustomColor ? root.accentColor : Colours.palette.m3primary)
                                          : (root.hasCustomColor ? Qt.alpha(root.accentColor, 0.4) : Qt.alpha(Colours.palette.m3outlineVariant, 0.45))

                            Behavior on border.color { CAnim {} }
                            Behavior on color { CAnim {} }

                            HoverHandler {
                                id: codeBlockHover
                            }

                            ColumnLayout {
                                id: codeBlockCol
                                width: parent.width
                                spacing: 0

                                // Code Block Header Bar
                                Rectangle {
                                    id: codeHeaderBar
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    height: 30
                                    color: root.hasCustomColor
                                           ? Qt.tint(Colours.palette.m3surfaceContainerHigh, Qt.alpha(root.accentColor, 0.22))
                                           : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.75)

                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        MaterialIcon {
                                            text: "terminal"
                                            font: Tokens.font.icon.size(13).build()
                                            color: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                                            opacity: 0.9
                                        }

                                        StyledText {
                                            text: qsTr("Code")
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3onSurfaceVariant
                                            opacity: 0.85
                                        }
                                    }

                                    // Integrated Copy Button
                                    StyledRect {
                                        id: copyBtn
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter

                                        implicitWidth: 24
                                        implicitHeight: 24
                                        radius: Tokens.rounding.extraSmall

                                        property bool copied: false

                                        color: {
                                            if (copied) return Qt.alpha(root.hasCustomColor ? root.accentColor : Colours.palette.m3primary, 0.25);
                                            if (copyMouseArea.containsMouse) return Colours.palette.m3surfaceContainerHighest;
                                            return Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.5);
                                        }
                                        border.width: 1
                                        border.color: {
                                            if (copied) return root.hasCustomColor ? root.accentColor : Colours.palette.m3primary;
                                            if (copyMouseArea.containsMouse) return Colours.palette.m3outline;
                                            return Qt.alpha(Colours.palette.m3outlineVariant, 0.35);
                                        }

                                        opacity: copyMouseArea.containsMouse || copyBtn.copied ? 1.0 : (codeBlockHover.hovered ? 0.9 : 0.6)
                                        scale: copyMouseArea.pressed ? 0.92 : (copyMouseArea.containsMouse ? 1.06 : 1.0)

                                        Behavior on color { CAnim {} }
                                        Behavior on border.color { CAnim {} }
                                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                                        Behavior on scale { Anim { type: Anim.DefaultSpatial } }

                                        MaterialIcon {
                                            id: copyIcon
                                            anchors.centerIn: parent
                                            text: copyBtn.copied ? "check" : "content_copy"
                                            font: Tokens.font.icon.size(12).build()
                                            color: {
                                                if (copyBtn.copied) return root.hasCustomColor ? root.accentColor : Colours.palette.m3primary;
                                                if (copyMouseArea.containsMouse) return Colours.palette.m3onSurface;
                                                return Colours.palette.m3onSurfaceVariant;
                                            }

                                            Behavior on color { CAnim {} }
                                        }

                                        Timer {
                                            id: copyFeedbackTimer
                                            interval: 1500
                                            repeat: false
                                            onTriggered: copyBtn.copied = false
                                        }

                                        function copyCode(): void {
                                            const codeContent = (blockItem.modelData && blockItem.modelData.content) || "";
                                            if (!codeContent) return;
                                            Quickshell.clipboardText = codeContent;
                                            copyBtn.copied = true;
                                            copyFeedbackTimer.restart();
                                            Toaster.toast(qsTr("Code copied to clipboard"), "", "content_copy");
                                        }

                                        MouseArea {
                                            id: copyMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            preventStealing: true
                                            onClicked: (mouse) => {
                                                mouse.accepted = true;
                                                copyBtn.copyCode();
                                            }
                                            onDoubleClicked: (mouse) => {
                                                mouse.accepted = true;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: root.hasCustomColor ? Qt.alpha(root.accentColor, 0.25) : Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                                    }
                                }

                                // Code Text Area
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: codeText.implicitHeight + 20

                                    StyledText {
                                        id: codeText
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        anchors.topMargin: 10
                                        text: (blockItem.modelData && blockItem.modelData.content) || ""
                                        font.family: "JetBrains Mono, Fira Code, Monospace"
                                        font.pixelSize: 12
                                        color: Colours.palette.m3onSurface
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                    }
                                }
                            }
                        }

                        // Table Block
                        StyledRect {
                            id: tableCard
                            clip: true
                            visible: !!(blockItem.modelData && blockItem.modelData.type === "table")
                            Layout.fillWidth: true
                            implicitHeight: tableCol.implicitHeight
                            radius: Tokens.rounding.medium
                            color: root.hasCustomColor
                                   ? Qt.tint(Colours.palette.m3surfaceContainerLowest, Qt.alpha(root.accentColor, 0.12))
                                   : Colours.palette.m3surfaceContainerLowest
                            border.color: root.hasCustomColor
                                          ? Qt.alpha(root.accentColor, 0.45)
                                          : Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                            border.width: 1

                            Behavior on color { CAnim {} }
                            Behavior on border.color { CAnim {} }

                            readonly property var headers: (blockItem.modelData && blockItem.modelData.headers) || []
                            readonly property var alignments: (blockItem.modelData && blockItem.modelData.alignments) || []
                            readonly property var rows: (blockItem.modelData && blockItem.modelData.rows) || []
                            readonly property var colWidths: (blockItem.modelData && blockItem.modelData.colWidths) || []

                            property real scrollX: 0
                            readonly property real maxScrollX: Math.max(0, totalTableWidth - tableViewport.width)
                            readonly property bool hasOverflow: totalTableWidth > tableViewport.width + 1

                            readonly property real totalBaseWidth: {
                                if (!tableCard.colWidths || tableCard.colWidths.length === 0) return 0;
                                let s = 0;
                                for (let i = 0; i < tableCard.colWidths.length; i++) s += tableCard.colWidths[i];
                                return s;
                            }

                            readonly property real totalTableWidth: Math.max(tableViewport.width, totalBaseWidth)

                            function getColumnWidth(colIndex: int): real {
                                if (!tableCard.colWidths || colIndex < 0 || colIndex >= tableCard.colWidths.length) return 100;
                                const baseW = tableCard.colWidths[colIndex];
                                if (tableCard.totalBaseWidth <= 0) return baseW;
                                const availW = tableViewport.width;
                                if (tableCard.totalBaseWidth < availW) {
                                    return (baseW / tableCard.totalBaseWidth) * availW;
                                }
                                return baseW;
                            }

                            ColumnLayout {
                                id: tableCol
                                width: parent.width
                                spacing: 0

                                // Table Viewport: plain Item (no Flickable) so normal mouse wheel passes 100% to outer note view
                                Item {
                                    id: tableViewport
                                    Layout.fillWidth: true
                                    implicitHeight: tableGridCol.height
                                    clip: true

                                    WheelHandler {
                                        target: tableViewport
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        acceptedModifiers: Qt.ShiftModifier
                                        onWheel: (event) => {
                                            if (event.angleDelta.y !== 0 && tableCard.hasOverflow) {
                                                tableCard.scrollX = Math.max(0, Math.min(tableCard.maxScrollX, tableCard.scrollX - event.angleDelta.y));
                                                event.accepted = true;
                                            }
                                        }
                                    }

                                    Column {
                                        id: tableGridCol
                                        x: -tableCard.scrollX
                                        width: tableCard.totalTableWidth

                                        // Header Row
                                        Rectangle {
                                            id: headerRowRect
                                            width: parent.width
                                            height: 44
                                            color: root.hasCustomColor
                                                   ? Qt.tint(Colours.palette.m3surfaceContainerHigh, Qt.alpha(root.accentColor, 0.25))
                                                   : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.85)

                                            Behavior on color { CAnim {} }

                                            Row {
                                                anchors.fill: parent

                                                Repeater {
                                                    id: headerRepeater
                                                    model: tableCard.headers

                                                    Item {
                                                        id: headerCell
                                                        required property int index
                                                        required property string modelData

                                                        width: tableCard.getColumnWidth(headerCell.index)
                                                        height: parent.height

                                                        StyledText {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 16
                                                            anchors.rightMargin: 16
                                                            verticalAlignment: Text.AlignVCenter
                                                            horizontalAlignment: {
                                                                const a = (tableCard.alignments && tableCard.alignments[headerCell.index]) || "left";
                                                                if (a === "center") return Text.AlignHCenter;
                                                                if (a === "right") return Text.AlignRight;
                                                                return Text.AlignLeft;
                                                            }
                                                            text: headerCell.modelData
                                                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                                                            color: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                                                            textFormat: Text.MarkdownText
                                                            wrapMode: Text.NoWrap
                                                            elide: Text.ElideRight

                                                            Behavior on color { CAnim {} }
                                                        }

                                                        Rectangle {
                                                            anchors.right: parent.right
                                                            anchors.top: parent.top
                                                            anchors.bottom: parent.bottom
                                                            width: 1
                                                            color: root.hasCustomColor ? Qt.alpha(root.accentColor, 0.3) : Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                                                            visible: headerCell.index < tableCard.headers.length - 1
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                width: parent.width
                                                height: 1
                                                color: root.hasCustomColor ? Qt.alpha(root.accentColor, 0.5) : Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
                                            }
                                        }

                                        // Data Rows
                                        Repeater {
                                            id: rowRepeater
                                            model: tableCard.rows

                                            Rectangle {
                                                id: dataRowRect
                                                required property int index
                                                required property var modelData

                                                readonly property int rowIndex: dataRowRect.index
                                                readonly property var rowCells: dataRowRect.modelData

                                                width: parent.width
                                                height: 40
                                                color: rowHover.hovered ? Qt.alpha(root.accentColor, 0.12) :
                                                       (dataRowRect.rowIndex % 2 === 1 ? Qt.alpha(root.accentColor, 0.04) : "transparent")

                                                Behavior on color { CAnim {} }

                                                HoverHandler {
                                                    id: rowHover
                                                }

                                                Row {
                                                    anchors.fill: parent

                                                    Repeater {
                                                        id: cellRepeater
                                                        model: dataRowRect.rowCells

                                                        Item {
                                                            id: dataCell
                                                            required property int index
                                                            required property string modelData

                                                            width: tableCard.getColumnWidth(dataCell.index)
                                                            height: parent.height

                                                            StyledText {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: 16
                                                                anchors.rightMargin: 16
                                                                verticalAlignment: Text.AlignVCenter
                                                                horizontalAlignment: {
                                                                    const a = (tableCard.alignments && tableCard.alignments[dataCell.index]) || "left";
                                                                    if (a === "center") return Text.AlignHCenter;
                                                                    if (a === "right") return Text.AlignRight;
                                                                    return Text.AlignLeft;
                                                                }
                                                                text: dataCell.modelData
                                                                font: Tokens.font.body.medium
                                                                color: Colours.palette.m3onSurface
                                                                textFormat: Text.MarkdownText
                                                                linkColor: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
                                                                onLinkActivated: url => Qt.openUrlExternally(url)
                                                                wrapMode: Text.NoWrap
                                                                elide: Text.ElideRight
                                                            }

                                                            Rectangle {
                                                                anchors.right: parent.right
                                                                anchors.top: parent.top
                                                                anchors.bottom: parent.bottom
                                                                width: 1
                                                                color: root.hasCustomColor ? Qt.alpha(root.accentColor, 0.18) : Qt.alpha(Colours.palette.m3outlineVariant, 0.25)
                                                                visible: dataCell.index < tableCard.headers.length - 1
                                                            }
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width
                                                    height: 1
                                                    color: root.hasCustomColor ? Qt.alpha(root.accentColor, 0.18) : Qt.alpha(Colours.palette.m3outlineVariant, 0.25)
                                                    visible: dataRowRect.rowIndex < tableCard.rows.length - 1
                                                }
                                            }
                                        }
                                    }
                                }

                                // Bottom Horizontal Scroll Bar Container
                                Rectangle {
                                    id: tableBottomBar
                                    visible: tableCard.hasOverflow
                                    Layout.fillWidth: true
                                    implicitHeight: 22
                                    height: 22
                                    color: root.hasCustomColor
                                           ? Qt.tint(Colours.palette.m3surfaceContainerLow, Qt.alpha(root.accentColor, 0.16))
                                           : Colours.palette.m3surfaceContainerLow

                                    Behavior on color { CAnim {} }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: root.hasCustomColor ? Qt.alpha(root.accentColor, 0.3) : Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
                                    }

                                    Item {
                                        id: scrollTrack
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: 12
                                        height: 6

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 3
                                            color: Qt.alpha(root.accentColor, 0.16)
                                        }

                                        Rectangle {
                                            id: scrollThumb
                                            readonly property real trackWidth: scrollTrack.width
                                            readonly property real visibleRatio: tableCard.totalTableWidth > 0 ? (tableViewport.width / tableCard.totalTableWidth) : 1.0
                                            readonly property real thumbWidth: Math.max(32, trackWidth * Math.min(1.0, visibleRatio))
                                            readonly property real scrollProgress: tableCard.maxScrollX > 0 ? (tableCard.scrollX / tableCard.maxScrollX) : 0

                                            width: thumbWidth
                                            height: 6
                                            radius: 3
                                            x: scrollProgress * (trackWidth - thumbWidth)
                                            anchors.verticalCenter: parent.verticalCenter

                                            color: thumbMouse.pressed ? (root.hasCustomColor ? root.accentColor : Colours.palette.m3primary) :
                                                   (thumbMouse.containsMouse ? (root.hasCustomColor ? Qt.lighter(root.accentColor, 1.15) : Colours.palette.m3onSurface) :
                                                   Qt.alpha(root.hasCustomColor ? root.accentColor : Colours.palette.m3primary, 0.82))

                                            Behavior on color { CAnim {} }
                                        }

                                        MouseArea {
                                            id: thumbMouse
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            preventStealing: true

                                            onPressed: (mouse) => {
                                                mouse.accepted = true;
                                                seekTo(mouse.x);
                                            }

                                            onPositionChanged: (mouse) => {
                                                if (pressed) {
                                                    mouse.accepted = true;
                                                    seekTo(mouse.x);
                                                }
                                            }

                                            onDoubleClicked: (mouse) => {
                                                mouse.accepted = true;
                                            }

                                            function seekTo(mouseX) {
                                                const avail = scrollTrack.width - scrollThumb.thumbWidth;
                                                if (avail <= 0) return;
                                                const targetX = Math.max(0, Math.min(avail, mouseX - scrollThumb.thumbWidth / 2));
                                                const progress = targetX / avail;
                                                tableCard.scrollX = progress * tableCard.maxScrollX;
                                            }
                                        }
                                    }
                                }
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
                                id: uText
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
                                id: oText
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
                            id: pText
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
                    onDoubleClicked: root.requestEditAt(root.rawText.length)
                }
            }
        }
    }
}
