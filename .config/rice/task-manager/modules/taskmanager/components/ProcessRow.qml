import QtQuick
import QtQuick.Layouts
import "root:/styles" as Styles

// ProcessRow.qml
// A single row in the Processes tab ListView -- either a normal process,
// a collapsible group parent (e.g. "code (11)"), or an indented child row
// under an expanded group. Right-click opens ProcessContextMenu.qml; ending
// a group task kills every child PID via childPids.

Rectangle {
    id: root

    property int pid: 0
    property string name: ""
    property real cpu: 0
    property real memMb: 0
    property real memPercent: 0
    property bool selected: false

    property bool isGroup: false
    property int groupCount: 1
    property int indent: 0
    property var childPids: []

    signal endTaskRequested(var pids)
    signal rowClicked(int pid)
    signal toggleGroupRequested(string name)

    height: Styles.Metrics.processRowHeight
    color: selected ? Styles.Theme.rowSelected
                     : (rowMouseArea.containsMouse ? Styles.Theme.rowHover : "transparent")
    radius: Styles.Metrics.radiusSmall

    Behavior on color { ColorAnimation { duration: Styles.Metrics.animFast } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Styles.Metrics.spacingMd + (root.indent * Styles.Metrics.spacingXl)
        anchors.rightMargin: Styles.Metrics.spacingMd
        spacing: Styles.Metrics.spacingSm

        // Expand/collapse arrow -- only visible on group parent rows
        Text {
            visible: root.isGroup
            text: root.isGroup && root._expanded ? "\u25BE" : "\u25B8" // ▾ / ▸
            color: Styles.Theme.textSecondary
            font.pixelSize: Styles.Metrics.fontSizeXs
            Layout.preferredWidth: 12

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: root.toggleGroupRequested(root.name)
            }
        }
        Item { visible: !root.isGroup; Layout.preferredWidth: 12 }

        Rectangle {
            width: Styles.Metrics.processIconSize
            height: Styles.Metrics.processIconSize
            radius: Styles.Metrics.radiusSmall
            color: Styles.Theme.cardBackground
            border.color: Styles.Theme.divider

            Text {
                anchors.centerIn: parent
                text: root.name.length > 0 ? root.name.charAt(0).toUpperCase() : "?"
                color: Styles.Theme.textSecondary
                font.pixelSize: Styles.Metrics.fontSizeXs
            }
        }

        Text {
            text: root.isGroup ? root.name + " (" + root.groupCount + ")" : root.name
            color: Styles.Theme.textPrimary
            font.pixelSize: Styles.Metrics.fontSizeMd
            font.family: Styles.Metrics.fontFamily
            font.weight: root.isGroup ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.preferredWidth: 200
        }

        Text {
            text: root.isGroup ? "" : root.pid
            color: Styles.Theme.textSecondary
            font.pixelSize: Styles.Metrics.fontSizeSm
            font.family: Styles.Metrics.fontFamily
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 70
        }

        Text {
            text: root.cpu.toFixed(1) + "%"
            color: Styles.Theme.usageColor(root.cpu)
            font.pixelSize: Styles.Metrics.fontSizeSm
            font.family: Styles.Metrics.fontFamily
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 60
        }

        Text {
            text: root.memMb.toFixed(0) + " MB"
            color: Styles.Theme.usageColor(root.memPercent)
            font.pixelSize: Styles.Metrics.fontSizeSm
            font.family: Styles.Metrics.fontFamily
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 90
        }
    }

    // Tracks expand state visually via the arrow glyph -- ProcessesView.qml
    // passes the current expanded state in via this property so the arrow
    // flips instantly on click, without waiting for the model rebuild.
    property bool _expanded: false

    MouseArea {
        id: rowMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (root.isGroup) {
                    root.toggleGroupRequested(root.name)
                } else {
                    root.rowClicked(root.pid)
                }
            } else if (mouse.button === Qt.RightButton) {
                contextMenuLoader.openAt(mouse.x, mouse.y)
            }
        }
    }

    Loader {
        id: contextMenuLoader
        source: "ProcessContextMenu.qml"

        function openAt(x, y) {
            if (!item) return
            item.targetPids = (root.childPids && root.childPids.length > 0) ? root.childPids : [root.pid]
            item.targetName = root.isGroup ? (root.name + " (" + root.groupCount + " processes)") : root.name
            item.isGroupTarget = root.isGroup
            item.x = x
            item.y = y
            item.open()
        }

        onLoaded: {
            item.endTaskConfirmed.connect(function(pids) {
                root.endTaskRequested(pids)
            })
        }
    }
}
