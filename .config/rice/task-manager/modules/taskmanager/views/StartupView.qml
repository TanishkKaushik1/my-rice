import QtQuick
import QtQuick.Layouts
import "root:/styles" as Styles
import "root:/services" as Services

// StartupView.qml
// The "Startup" tab -- lists real XDG autostart entries via StartupService,
// with a click-to-toggle Enabled/Disabled status column (mirrors Win11's
// Startup Apps tab, minus the "impact" measurement which isn't something
// we can cheaply compute on Linux without historical boot-time profiling).

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Styles.Metrics.spacingMd
        spacing: Styles.Metrics.spacingSm

        // ---- Column headers ----
        RowLayout {
            Layout.fillWidth: true
            height: Styles.Metrics.columnHeaderHeight

            Text {
                text: "Name"
                color: Styles.Theme.textSecondary
                font.pixelSize: Styles.Metrics.fontSizeXs
                font.family: Styles.Metrics.fontFamily
                Layout.fillWidth: true
            }
            Text {
                text: "Source"
                color: Styles.Theme.textSecondary
                font.pixelSize: Styles.Metrics.fontSizeXs
                font.family: Styles.Metrics.fontFamily
                Layout.preferredWidth: 100
            }
            Text {
                text: "Status"
                color: Styles.Theme.textSecondary
                font.pixelSize: Styles.Metrics.fontSizeXs
                font.family: Styles.Metrics.fontFamily
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 100
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Styles.Theme.divider }

        // ---- List ----
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: Services.StartupService.apps

            delegate: Rectangle {
                width: ListView.view.width
                height: Styles.Metrics.processRowHeight
                color: itemArea.containsMouse ? Styles.Theme.rowHover : "transparent"
                radius: Styles.Metrics.radiusSmall

                Behavior on color { ColorAnimation { duration: Styles.Metrics.animFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Styles.Metrics.spacingSm
                    anchors.rightMargin: Styles.Metrics.spacingSm

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: modelData.name
                            color: Styles.Theme.textPrimary
                            font.pixelSize: Styles.Metrics.fontSizeMd
                            font.family: Styles.Metrics.fontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.comment && modelData.comment.length > 0
                            text: modelData.comment
                            color: Styles.Theme.textDisabled
                            font.pixelSize: Styles.Metrics.fontSizeXs
                            font.family: Styles.Metrics.fontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: modelData.source === "user" ? "User" : "System"
                        color: Styles.Theme.textSecondary
                        font.pixelSize: Styles.Metrics.fontSizeSm
                        font.family: Styles.Metrics.fontFamily
                        Layout.preferredWidth: 100
                    }

                    // ---- Click-to-toggle status pill ----
                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignRight
                        radius: Styles.Metrics.radiusSmall
                        color: modelData.enabled
                            ? Qt.rgba(Styles.Theme.cpuGraphColor.r, Styles.Theme.cpuGraphColor.g, Styles.Theme.cpuGraphColor.b, 0.15)
                            : Qt.rgba(Styles.Theme.textDisabled.r, Styles.Theme.textDisabled.g, Styles.Theme.textDisabled.b, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: modelData.enabled ? "Enabled" : "Disabled"
                            color: modelData.enabled ? Styles.Theme.cpuGraphColor : Styles.Theme.textDisabled
                            font.pixelSize: Styles.Metrics.fontSizeXs
                            font.family: Styles.Metrics.fontFamily
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.StartupService.setEnabled(modelData.id, !modelData.enabled)
                        }
                    }
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton // row itself doesn't need its own click; the pill handles toggling
                    z: -1
                }
            }

            Text {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: "No startup apps found"
                color: Styles.Theme.textDisabled
                font.pixelSize: Styles.Metrics.fontSizeSm
                font.family: Styles.Metrics.fontFamily
            }
        }

        Text {
            text: Services.StartupService.apps.length + " startup apps  ·  click Enabled/Disabled to toggle"
            color: Styles.Theme.textDisabled
            font.pixelSize: Styles.Metrics.fontSizeXs
            font.family: Styles.Metrics.fontFamily
        }
    }
}
