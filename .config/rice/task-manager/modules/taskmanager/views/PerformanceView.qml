import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/styles" as Styles
import "root:/services" as Services
import "../components" as Components

// PerformanceView.qml
// Layout: CPU stat bar (full width) on top, Memory stat bar (full width)
// below it, then a two-column row underneath with independently scrollable
// "top processes" lists -- CPU processes on the left, RAM processes on the
// right -- each with End Task.
//
// Usage: loaded by TaskManager.qml when Sidebar selects "Performance"

Item {
    id: root

    function formatMb(mb) {
        if (mb >= 1024) return (mb / 1024).toFixed(1) + " GB"
        return Math.round(mb) + " MB"
    }

    // Compact full-width stat bar: title, value line, small inline graph.
    component StatBar: Rectangle {
        id: bar
        required property string barTitle
        required property string valueLine
        required property var history
        required property color lineColor
        required property color fillColor

        Layout.fillWidth: true
        Layout.preferredHeight: 84
        radius: Styles.Metrics.radiusMedium
        color: Styles.Theme.cardBackground
        border.color: Styles.Theme.divider
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: Styles.Metrics.spacingMd
            spacing: Styles.Metrics.spacingLg

            ColumnLayout {
                Layout.preferredWidth: 220
                spacing: 2

                Text {
                    text: bar.barTitle
                    color: Styles.Theme.textPrimary
                    font.pixelSize: Styles.Metrics.fontSizeMd
                    font.family: Styles.Metrics.fontFamily
                    font.weight: Font.DemiBold
                }
                Text {
                    text: bar.valueLine
                    color: Styles.Theme.textSecondary
                    font.pixelSize: Styles.Metrics.fontSizeSm
                    font.family: Styles.Metrics.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Components.UsageGraph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 200
                Layout.minimumHeight: 50
                history: bar.history
                lineColor: bar.lineColor
                fillColor: bar.fillColor
            }
        }
    }

    // Scrollable ranked process list with End Task, used for both columns below.
    component ProcessListColumn: Rectangle {
        id: col
        required property string listTitle
        required property var processList
        // function(modelData) -> string, e.g. "23.6%" or "512 MB"
        required property var valueFormatter

        radius: Styles.Metrics.radiusMedium
        color: Styles.Theme.cardBackground
        border.color: Styles.Theme.divider
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Styles.Metrics.spacingMd
            spacing: Styles.Metrics.spacingSm

            Text {
                text: col.listTitle
                color: Styles.Theme.textPrimary
                font.pixelSize: Styles.Metrics.fontSizeSm
                font.family: Styles.Metrics.fontFamily
                font.weight: Font.DemiBold
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Styles.Metrics.spacingXs
                model: col.processList
                boundsBehavior: Flickable.StopAtBounds
                // Functional scrolling (wheel/drag), no visible scrollbar track.
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 34
                    radius: Styles.Metrics.radiusSmall
                    color: rowHover.containsMouse ? Styles.Theme.rowHover : "transparent"

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Styles.Metrics.spacingSm
                        anchors.rightMargin: Styles.Metrics.spacingSm
                        spacing: Styles.Metrics.spacingSm

                        Text {
                            text: modelData.name
                            color: Styles.Theme.textPrimary
                            font.pixelSize: Styles.Metrics.fontSizeSm
                            font.family: Styles.Metrics.fontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "PID " + modelData.pid
                            color: Styles.Theme.textSecondary
                            font.pixelSize: Styles.Metrics.fontSizeXs
                            font.family: Styles.Metrics.fontFamily
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: col.valueFormatter(modelData)
                            color: Styles.Theme.textSecondary
                            font.pixelSize: Styles.Metrics.fontSizeSm
                            font.family: Styles.Metrics.fontFamily
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                        }

                        Button {
                            id: endBtn
                            text: "End task"
                            Layout.preferredWidth: 72
                            onClicked: Services.ProcessService.killProcess(modelData.pid)

                            background: Rectangle {
                                radius: Styles.Metrics.radiusSmall
                                color: endBtn.hovered ? Styles.Theme.rowHover : Styles.Theme.windowBackground
                                border.color: Styles.Theme.divider
                                border.width: 1
                            }
                            contentItem: Text {
                                text: endBtn.text
                                color: Styles.Theme.textPrimary
                                font.pixelSize: Styles.Metrics.fontSizeXs
                                font.family: Styles.Metrics.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: "No data"
                    color: Styles.Theme.textDisabled
                    font.pixelSize: Styles.Metrics.fontSizeSm
                    font.family: Styles.Metrics.fontFamily
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Styles.Metrics.spacingMd
        spacing: Styles.Metrics.spacingMd

        StatBar {
            barTitle: "CPU"
            valueLine: Services.SystemMonitor.cpuPercent.toFixed(1) + "%"
            history: Services.SystemMonitor.cpuHistory
            lineColor: Styles.Theme.cpuGraphColor
            fillColor: Styles.Theme.cpuGraphFill
        }

        StatBar {
            barTitle: "Memory"
            valueLine: Services.SystemMonitor.ramPercent.toFixed(1) + "%  ("
                + Services.SystemMonitor.ramUsedMb.toFixed(0) + " / "
                + Services.SystemMonitor.ramTotalMb.toFixed(0) + " MB)"
            history: Services.SystemMonitor.ramHistory
            lineColor: Styles.Theme.ramGraphColor
            fillColor: Styles.Theme.ramGraphFill
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Styles.Metrics.spacingMd

            ProcessListColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 300
                listTitle: "Top CPU processes"
                processList: Services.SystemMonitor.topCpuProcesses
                valueFormatter: (m) => (m.cpu !== undefined ? m.cpu.toFixed(1) + "%" : "--")
            }

            ProcessListColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 300
                listTitle: "Top memory processes"
                processList: Services.SystemMonitor.topRamProcesses
                valueFormatter: (m) => root.formatMb(m.mem_mb)
            }
        }
    }
}
