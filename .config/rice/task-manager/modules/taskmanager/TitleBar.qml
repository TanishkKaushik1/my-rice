import QtQuick
import QtQuick.Layouts
import "root:/styles" as Styles

// TitleBar.qml
// Top bar mimicking Win11's window chrome: title on the left, minimize/close
// on the right. Since this runs inside QuickShell (not a real OS window),
// "minimize" and "close" just emit signals — TaskManager.qml decides what
// that means (hide the panel, destroy it, etc.) depending on how it's invoked
// (e.g. as a niri floating window vs an overlay panel).
//
// Usage:
//   TitleBar {
//       Layout.fillWidth: true
//       onCloseRequested: taskManagerRoot.visible = false
//       onMinimizeRequested: taskManagerRoot.visible = false
//   }

Rectangle {
    id: root

    signal closeRequested()
    signal minimizeRequested()

    implicitHeight: Styles.Metrics.titleBarHeight
    color: Styles.Theme.windowBackground

    // Allows dragging the window if TaskManager.qml is placed in a floating
    // niri window rather than an anchored panel. Harmless no-op otherwise.
    property alias dragArea: dragMouseArea

    MouseArea {
        id: dragMouseArea
        anchors.fill: parent
        anchors.rightMargin: Styles.Metrics.titleBarButtonSize * 2
        // Drag-to-move logic hooked up by TaskManager.qml if it wraps this
        // in a PanelWindow with anchors that support repositioning.
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Styles.Metrics.spacingMd
        spacing: Styles.Metrics.spacingSm

        Text {
            text: "Task Manager"
            color: Styles.Theme.textPrimary
            font.pixelSize: Styles.Metrics.fontSizeMd
            font.family: Styles.Metrics.fontFamily
            font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        // ---- Minimize button ----
        Rectangle {
            Layout.preferredWidth: Styles.Metrics.titleBarButtonSize
            Layout.preferredHeight: Styles.Metrics.titleBarHeight
            color: minimizeArea.containsMouse ? Styles.Theme.rowHover : "transparent"

            Behavior on color { ColorAnimation { duration: Styles.Metrics.animFast } }

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 1
                color: Styles.Theme.textPrimary
            }

            MouseArea {
                id: minimizeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.minimizeRequested()
            }
        }

        // ---- Close button ----
        Rectangle {
            Layout.preferredWidth: Styles.Metrics.titleBarButtonSize
            Layout.preferredHeight: Styles.Metrics.titleBarHeight
            color: closeArea.containsMouse ? Styles.Theme.danger : "transparent"

            Behavior on color { ColorAnimation { duration: Styles.Metrics.animFast } }

            Text {
                anchors.centerIn: parent
                text: "\u2715" // ✕
                color: closeArea.containsMouse ? Styles.Theme.buttonPrimaryText : Styles.Theme.textPrimary
                font.pixelSize: Styles.Metrics.fontSizeSm
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.closeRequested()
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Styles.Theme.divider
    }
}
