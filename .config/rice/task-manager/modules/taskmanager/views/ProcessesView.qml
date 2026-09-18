import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/styles" as Styles
import "root:/services" as Services
import "../components" as Components
import "../models" as Models

// ProcessesView.qml
// The "Processes" tab — Win11 Task Manager's default landing tab.
// Search bar up top, column headers, then a scrollable sorted process list.
//
// Usage: loaded by TaskManager.qml when Sidebar selects "Processes"

Item {
    id: root

    Models.ProcessModel {
        id: processModel
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Styles.Metrics.spacingMd
        spacing: Styles.Metrics.spacingSm

        // ---- Search bar ----
        Components.SearchBar {
            Layout.fillWidth: true
        }

        // ---- Column headers ----
        Rectangle {
            Layout.fillWidth: true
            height: Styles.Metrics.columnHeaderHeight
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Styles.Metrics.spacingMd + Styles.Metrics.processIconSize + Styles.Metrics.spacingSm
                anchors.rightMargin: Styles.Metrics.spacingMd
                spacing: Styles.Metrics.spacingSm

                Text {
                    text: "Name"
                    color: Styles.Theme.textSecondary
                    font.pixelSize: Styles.Metrics.fontSizeXs
                    font.family: Styles.Metrics.fontFamily
                    Layout.fillWidth: true
                    Layout.preferredWidth: 200
                }
                Text {
                    text: "PID"
                    color: Styles.Theme.textSecondary
                    font.pixelSize: Styles.Metrics.fontSizeXs
                    font.family: Styles.Metrics.fontFamily
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 70
                }
                Text {
                    text: "CPU"
                    color: Styles.Theme.textSecondary
                    font.pixelSize: Styles.Metrics.fontSizeXs
                    font.family: Styles.Metrics.fontFamily
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 60
                }
                Text {
                    text: "Memory"
                    color: Styles.Theme.textSecondary
                    font.pixelSize: Styles.Metrics.fontSizeXs
                    font.family: Styles.Metrics.fontFamily
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 90
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Styles.Theme.divider
            }
        }

        // ---- Process list ----
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: processModel.rows
            boundsBehavior: Flickable.StopAtBounds

            property int selectedPid: -1

            delegate: Components.ProcessRow {
                id: rowDelegate
                required property var modelData

                width: listView.width
                pid: modelData.pid
                name: modelData.name
                cpu: modelData.cpu
                memMb: modelData.mem_mb
                memPercent: modelData.mem_percent
                selected: listView.selectedPid === modelData.pid
                isGroup: modelData.isGroup
                groupCount: modelData.groupCount
                indent: modelData.indent
                childPids: modelData.childPids
                _expanded: modelData.isGroup && processModel.expandedGroups[modelData.name] === true

                onRowClicked: pid => listView.selectedPid = pid
                onToggleGroupRequested: name => processModel.toggleGroup(name)
                onEndTaskRequested: pids => {
                    if (pids.includes(listView.selectedPid)) listView.selectedPid = -1
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            // Empty state when search filters everything out
            Text {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: "No processes match your search"
                color: Styles.Theme.textDisabled
                font.pixelSize: Styles.Metrics.fontSizeSm
                font.family: Styles.Metrics.fontFamily
            }
        }

        // ---- Footer: process count + total resource summary ----
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                Text {
                    text: listView.count + " processes"
                    color: Styles.Theme.textSecondary
                    font.pixelSize: Styles.Metrics.fontSizeXs
                    font.family: Styles.Metrics.fontFamily
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "CPU " + Services.SystemMonitor.cpuPercent.toFixed(0) + "%    "
                        + "Memory " + Services.SystemMonitor.ramPercent.toFixed(0) + "%"
                    color: Styles.Theme.textSecondary
                    font.pixelSize: Styles.Metrics.fontSizeXs
                    font.family: Styles.Metrics.fontFamily
                }
            }
        }
    }
}
