pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

StyledRect {
    id: root

    signal dateSelected(string dateStr)
    signal cancelled()

    property date viewDate: new Date()
    property string currentDateStr: ""

    radius: Tokens.rounding.medium
    color: Colours.tPalette.m3surfaceContainerHigh
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
    implicitHeight: inner.implicitHeight + Tokens.padding.medium * 2
    implicitWidth: 320
    clip: true

    function prevMonth() {
        viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1);
    }

    function nextMonth() {
        viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1);
    }

    function resetToToday() {
        viewDate = new Date();
    }

    function formatDate(d) {
        const y = d.getFullYear();
        const m = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1);
        const day = (d.getDate() < 10 ? "0" : "") + d.getDate();
        return y + "-" + m + "-" + day;
    }

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.extraSmall

        // Month Navigation Row (exact 1:1 match with Calendar.qml)
        RowLayout {
            id: monthNavigationRow
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                isRound: true
                icon: "chevron_left"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.prevMonth()
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: monthYearDisplay.implicitWidth + Tokens.padding.large * 2
                implicitHeight: monthYearDisplay.implicitHeight + Tokens.padding.extraSmall * 2

                StateLayer {
                    color: Colours.palette.m3primary
                    radius: pressed ? Tokens.rounding.small : height / 2
                    onClicked: root.resetToToday()

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                StyledText {
                    id: monthYearDisplay
                    anchors.centerIn: parent
                    text: grid.title
                    color: Colours.palette.m3primary
                    font: Tokens.font.title.builders.small.capitalisation(Font.Capitalize).build()
                }
            }

            IconButton {
                isRound: true
                icon: "chevron_right"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.nextMonth()
            }

            IconButton {
                isRound: true
                icon: "close"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.cancelled()
            }
        }

        // Day of Week Header Row (exact 1:1 match with Calendar.qml)
        DayOfWeekRow {
            id: daysRow
            Layout.fillWidth: true
            locale: grid.locale

            delegate: StyledText {
                required property var model
                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: (model.day === 0 || model.day === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
            }
        }

        // Calendar Month Grid Area (exact 1:1 match with Calendar.qml)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 180
            implicitHeight: Math.max(grid.implicitHeight, 180)

            MonthGrid {
                id: grid
                month: root.viewDate.getMonth()
                year: root.viewDate.getFullYear()
                anchors.fill: parent
                spacing: 3
                locale: Qt.locale()

                delegate: Item {
                    id: dayItem
                    required property var model

                    readonly property string dayDateStr: root.formatDate(model.date)
                    readonly property bool isSelected: root.currentDateStr.length > 0 && root.currentDateStr === dayDateStr
                    readonly property int dayOfWeek: model.date.getDay()

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small

                    // Selected date indicator: Solid 4-leaf clover with continuous slow rotation
                    MaterialShape {
                        id: selectedShape
                        visible: dayItem.isSelected
                        anchors.centerIn: parent
                        implicitSize: Math.max(20, Math.min(parent.width, parent.height) - 2)
                        shape: MaterialShape.Clover4Leaf
                        color: Colours.palette.m3tertiary
                        z: 1

                        NumberAnimation on rotation {
                            running: dayItem.isSelected
                            from: 0
                            to: 360
                            duration: 10000
                            loops: Animation.Infinite
                        }
                    }

                    StyledText {
                        id: text
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: grid.locale.toString(dayItem.model.day)
                        color: {
                            if (dayItem.isSelected)
                                return Colours.palette.m3onTertiary;
                            if (dayItem.dayOfWeek === 0 || dayItem.dayOfWeek === 6)
                                return Colours.palette.m3tertiary;
                            return Colours.palette.m3onSurfaceVariant;
                        }
                        opacity: dayItem.isSelected || dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                        font: (dayItem.isSelected || dayItem.model.today) ? Tokens.font.body.builders.small.weight(Font.Bold).build() : Tokens.font.body.small
                        renderType: Text.QtRendering
                        z: 2
                    }

                    TapHandler {
                        onTapped: root.dateSelected(dayItem.dayDateStr)
                    }
                }
            }

            // MaterialShape Sunny Today Indicator with Colouriser (Exact Caelestia shape)
            MaterialShape {
                id: todayIndicator

                readonly property Item todayItem: grid.contentItem.children.find(c => c.model && c.model.today) ?? null
                property Item today

                readonly property bool isTodaySelected: {
                    if (!root.currentDateStr || root.currentDateStr.length === 0) return false;
                    const now = new Date();
                    return root.currentDateStr === root.formatDate(now);
                }

                onTodayItemChanged: {
                    if (todayItem)
                        today = todayItem;
                }

                x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                y: today ? today.y + (today.height - implicitHeight) / 2 : 0

                implicitSize: today ? Math.min(today.width, today.height) - 2 : 0
                shape: MaterialShape.Sunny

                clip: true
                color: Colours.palette.m3primary
                opacity: (todayItem && !isTodaySelected) ? 1 : 0

                Colouriser {
                    x: -todayIndicator.x
                    y: -todayIndicator.y

                    implicitWidth: grid.width
                    implicitHeight: grid.height

                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }
            }
        }
    }
}
