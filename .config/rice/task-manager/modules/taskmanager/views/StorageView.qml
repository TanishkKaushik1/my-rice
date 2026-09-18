import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services
import "root:/styles" as Styles

// StorageView.qml
// Pie chart of disk used/free (Canvas-drawn, no extra deps) + a ranked list
// of the biggest space consumers (directories, pacman packages, steam
// games) with per-row delete + a confirm dialog before anything is removed.
//
// Usage: dropped into TaskManager.qml's view stack alongside ProcessesView,
// PerformanceView, StartupView -- same pattern.

Item {
    id: root

    function formatBytes(bytes) {
        if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + " GB"
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB"
        if (bytes >= 1024) return (bytes / 1024).toFixed(1) + " KB"
        return bytes + " B"
    }

    function typeLabel(t) {
        if (t === "pacman") return "Package"
        if (t === "steam") return "Steam game"
        return "Directory"
    }

    // Directory items store a full path as `name` (e.g. "/home/tanishk/.local/share"),
    // which ElideMiddle mangles into unreadable "/ho...are". Show the last
    // one or two path segments instead -- readable, and still specific
    // enough to tell dirs apart. Full path is still available via tooltip.
    function displayName(item) {
        if (item.type !== "dir") return item.name
        const parts = item.name.split("/").filter(p => p.length > 0)
        if (parts.length === 0) return item.name
        if (parts.length === 1) return "/" + parts[parts.length - 1]
        return parts[parts.length - 2] + "/" + parts[parts.length - 1]
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Styles.Metrics.spacingXl
        spacing: Styles.Metrics.spacingXl

        // ---------------- Left: pie chart + legend ----------------
        ColumnLayout {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            spacing: Styles.Metrics.spacingLg

            Text {
                text: "Storage"
                font.pixelSize: Styles.Metrics.fontSizeLg
                font.family: Styles.Metrics.fontFamily
                color: Styles.Theme.textPrimary
                font.bold: true
            }

            Item {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 220
                Layout.alignment: Qt.AlignHCenter

                Canvas {
                    id: pieCanvas
                    anchors.fill: parent

                    property real usedFraction: {
                        const d = Services.StorageService.disk
                        return d.total > 0 ? d.used / d.total : 0
                    }

                    onUsedFractionChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const cx = width / 2
                        const cy = height / 2
                        const r = Math.min(width, height) / 2 - 10
                        const startAngle = -Math.PI / 2
                        const usedAngle = startAngle + usedFraction * Math.PI * 2

                        // Free slice (background ring)
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.arc(cx, cy, r, usedAngle, startAngle + Math.PI * 2)
                        ctx.closePath()
                        ctx.fillStyle = Styles.Theme.cardBackground
                        ctx.fill()

                        // Used slice
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.arc(cx, cy, r, startAngle, usedAngle)
                        ctx.closePath()
                        ctx.fillStyle = Styles.Theme.diskGraphColor
                        ctx.fill()

                        // Inner cutout (donut style, matches Win11's ring look)
                        ctx.beginPath()
                        ctx.arc(cx, cy, r * 0.6, 0, Math.PI * 2)
                        ctx.fillStyle = Styles.Theme.windowBackground
                        ctx.fill()
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            const d = Services.StorageService.disk
                            return d.total > 0 ? Math.round((d.used / d.total) * 100) + "%" : "--"
                        }
                        font.pixelSize: Styles.Metrics.fontSizeXl
                        font.bold: true
                        font.family: Styles.Metrics.fontFamily
                        color: Styles.Theme.textPrimary
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "used"
                        font.pixelSize: Styles.Metrics.fontSizeXs
                        font.family: Styles.Metrics.fontFamily
                        color: Styles.Theme.textSecondary
                    }
                }
            }

            // ---- Legend ----
            ColumnLayout {
                spacing: Styles.Metrics.spacingSm
                Layout.topMargin: Styles.Metrics.spacingMd

                RowLayout {
                    spacing: Styles.Metrics.spacingSm
                    Rectangle { width: 10; height: 10; radius: 2; color: Styles.Theme.diskGraphColor }
                    Text {
                        text: "Used: " + root.formatBytes(Services.StorageService.disk.used)
                        font.pixelSize: Styles.Metrics.fontSizeSm
                        font.family: Styles.Metrics.fontFamily
                        color: Styles.Theme.textSecondary
                    }
                }
                RowLayout {
                    spacing: Styles.Metrics.spacingSm
                    Rectangle { width: 10; height: 10; radius: 2; color: Styles.Theme.cardBackground; border.color: Styles.Theme.divider; border.width: 1 }
                    Text {
                        text: "Free: " + root.formatBytes(Services.StorageService.disk.free)
                        font.pixelSize: Styles.Metrics.fontSizeSm
                        font.family: Styles.Metrics.fontFamily
                        color: Styles.Theme.textSecondary
                    }
                }
                Text {
                    text: "Total: " + root.formatBytes(Services.StorageService.disk.total)
                    font.pixelSize: Styles.Metrics.fontSizeSm
                    font.family: Styles.Metrics.fontFamily
                    color: Styles.Theme.textDisabled
                    Layout.topMargin: Styles.Metrics.spacingXs
                }
            }

            Item { Layout.fillHeight: true }

            Button {
                id: rescanButton
                text: root.storageLoading ? "Scanning..." : "Rescan"
                enabled: !Services.StorageService.loading
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 120
                Layout.preferredHeight: 32
                onClicked: Services.StorageService.refresh()

                background: Rectangle {
                    radius: Styles.Metrics.radiusSmall
                    color: rescanButton.enabled
                           ? (rescanButton.hovered ? Styles.Theme.rowHover : Styles.Theme.cardBackground)
                           : Styles.Theme.cardBackground
                    border.color: Styles.Theme.divider
                    border.width: 1
                    opacity: rescanButton.enabled ? 1.0 : 0.5
                }

                contentItem: Text {
                    text: rescanButton.text
                    color: Styles.Theme.textPrimary
                    font.pixelSize: Styles.Metrics.fontSizeSm
                    font.family: Styles.Metrics.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            property bool storageLoading: Services.StorageService.loading
        }

        // ---------------- Right: ranked list ----------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Styles.Metrics.spacingSm

            Text {
                text: "Biggest space users"
                font.pixelSize: Styles.Metrics.fontSizeMd
                font.family: Styles.Metrics.fontFamily
                color: Styles.Theme.textPrimary
                font.bold: true
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: Services.StorageService.items
                spacing: Styles.Metrics.spacingXs

                delegate: Rectangle {
                    width: ListView.view.width
                    height: Styles.Metrics.processRowHeight + 6
                    radius: Styles.Metrics.radiusSmall
                    color: rowMouse.containsMouse ? Styles.Theme.rowHover : "transparent"

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Styles.Metrics.spacingMd
                        anchors.rightMargin: Styles.Metrics.spacingMd
                        spacing: Styles.Metrics.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            spacing: 0

                            Text {
                                text: root.displayName(modelData)
                                font.pixelSize: Styles.Metrics.fontSizeSm
                                font.family: Styles.Metrics.fontFamily
                                color: Styles.Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true

                                ToolTip.visible: nameHover.containsMouse
                                ToolTip.text: modelData.type === "dir" ? modelData.path : modelData.name
                                ToolTip.delay: 400

                                MouseArea {
                                    id: nameHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                            Text {
                                text: root.typeLabel(modelData.type)
                                font.pixelSize: Styles.Metrics.fontSizeXs
                                font.family: Styles.Metrics.fontFamily
                                color: Styles.Theme.textSecondary
                            }
                        }

                        Text {
                            text: root.formatBytes(modelData.size)
                            font.pixelSize: Styles.Metrics.fontSizeSm
                            font.family: Styles.Metrics.fontFamily
                            color: Styles.Theme.textSecondary
                            Layout.preferredWidth: 90
                            horizontalAlignment: Text.AlignRight
                        }

                        Button {
                            text: "Delete"
                            enabled: modelData.deletable
                            opacity: modelData.deletable ? 1.0 : 0.4
                            Layout.preferredWidth: 90
                            Layout.minimumWidth: 90
                            onClicked: {
                                confirmDialog.pendingItem = modelData
                                confirmDialog.open()
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Services.StorageService.items.length === 0 && !Services.StorageService.loading
                    text: "No data yet"
                    color: Styles.Theme.textSecondary
                    font.family: Styles.Metrics.fontFamily
                }
            }
        }
    }

    // ---------------- Delete confirmation ----------------
    Dialog {
        id: confirmDialog
        property var pendingItem: null

        anchors.centerIn: parent
        modal: true
        title: "Delete " + (pendingItem ? pendingItem.name : "")
        standardButtons: Dialog.Yes | Dialog.No

        contentItem: ColumnLayout {
            spacing: Styles.Metrics.spacingSm
            Text {
                text: confirmDialog.pendingItem
                      ? "This will permanently delete \"" + confirmDialog.pendingItem.name
                        + "\" (" + root.formatBytes(confirmDialog.pendingItem.size) + ").\n"
                        + (confirmDialog.pendingItem.type === "pacman"
                           ? "This will uninstall the package via pacman."
                           : confirmDialog.pendingItem.type === "steam"
                             ? "This only deletes the game folder -- verify/remove it in Steam afterward."
                             : "This cannot be undone.")
                      : ""
                wrapMode: Text.WordWrap
                color: Styles.Theme.textPrimary
                font.family: Styles.Metrics.fontFamily
            }
        }

        onAccepted: {
            if (pendingItem) {
                Services.StorageService.deleteItem(pendingItem, function(success, error) {
                    if (!success) {
                        console.warn("StorageView: delete failed:", error)
                        // Could surface a toast here if the shell has one
                    }
                })
            }
            pendingItem = null
        }
        onRejected: pendingItem = null
    }
}
