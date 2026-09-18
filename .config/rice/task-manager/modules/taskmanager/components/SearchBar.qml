import QtQuick
import QtQuick.Controls
import "root:/styles" as Styles
import "root:/services" as Services

// SearchBar.qml
// Filter input at the top of the Processes tab. Binds directly to
// ProcessService.filterText so ProcessesView.qml's model updates live.
//
// Usage:
//   SearchBar { width: parent.width }

Rectangle {
    id: root

    implicitHeight: 32
    radius: Styles.Metrics.radiusMedium
    color: Styles.Theme.cardBackground
    border.color: input.activeFocus ? Styles.Theme.primaryAccentBorder : Styles.Theme.divider
    border.width: 1

    // Fallback in case Theme doesn't define a focus border color yet
    readonly property color primaryAccentBorderFallback: Styles.Theme.tabActiveIndicator

    Behavior on border.color { ColorAnimation { duration: Styles.Metrics.animFast } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Styles.Metrics.spacingSm
        anchors.rightMargin: Styles.Metrics.spacingSm
        spacing: Styles.Metrics.spacingXs

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uD83D\uDD0D" // 🔍 fallback glyph; swap for assets/icons/ui/search.svg later
            color: Styles.Theme.textSecondary
            font.pixelSize: Styles.Metrics.fontSizeSm
        }

        TextInput {
            id: input
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            color: Styles.Theme.textPrimary
            font.pixelSize: Styles.Metrics.fontSizeSm
            font.family: Styles.Metrics.fontFamily
            clip: true
            selectByMouse: true
            activeFocusOnTab: true

            MouseArea {
                anchors.fill: parent
                onClicked: input.forceActiveFocus()
            }

            onTextChanged: debounceTimer.restart()

            Timer {
                id: debounceTimer
                interval: 150
                onTriggered: Services.ProcessService.filterText = input.text
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search processes"
                color: Styles.Theme.textDisabled
                font.pixelSize: Styles.Metrics.fontSizeSm
                font.family: Styles.Metrics.fontFamily
                visible: input.text.length === 0
            }
        }

        // Clear button, only visible when there's text
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length > 0
            text: "\u2715" // ✕
            color: Styles.Theme.textSecondary
            font.pixelSize: Styles.Metrics.fontSizeXs

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6 // bigger hit target
                onClicked: input.text = ""
            }
        }
    }
}
