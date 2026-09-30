pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import M3Shapes
import Caelestia.Components
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

    readonly property var activeTodos: NotesStore.getSortedTodos()
    readonly property var trashTodosList: NotesStore.getCompletedAndTrashTodos()
    readonly property var repeatingTrashList: NotesStore.getRepeatingTrashTodos()
    readonly property var generalTrashList: NotesStore.getGeneralTrashTodos()
    readonly property int remainingCount: NotesStore.getRemainingTodosCount()
    readonly property int trashCount: NotesStore.getTrashCount()
    readonly property int generalTrashCount: NotesStore.getGeneralTrashCount()

    property bool showTrash: false
    property bool confirmEmptyTrash: false
    property bool isAdding: false
    property bool calendarPickerOpen: false
    property string selectedNewDue: ""
    property bool newTodoRepeating: false
    readonly property bool isDatePicking: root.calendarPickerOpen || (detailView && detailView.calendarOpen)

    Timer {
        id: confirmEmptyTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmEmptyTrash = false
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: NotesStore.isEditingTodo ? 1 : 0

        // ==========================================
        // INDEX 0: MAIN TODO LIST VIEW
        // ==========================================
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: root.showTrash ? qsTr("Trash") : qsTr("To-do")
                        font: Tokens.font.title.medium
                        color: Colours.palette.m3onSurface
                        Layout.maximumWidth: 100
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3surfaceContainerHigh
                        implicitHeight: 20
                        implicitWidth: countBadgeText.implicitWidth + 12

                        StyledText {
                            id: countBadgeText
                            anchors.centerIn: parent
                            text: root.showTrash
                                  ? qsTr(`${root.trashCount}`)
                                  : (root.remainingCount === 0 ? qsTr("All done") : qsTr(`${root.remainingCount} left`))
                            font: Tokens.font.label.small
                            color: root.showTrash
                                   ? Colours.palette.m3onSurfaceVariant
                                   : (root.remainingCount === 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant)
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Sort toggle button (Latest ↔ Due Date), only shown in active todo mode
                    IconButton {
                        visible: !root.showTrash
                        icon: NotesStore.todoSortMode === "date" ? "calendar_month" : "sort"
                        type: NotesStore.todoSortMode === "date" ? ButtonBase.Filled : ButtonBase.Tonal
                        onClicked: NotesStore.toggleTodoSort()
                    }

                    // Empty Trash button (clears general trash only, preserves repeating habits)
                    IconButton {
                        visible: root.showTrash && root.generalTrashCount > 0
                        icon: root.confirmEmptyTrash ? "check" : "delete_sweep"
                        type: root.confirmEmptyTrash ? ButtonBase.Filled : ButtonBase.Tonal
                        inactiveColour: root.confirmEmptyTrash ? Colours.palette.m3error : Colours.palette.m3secondaryContainer
                        inactiveOnColour: root.confirmEmptyTrash ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                        onClicked: {
                            if (!root.confirmEmptyTrash) {
                                root.confirmEmptyTrash = true;
                                confirmEmptyTimer.restart();
                            } else {
                                confirmEmptyTimer.stop();
                                root.confirmEmptyTrash = false;
                                NotesStore.emptyAllTrash();
                            }
                        }
                    }

                    // Trashcan toggle button (switches between active to-dos and cross-marked completed/removed)
                    IconButton {
                        icon: root.showTrash ? "checklist" : "delete_outline"
                        type: root.showTrash ? ButtonBase.Filled : ButtonBase.Tonal
                        onClicked: {
                            root.flushPendingActions();
                            root.confirmEmptyTrash = false;
                            confirmEmptyTimer.stop();
                            root.showTrash = !root.showTrash;
                            if (root.showTrash) {
                                root.isAdding = false;
                                root.calendarPickerOpen = false;
                                root.newTodoRepeating = false;
                            }
                        }
                    }

                    // Add button (visible in active to-do mode)
                    IconButton {
                        visible: !root.showTrash
                        icon: root.isAdding ? "close" : "add"
                        type: root.isAdding ? ButtonBase.Text : ButtonBase.Filled
                        onClicked: {
                            root.flushPendingActions();
                            root.isAdding = !root.isAdding;
                            if (root.isAdding) {
                                root.selectedNewDue = "";
                                root.newTodoRepeating = false;
                                root.calendarPickerOpen = false;
                                Qt.callLater(() => {
                                    newTodoInput.text = "";
                                    newTodoInput.forceActiveFocus();
                                });
                            } else {
                                root.calendarPickerOpen = false;
                                root.newTodoRepeating = false;
                            }
                        }
                    }
                }

                // Inline Add Row (visible when isAdding is true)
                StyledRect {
                    id: inlineAddBox
                    Layout.fillWidth: true
                    Layout.fillHeight: root.isAdding && root.calendarPickerOpen
                    implicitHeight: root.isAdding ? (root.calendarPickerOpen ? 368 : 44) : 0
                    visible: root.isAdding
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainerHigh
                    clip: true

                    Behavior on implicitHeight {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        // Row 1: Checkbox icon + Input text + Date button + Add button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            MaterialShape {
                                Layout.alignment: Qt.AlignVCenter
                                implicitSize: 18
                                shape: MaterialShape.Square
                                color: "transparent"
                                strokeColor: Colours.palette.m3primary
                                strokeWidth: 1.5
                            }

                            TextField {
                                id: newTodoInput
                                Layout.fillWidth: true
                                maximumLength: 300
                                enabled: !root.calendarPickerOpen
                                placeholderText: qsTr("Add a new to-do…")
                                placeholderTextColor: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.medium
                                color: Colours.palette.m3onSurface
                                background: null
                                padding: 0
                                selectByMouse: true

                                Keys.onReturnPressed: root.commitNewTodo()
                                Keys.onEnterPressed: root.commitNewTodo()
                                Keys.onEscapePressed: {
                                    if (root.calendarPickerOpen) {
                                        root.calendarPickerOpen = false;
                                    } else {
                                        root.isAdding = false;
                                        text = "";
                                        root.selectedNewDue = "";
                                    }
                                }
                            }

                            // Repeating habit toggle button (morphs from circle to pill with text)
                            CustomMouseArea {
                                id: repeatToggleBtn
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: 26
                                implicitWidth: root.newTodoRepeating ? (repeatContent.implicitWidth + 14) : 26
                                opacity: datePickerTrigger.isDateActive ? 0.35 : 1.0
                                cursorShape: Qt.PointingHandCursor

                                Behavior on implicitWidth {
                                    Anim { type: Anim.DefaultSpatial }
                                }

                                Behavior on opacity {
                                    Anim { type: Anim.FastEffects }
                                }

                                onClicked: {
                                    if (root.newTodoRepeating) {
                                        root.newTodoRepeating = false;
                                    } else {
                                        root.newTodoRepeating = true;
                                        root.selectedNewDue = "";
                                        root.calendarPickerOpen = false;
                                    }
                                }

                                StyledRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.full
                                    clip: true
                                    color: root.newTodoRepeating
                                           ? Colours.palette.m3primary
                                           : "transparent"
                                    border.width: 1
                                    border.color: root.newTodoRepeating
                                                  ? Colours.palette.m3primary
                                                  : Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    RowLayout {
                                        id: repeatContent
                                        anchors.centerIn: parent
                                        spacing: 4

                                        MaterialIcon {
                                            text: "repeat"
                                            fontStyle: Tokens.font.icon.small
                                            color: root.newTodoRepeating
                                                   ? Colours.palette.m3onPrimary
                                                   : Colours.palette.m3onSurfaceVariant
                                        }

                                        StyledText {
                                            visible: root.newTodoRepeating
                                            text: qsTr("Repeating")
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3onPrimary
                                        }
                                    }
                                }
                            }

                            // Calendar Date Button / Pill (morphs from circle to pill with text)
                            CustomMouseArea {
                                id: datePickerTrigger
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: 26
                                implicitWidth: datePickerTrigger.isDateActive ? (dateBtnContent.implicitWidth + 14) : 26
                                opacity: root.newTodoRepeating ? 0.35 : 1.0
                                cursorShape: Qt.PointingHandCursor

                                readonly property bool isDateActive: root.calendarPickerOpen || root.selectedNewDue.length > 0
                                readonly property var dueInfo: NotesStore.formatDuePill(root.selectedNewDue)

                                Behavior on implicitWidth {
                                    Anim { type: Anim.DefaultSpatial }
                                }

                                Behavior on opacity {
                                    Anim { type: Anim.FastEffects }
                                }

                                StyledRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.full
                                    clip: true
                                    color: root.calendarPickerOpen
                                           ? Colours.palette.m3primary
                                           : (root.selectedNewDue.length > 0 ? Colours.palette.m3surfaceContainerHighest : "transparent")
                                    border.width: 1
                                    border.color: root.calendarPickerOpen
                                                  ? Colours.palette.m3primary
                                                  : (root.selectedNewDue.length > 0 ? Qt.alpha(Colours.palette.m3primary, 0.5) : Qt.alpha(Colours.palette.m3outlineVariant, 0.5))

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    RowLayout {
                                        id: dateBtnContent
                                        anchors.centerIn: parent
                                        spacing: 4

                                        MaterialIcon {
                                            text: root.selectedNewDue.length > 0 ? "event" : "calendar_today"
                                            fontStyle: Tokens.font.icon.small
                                            color: root.calendarPickerOpen
                                                   ? Colours.palette.m3onPrimary
                                                   : (root.selectedNewDue.length > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant)
                                        }

                                        StyledText {
                                            visible: datePickerTrigger.isDateActive
                                            text: datePickerTrigger.dueInfo ? datePickerTrigger.dueInfo.label : qsTr("Date")
                                            font: Tokens.font.label.small
                                            color: root.calendarPickerOpen
                                                   ? Colours.palette.m3onPrimary
                                                   : (root.selectedNewDue.length > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant)
                                        }
                                    }
                                }

                                onClicked: {
                                    if (root.newTodoRepeating) {
                                        root.newTodoRepeating = false;
                                    }
                                    root.calendarPickerOpen = !root.calendarPickerOpen;
                                }
                            }

                            IconButton {
                                icon: "check"
                                type: ButtonBase.Text
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                onClicked: root.commitNewTodo()
                            }
                        }

                        // Row 2: Embedded Calendar Picker (visible when calendarPickerOpen is true)
                        TodoDatePicker {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.calendarPickerOpen
                            currentDateStr: root.selectedNewDue
                            onDateSelected: (dateStr) => {
                                root.selectedNewDue = (root.selectedNewDue === dateStr ? "" : dateStr);
                                root.newTodoRepeating = false;
                            }
                            onCancelled: {
                                root.calendarPickerOpen = false;
                                Qt.callLater(() => {
                                    newTodoInput.forceActiveFocus();
                                });
                            }
                        }
                    }
                }

                // Scrollable List of Todos (hidden when picking date)
                ScrollView {
                    id: todoScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.calendarPickerOpen
                    visible: !root.calendarPickerOpen
                    clip: true

                    ColumnLayout {
                        width: todoScrollView.availableWidth
                        spacing: 2

                        // Empty State
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 40
                            visible: (root.showTrash ? root.trashTodosList.length : root.activeTodos.length) === 0
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.showTrash ? "auto_delete" : "check_circle"
                                fontStyle: Tokens.font.icon.extraLarge
                                color: Colours.palette.m3primary
                                opacity: 0.8
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.showTrash ? qsTr("Trash is empty") : qsTr("All clear for today")
                                font: Tokens.font.body.medium
                                color: Colours.palette.m3onSurface
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.leftMargin: Tokens.padding.medium
                                Layout.rightMargin: Tokens.padding.medium
                                horizontalAlignment: Text.AlignHCenter
                                text: root.showTrash
                                      ? qsTr("Completed and removed tasks will appear here")
                                      : qsTr("Tap + to add your first task")
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                                wrapMode: Text.Wrap
                            }
                        }

                        // Reusable Todo Row Component
                        Component {
                            id: todoRowDelegate

                            Item {
                                id: todoRow
                                required property var modelData

                                readonly property string todoId: modelData ? (modelData.id || "") : ""
                                property bool actionCommitted: false
                                readonly property int taskShape: root.getTaskShape(modelData)

                                function commitCompletion() {
                                    if (!actionCommitted && todoId.length > 0) {
                                        actionCommitted = true;
                                        scratchDoneAnimation.stop();
                                        NotesStore.toggleTodo(todoId);
                                    }
                                }

                                function commitDeletion() {
                                    if (!actionCommitted && todoId.length > 0) {
                                        actionCommitted = true;
                                        scratchDeleteAnimation.stop();
                                        NotesStore.deleteTodo(todoId);
                                    }
                                }

                                Component.onDestruction: {
                                    if (isScratching && !actionCommitted) {
                                        commitCompletion();
                                    } else if (isDeleting && !actionCommitted) {
                                        commitDeletion();
                                    }
                                }

                                Layout.fillWidth: true
                                implicitHeight: 38

                                readonly property bool isDone: !!(modelData && modelData.done)
                                readonly property var duePillInfo: NotesStore.formatDuePill(modelData ? modelData.due : null)

                                property bool isScratching: false
                                property bool isDeleting: false
                                property real scratchProgress: 0.0
                                property real rowOpacity: 1.0

                                readonly property bool isRowHovered: rowHoverHandler.hovered || (rowActionBtn && (rowActionBtn.hovered || rowActionBtn.pressed)) || hoverGraceTimer.running

                                HoverHandler {
                                    id: rowHoverHandler
                                    onHoveredChanged: {
                                        if (!hovered) {
                                            hoverGraceTimer.restart();
                                        } else {
                                            hoverGraceTimer.stop();
                                        }
                                    }
                                }

                                Timer {
                                    id: hoverGraceTimer
                                    interval: 200
                                    repeat: false
                                }

                                clip: true
                                opacity: rowOpacity

                                // 1-Second Scratching-Off & Fade-Out Animation for Completion
                                SequentialAnimation {
                                    id: scratchDoneAnimation

                                    ScriptAction {
                                        script: {
                                            todoRow.isScratching = true;
                                        }
                                    }

                                    // Phase 1: Strike line animates across the text (400ms)
                                    ParallelAnimation {
                                        NumberAnimation {
                                            target: todoRow
                                            property: "scratchProgress"
                                            from: 0.0
                                            to: 1.0
                                            duration: 400
                                            easing.type: Easing.OutCubic
                                        }
                                        NumberAnimation {
                                            target: todoLabel
                                            property: "opacity"
                                            to: 0.5
                                            duration: 400
                                        }
                                    }

                                    // Phase 2: Fade out & collapse row height to move rest of tasks up (600ms)
                                    ParallelAnimation {
                                        NumberAnimation {
                                            target: todoRow
                                            property: "rowOpacity"
                                            to: 0.0
                                            duration: 350
                                            easing.type: Easing.InQuad
                                        }
                                        NumberAnimation {
                                            target: todoRow
                                            property: "implicitHeight"
                                            to: 0
                                            duration: 550
                                            easing.type: Easing.InOutQuad
                                        }
                                    }

                                    // Phase 3: Update model state at ~1000ms
                                    ScriptAction {
                                        script: {
                                            todoRow.commitCompletion();
                                        }
                                    }
                                }

                                // 1-Second Scratching-Off & Fade-Out Animation for Deletion
                                SequentialAnimation {
                                    id: scratchDeleteAnimation

                                    ScriptAction {
                                        script: {
                                            todoRow.isDeleting = true;
                                        }
                                    }

                                    // Phase 1: Red scratch line draws across text (400ms)
                                    ParallelAnimation {
                                        NumberAnimation {
                                            target: todoRow
                                            property: "scratchProgress"
                                            from: 0.0
                                            to: 1.0
                                            duration: 400
                                            easing.type: Easing.OutCubic
                                        }
                                        NumberAnimation {
                                            target: todoLabel
                                            property: "opacity"
                                            to: 0.4
                                            duration: 400
                                        }
                                    }

                                    // Phase 2: Fade out & collapse row height (600ms)
                                    ParallelAnimation {
                                        NumberAnimation {
                                            target: todoRow
                                            property: "rowOpacity"
                                            to: 0.0
                                            duration: 350
                                            easing.type: Easing.InQuad
                                        }
                                        NumberAnimation {
                                            target: todoRow
                                            property: "implicitHeight"
                                            to: 0
                                            duration: 550
                                            easing.type: Easing.InOutQuad
                                        }
                                    }

                                    ScriptAction {
                                        script: {
                                            todoRow.commitDeletion();
                                        }
                                    }
                                }

                                // Background highlight on hover
                                StyledRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.small
                                    color: Colours.palette.m3onSurface
                                    opacity: todoRow.isRowHovered ? 0.06 : 0

                                    Behavior on opacity {
                                        Anim { type: Anim.FastEffects }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 4
                                    spacing: Tokens.spacing.small

                                    // Custom Checkbox with M3Shapes Morphing Animation
                                    CustomMouseArea {
                                        id: checkMouseArea
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 22
                                        implicitHeight: 22
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.showTrash) {
                                                NotesStore.restoreTodo(todoRow.todoId);
                                            } else {
                                                if (!todoRow.isScratching && !todoRow.isDeleting && !todoRow.actionCommitted) {
                                                    scratchDoneAnimation.start();
                                                }
                                            }
                                        }

                                        MaterialShape {
                                            id: checkShape
                                            anchors.centerIn: parent
                                            implicitSize: 18

                                            readonly property bool isChecked: todoRow.isDone || root.showTrash || todoRow.isScratching

                                            shape: isChecked ? todoRow.taskShape : MaterialShape.Square

                                            color: isChecked ? Colours.palette.m3primary : "transparent"
                                            strokeColor: isChecked ? Colours.palette.m3primary : (checkMouseArea.containsMouse || todoRow.isRowHovered ? Colours.palette.m3primary : Colours.palette.m3outline)
                                            strokeWidth: isChecked ? 0 : 1.5

                                            scale: checkMouseArea.pressed ? 0.88 : (checkMouseArea.containsMouse ? 1.08 : 1.0)

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
                                                opacity: checkShape.isChecked ? 1 : 0
                                                scale: checkShape.isChecked ? 1.0 : 0.4

                                                Behavior on opacity {
                                                    Anim { type: Anim.FastEffects }
                                                }

                                                Behavior on scale {
                                                    Anim { type: Anim.DefaultSpatial }
                                                }
                                            }
                                        }
                                    }

                                    // Label text with click to open view mode & strikethrough / scratching overlay
                                    CustomMouseArea {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitHeight: Math.max(22, todoLabel.implicitHeight)
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!todoRow.isScratching && !todoRow.isDeleting && !todoRow.actionCommitted) {
                                                NotesStore.openTodo(todoRow.modelData);
                                            }
                                        }

                                        Item {
                                            anchors.fill: parent
                                            clip: true

                                            StyledText {
                                                id: todoLabel
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: todoRow.modelData ? (todoRow.modelData.title || "") : ""
                                                font: Tokens.font.body.medium
                                                color: (todoRow.isDone || root.showTrash || todoRow.isScratching) ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                                                opacity: (todoRow.isDone || root.showTrash) ? 0.7 : 1.0
                                                elide: Text.ElideRight
                                                maximumLineCount: 1

                                                Behavior on opacity {
                                                    Anim {}
                                                }
                                            }

                                            // Subtle Wavy Strike-through & Living Worm Scratch Animation
                                            WavyLine {
                                                id: scratchWavyLine

                                                readonly property bool isActionActive: todoRow.isScratching || todoRow.isDeleting
                                                readonly property bool isResting: (todoRow.isDone || root.showTrash) && !isActionActive

                                                visible: isActionActive || isResting
                                                anchors.left: todoLabel.left
                                                anchors.verticalCenter: todoLabel.verticalCenter
                                                width: Math.max(1, Math.min(todoLabel.implicitWidth, todoLabel.width))
                                                height: 12

                                                lineWidth: 2
                                                amplitudeMultiplier: isActionActive ? 0.75 : 0.55
                                                frequency: Math.max(2, Math.round(width / 24))
                                                fullLength: width
                                                value: isActionActive ? todoRow.scratchProgress : 1.0
                                                color: todoRow.isDeleting ? Colours.palette.m3error : (isActionActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant)
                                                opacity: isActionActive ? 1.0 : 0.7

                                                Anim on waveProgress {
                                                    running: scratchWavyLine.isActionActive
                                                    from: 0
                                                    to: 1
                                                    duration: 500
                                                    easing.type: Easing.Linear
                                                    loops: Animation.Infinite
                                                }
                                            }
                                        }
                                    }

                                    // Repeating Pill (Active view)
                                    StyledRect {
                                        visible: !root.showTrash && !!(todoRow.modelData && todoRow.modelData.repeating)
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Tokens.rounding.full
                                        implicitHeight: 18
                                        implicitWidth: repeatingPillText.implicitWidth + 10
                                        color: Qt.alpha(Colours.palette.m3tertiary, 0.22)

                                        StyledText {
                                            id: repeatingPillText
                                            anchors.centerIn: parent
                                            text: qsTr("Repeating")
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3tertiary
                                        }
                                    }

                                    // Resetting Cooldown Pill in Trash
                                    StyledRect {
                                        visible: root.showTrash && !!(todoRow.modelData && todoRow.modelData.repeating)
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Tokens.rounding.full
                                        implicitHeight: 18
                                        implicitWidth: resettingText.implicitWidth + 10
                                        color: Qt.alpha(Colours.palette.m3secondary, 0.22)

                                        StyledText {
                                            id: resettingText
                                            anchors.centerIn: parent
                                            text: NotesStore.getResettingTimeText()
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3secondary
                                        }
                                    }

                                    // Smart Due Pill (Today, Tomorrow, in X days, Overdue)
                                    StyledRect {
                                        visible: !root.showTrash && todoRow.duePillInfo !== null
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Tokens.rounding.full
                                        implicitHeight: 18
                                        implicitWidth: dueText.implicitWidth + 10
                                        color: {
                                            if (!todoRow.duePillInfo) return Colours.palette.m3surfaceContainerHigh;
                                            switch (todoRow.duePillInfo.status) {
                                                case "overdue": return Colours.palette.m3error;
                                                case "today": return Colours.palette.m3tertiary;
                                                case "tomorrow": return Colours.palette.m3secondaryContainer;
                                                default: return Colours.palette.m3surfaceContainerHigh;
                                            }
                                        }

                                        StyledText {
                                            id: dueText
                                            anchors.centerIn: parent
                                            text: todoRow.duePillInfo ? todoRow.duePillInfo.label : ""
                                            font: Tokens.font.label.small
                                            color: {
                                                if (!todoRow.duePillInfo) return Colours.palette.m3onSurfaceVariant;
                                                switch (todoRow.duePillInfo.status) {
                                                    case "overdue": return Colours.palette.m3onError;
                                                    case "today": return Colours.palette.m3onTertiary;
                                                    case "tomorrow": return Colours.palette.m3onSecondaryContainer;
                                                    default: return Colours.palette.m3onSurfaceVariant;
                                                }
                                            }
                                        }
                                    }

                                    // Fixed-slot action button (NEVER resizes row layout!)
                                    Item {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        Layout.alignment: Qt.AlignVCenter

                                        IconButton {
                                            id: rowActionBtn
                                            anchors.fill: parent
                                            opacity: todoRow.isRowHovered ? 1 : 0
                                            enabled: todoRow.isRowHovered
                                            icon: root.showTrash ? "restore" : "close"
                                            type: ButtonBase.Text
                                            onHoveredChanged: {
                                                if (!hovered && !rowHoverHandler.hovered) {
                                                    hoverGraceTimer.restart();
                                                }
                                            }
                                            onClicked: {
                                                if (root.showTrash) {
                                                    NotesStore.restoreTodo(todoRow.todoId);
                                                } else {
                                                    if (!todoRow.isScratching && !todoRow.isDeleting && !todoRow.actionCommitted) {
                                                        scratchDeleteAnimation.start();
                                                    }
                                                }
                                            }

                                            Behavior on opacity {
                                                Anim { type: Anim.FastEffects }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Active Todos List (Visible when not in Trash)
                        Repeater {
                            id: activeTodoRepeater
                            visible: !root.showTrash
                            model: root.showTrash ? [] : root.activeTodos
                            delegate: todoRowDelegate
                        }

                        // Trash View: Repeating Habits Section (Resting)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            visible: root.showTrash && root.repeatingTrashList.length > 0

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                Layout.bottomMargin: 2
                                spacing: 6

                                MaterialIcon {
                                    text: "repeat"
                                    fontStyle: Tokens.font.icon.small
                                    color: Colours.palette.m3tertiary
                                }

                                StyledText {
                                    text: qsTr(`Repeating Habits (${root.repeatingTrashList.length})`)
                                    font: Tokens.font.label.medium
                                    color: Colours.palette.m3tertiary
                                }
                            }

                            Repeater {
                                id: repeatingTrashRepeater
                                model: root.showTrash ? root.repeatingTrashList : []
                                delegate: todoRowDelegate
                            }
                        }

                        // Subtle divider between Repeating and General trash
                        StyledRect {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            Layout.bottomMargin: 6
                            implicitHeight: 1
                            color: Colours.palette.m3outlineVariant
                            opacity: 0.3
                            visible: root.showTrash && root.repeatingTrashList.length > 0 && root.generalTrashList.length > 0
                        }

                        // Trash View: General Trash Section
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            visible: root.showTrash && root.generalTrashList.length > 0

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                Layout.bottomMargin: 2
                                spacing: 6

                                MaterialIcon {
                                    text: "delete_outline"
                                    fontStyle: Tokens.font.icon.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    text: qsTr(`General (${root.generalTrashList.length})`)
                                    font: Tokens.font.label.medium
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }

                            Repeater {
                                id: generalTrashRepeater
                                model: root.showTrash ? root.generalTrashList : []
                                delegate: todoRowDelegate
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // INDEX 1: TODO DETAIL VIEW (FULL TEXT TAKEOVER)
        // ==========================================
        Item {
            TodoDetailView {
                id: detailView
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
            }
        }
    }

    function flushPendingActions() {
        const repeaters = [activeTodoRepeater, repeatingTrashRepeater, generalTrashRepeater];
        for (let r = 0; r < repeaters.length; ++r) {
            const rep = repeaters[r];
            if (rep) {
                for (let i = 0; i < rep.count; ++i) {
                    const item = rep.itemAt(i);
                    if (item) {
                        if (item.isScratching && !item.actionCommitted) {
                            item.commitCompletion();
                        } else if (item.isDeleting && !item.actionCommitted) {
                            item.commitDeletion();
                        }
                    }
                }
            }
        }
    }

    function commitNewTodo() {
        const text = newTodoInput.text.trim();
        if (text.length > 0) {
            NotesStore.addTodo(text, root.selectedNewDue, root.newTodoRepeating);
            newTodoInput.text = "";
            root.selectedNewDue = "";
            root.newTodoRepeating = false;
            root.calendarPickerOpen = false;
            root.isAdding = false;
        }
    }
}
