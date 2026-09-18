import QtQuick
import QtQuick.Controls
import "root:/styles" as Styles
import "root:/services" as Services

// ProcessContextMenu.qml
// Right-click popup menu for a process row. "End Task" is the primary action
// (mirrors Windows 11), with a couple of secondary items for completeness.
//
// Usage: instantiated via Loader in ProcessRow.qml, positioned at cursor.
//   item.targetPid = pid; item.targetName = name; item.open()

Popup {
    id: root

    property var targetPids: []
    property string targetName: ""
    property bool isGroupTarget: false

    signal endTaskConfirmed(var pids)

    width: Styles.Metrics.contextMenuWidth
    height: menuColumn.implicitHeight + Styles.Metrics.spacingXs * 2
    padding: Styles.Metrics.spacingXs
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: Styles.Theme.contextMenuBackground
        radius: Styles.Metrics.radiusMedium
        border.color: Styles.Theme.divider
        border.width: 1

        // Subtle drop shadow feel via a second rect behind (cheap shadow substitute)
        layer.enabled: true
    }

    Column {
        id: menuColumn
        width: parent.width
        spacing: 0

        Text {
            text: root.targetName
            color: Styles.Theme.textSecondary
            font.pixelSize: Styles.Metrics.fontSizeXs
            font.family: Styles.Metrics.fontFamily
            elide: Text.ElideRight
            width: parent.width
            leftPadding: Styles.Metrics.spacingSm
            topPadding: Styles.Metrics.spacingXs
            bottomPadding: Styles.Metrics.spacingXs
        }

        Rectangle { width: parent.width; height: 1; color: Styles.Theme.divider }

        MenuItemRow {
            label: "Switch to"
            onClicked: root.close()
        }

        MenuItemRow {
            label: "Details"
            onClicked: root.close()
        }

        MenuItemRow {
            label: "Open file location"
            onClicked: root.close()
        }

        Rectangle { width: parent.width; height: 1; color: Styles.Theme.divider }

        MenuItemRow {
            label: root.isGroupTarget ? "End task (all processes)" : "End task"
            danger: true
            onClicked: {
                Services.ProcessService.killGroup(root.targetPids)
                root.endTaskConfirmed(root.targetPids)
                root.close()
            }
        }
    }

    // Inline reusable menu row component
    component MenuItemRow: Rectangle {
        id: menuItem
        property string label: ""
        property bool danger: false
        signal clicked()

        width: parent.width
        height: Styles.Metrics.contextMenuItemHeight
        radius: Styles.Metrics.radiusSmall
        color: itemMouseArea.containsMouse ? Styles.Theme.contextMenuHover : "transparent"

        Behavior on color { ColorAnimation { duration: Styles.Metrics.animFast } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Styles.Metrics.spacingSm
            anchors.verticalCenter: parent.verticalCenter
            text: menuItem.label
            color: menuItem.danger ? Styles.Theme.danger : Styles.Theme.textPrimary
            font.pixelSize: Styles.Metrics.fontSizeSm
            font.family: Styles.Metrics.fontFamily
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menuItem.clicked()
        }
    }
}
