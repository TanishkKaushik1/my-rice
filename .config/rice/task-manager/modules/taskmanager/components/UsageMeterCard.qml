import QtQuick
import QtQuick.Layouts
import "root:/styles" as Styles

// UsageMeterCard.qml
// A single Performance-tab card: title, big numeric readout, and a UsageGraph
// underneath. Mirrors the Win11 Task Manager Performance tab tiles.
//
// Usage:
//   UsageMeterCard {
//       title: "Memory"
//       valueText: Services.SystemMonitor.ramUsedMb + " / " + Services.SystemMonitor.ramTotalMb + " MB"
//       percent: Services.SystemMonitor.ramPercent
//       history: Services.SystemMonitor.ramHistory
//       accentColor: Styles.Theme.ramGraphColor
//       accentFill: Styles.Theme.ramGraphFill
//   }

Rectangle {
    id: root

    property string title: "Metric"
    property string valueText: "0%"
    property real percent: 0
    property var history: []
    property color accentColor: Styles.Theme.cpuGraphColor
    property color accentFill: Styles.Theme.cpuGraphFill

    signal clicked()

    implicitWidth: Styles.Metrics.usageCardWidth
    implicitHeight: Styles.Metrics.usageCardHeight
    radius: Styles.Metrics.radiusMedium
    color: Styles.Theme.cardBackground
    border.color: Styles.Theme.divider
    border.width: 1

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        onEntered: root.color = Qt.lighter(Styles.Theme.cardBackground, 1.08)
        onExited: root.color = Styles.Theme.cardBackground
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Styles.Metrics.spacingMd
        spacing: Styles.Metrics.spacingXs

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.title
                color: Styles.Theme.textSecondary
                font.pixelSize: Styles.Metrics.fontSizeSm
                font.family: Styles.Metrics.fontFamily
                Layout.fillWidth: true
            }

            // Small colored dot indicating this metric's graph color,
            // useful once multiple graphs share a combined view
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: root.accentColor
            }
        }

        Text {
            text: root.valueText
            color: Styles.Theme.textPrimary
            font.pixelSize: Styles.Metrics.fontSizeXl
            font.family: Styles.Metrics.fontFamily
            font.weight: Font.DemiBold
        }

        Item { Layout.fillHeight: true; Layout.minimumHeight: Styles.Metrics.spacingXs }

        UsageGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: Styles.Metrics.usageGraphHeight * 0.6
            history: root.history
            lineColor: root.accentColor
            fillColor: root.accentFill
        }
    }
}
