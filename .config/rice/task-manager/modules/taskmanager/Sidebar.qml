import QtQuick
import QtQuick.Layouts
import "root:/styles" as Styles

// Sidebar.qml
// Left navigation rail: Processes / Performance / Startup. Mirrors Win11
// Task Manager's left nav (icon + label per item, active item highlighted
// with a colored indicator bar).
//
// Usage:
//   Sidebar {
//       Layout.fillHeight: true
//       selectedTab: "processes"
//       onTabSelected: tab => taskManagerRoot.currentTab = tab
//   }

Rectangle {
    id: root

    property string selectedTab: "processes" // "processes" | "performance" | "startup"
    signal tabSelected(string tab)

    implicitWidth: Styles.Metrics.sidebarWidth
    color: Styles.Theme.sidebarBackground

   readonly property var items: [
        { id: "processes", label: "Processes", glyph: "\u2630" },   // ☰
        { id: "performance", label: "Performance", glyph: "\u2637" }, // ☷
        { id: "startup", label: "Startup apps", glyph: "\u25B6" },   // ▶
        { id: "storage", label: "Storage", glyph: "\u25A1" }         // □
    ]
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Styles.Metrics.spacingSm
        spacing: 2

        Repeater {
            model: root.items

            delegate: Rectangle {
                id: navItem
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Styles.Metrics.sidebarItemHeight
                Layout.leftMargin: Styles.Metrics.spacingSm
                Layout.rightMargin: Styles.Metrics.spacingSm
                radius: Styles.Metrics.radiusSmall

                readonly property bool isActive: root.selectedTab === modelData.id

                color: isActive ? Styles.Theme.rowSelected
                                 : (navMouseArea.containsMouse ? Styles.Theme.rowHover : "transparent")

                Behavior on color { ColorAnimation { duration: Styles.Metrics.animFast } }

                // Active indicator bar, Win11-style left accent strip
                Rectangle {
                    visible: navItem.isActive
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 1.5
                    color: Styles.Theme.tabActiveIndicator
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Styles.Metrics.spacingMd
                    anchors.rightMargin: Styles.Metrics.spacingSm
                    spacing: Styles.Metrics.spacingSm

                    Text {
                        text: navItem.modelData.glyph
                        color: navItem.isActive ? Styles.Theme.textPrimary : Styles.Theme.textSecondary
                        font.pixelSize: Styles.Metrics.fontSizeMd
                    }

                    Text {
                        text: navItem.modelData.label
                        color: navItem.isActive ? Styles.Theme.textPrimary : Styles.Theme.textSecondary
                        font.pixelSize: Styles.Metrics.fontSizeSm
                        font.family: Styles.Metrics.fontFamily
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: navMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.tabSelected(navItem.modelData.id)
                }
            }
        }

        Item { Layout.fillHeight: true } // pushes items to top
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Styles.Theme.divider
    }
}
