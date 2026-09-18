import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "services"
import "modules"
import "components"

FloatingWindow {
    id: root

    width: 1180
    height: 740
    visible: true
    title: "Wallpaper Switcher" 
    
    color: "transparent" 

    WallpaperService {
        id: wallpaperService
    }

    property int activeTab: 0
    property bool safeMode: true
    
    // Automatically refresh the workshop search if safe mode is toggled
    onSafeModeChanged: {
        if (workshopBrowser && (workshopBrowser.lastQuery !== "" || workshopBrowser.results.length > 0)) {
            workshopBrowser.doSearch(workshopBrowser.lastQuery, 1)
        }
    }

    // Main window container: Deep Gunmetal Base
    Rectangle {
        id: mainCard
        anchors.fill: parent
        anchors.margins: 1
        radius: 12
        color: "#121215" 
        border.color: "#2a2a30" // Subtle metallic edge
        border.width: 1
        antialiasing: true
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Top Row: Tabs ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 54
                color: "transparent"

                // Separator line
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: "#1e1e24" 
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 16

                    Row {
                        spacing: 12
                        Layout.alignment: Qt.AlignVCenter

                        // Library Tab
                        Rectangle {
                            property bool isActive: root.activeTab === 0
                            width: 110; height: 32; radius: 6
                            color: isActive ? "#35353c" : (libHover.containsMouse ? "#1e1e22" : "transparent")
                            border.color: isActive ? "#4a4a52" : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "LIBRARY"
                                color: parent.isActive ? "#e0e0e4" : "#7a7a80"
                                font.pixelSize: 11; font.family: "monospace"; font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                            HoverHandler { id: libHover }
                            TapHandler { onTapped: root.activeTab = 0 }
                        }

                        // Workshop Tab
                        Rectangle {
                            property bool isActive: root.activeTab === 1
                            width: 110; height: 32; radius: 6
                            color: isActive ? "#35353c" : (wsHover.containsMouse ? "#1e1e22" : "transparent")
                            border.color: isActive ? "#4a4a52" : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "WORKSHOP"
                                color: parent.isActive ? "#e0e0e4" : "#7a7a80"
                                font.pixelSize: 11; font.family: "monospace"; font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                            HoverHandler { id: wsHover }
                            TapHandler { onTapped: root.activeTab = 1 }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Status Indicator
                    Row {
                        spacing: 8
                        visible: wallpaperService.statusMessage !== ""
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: wallpaperService.isApplying ? "#d4af37" : "#a0a0a5"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: wallpaperService.statusMessage
                            color: "#a0a0a5"
                            font.pixelSize: 11; font.family: "monospace"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 32; height: 32; radius: 6
                        color: closeHover.containsMouse ? "#d32f2f" : "transparent"
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeHover.containsMouse ? "#ffffff" : "#7a7a80"
                            font.pixelSize: 12
                        }
                        HoverHandler { id: closeHover }
                        TapHandler { onTapped: Qt.quit() }
                    }
                }
            }

            // ── Toolbar Row: Search, Refresh, Safe Mode ─────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 56
                color: "transparent"

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: "#1e1e24"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 16

                    SearchBar {
                        id: searchBar
                        Layout.fillWidth: true
                        Layout.maximumWidth: 360
                        visible: root.activeTab === 0
                        onTextChanged: wallpaperGrid.filterText = text
                    }

                    Text {
                        visible: root.activeTab === 1
                        Layout.fillWidth: true
                        text: "Browse, search and download wallpapers from the Steam Workshop"
                        color: "#7a7a80"
                        font.pixelSize: 11
                        font.family: "monospace"
                    }

                    Item { Layout.fillWidth: true; visible: root.activeTab === 0 }

                    // Refresh Button (Library Only)
                    Rectangle {
                        visible: root.activeTab === 0
                        width: 110; height: 34; radius: 6
                        color: refreshHover.containsMouse ? "#222228" : "transparent"
                        border.color: refreshHover.containsMouse ? "#3a3a42" : "#2a2a30"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Text {
                                text: "⟳"; color: "#a0a0a5"; font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                                RotationAnimation on rotation {
                                    id: spinAnim; running: false; from: 0; to: 360; duration: 500; loops: 1
                                }
                            }
                            Text {
                                text: "REFRESH"; color: "#a0a0a5"; font.pixelSize: 10; font.family: "monospace"; font.weight: Font.Bold; font.letterSpacing: 1.2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        HoverHandler { id: refreshHover }
                        TapHandler { onTapped: { spinAnim.restart(); wallpaperService.scanWallpapers() } }
                    }

                    // Safe Mode Toggle (Always Visible)
                    Rectangle {
                        width: 120; height: 34; radius: 6
                        color: "transparent"
                        border.color: "#2a2a30"
                        border.width: 1

                        Row {
                            anchors.centerIn: parent; spacing: 10
                            Text {
                                text: "SAFE MODE"; color: "#a0a0a5"; font.pixelSize: 10; font.family: "monospace"; font.weight: Font.Bold; font.letterSpacing: 1.2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: 36; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.safeMode ? "#4a4a52" : "#1a1a1e"
                                border.color: root.safeMode ? "#6a6a72" : "#111113"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    width: 14; height: 14; radius: 7
                                    color: root.safeMode ? "#e0e0e4" : "#5a5a60"
                                    y: 1 
                                    x: root.safeMode ? parent.width - width - 2 : 1
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                TapHandler { 
                                    onTapped: {
                                        pwdDialog.targetSafeMode = !root.safeMode
                                        pwdDialog.open()
                                    } 
                                }
                            }
                        }
                    }
                }
            }

            // ── Main Content Area ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    WallpaperGrid {
                        id: wallpaperGrid
                        anchors.fill: parent
                        visible: root.activeTab === 0
                        model: wallpaperService.wallpapers
                        safeMode: root.safeMode

                        onApplyRequested: function(workshopId, wallpaperPath, previewPath) {
                            wallpaperService.applyWallpaper(workshopId, wallpaperPath, previewPath)
                        }

                        onSettingsRequested: function(workshopId, folderPath, previewPath) {
                            settingsPanel.targetWallpaperId      = workshopId
                            settingsPanel.targetWallpaperPath    = folderPath
                            settingsPanel.targetWallpaperPreview = previewPath
                        }
                    }

                    WorkshopBrowser {
                        id: workshopBrowser
                        anchors.fill: parent
                        visible: root.activeTab === 1
                        workshopRoot: wallpaperService.workshopRoot
                        allowNsfw: !root.safeMode  // Bound directly to the universal toggle
                    }
                }

                // Solid divider line
                Rectangle {
                    Layout.fillHeight: true
                    width: 1
                    color: "#1e1e24"
                }

                SettingsPanel {
                    id: settingsPanel
                    Layout.fillHeight: true
                    Layout.preferredWidth: 320 
                    
                    onApplyRequested: function(id, path, previewPath) {
                        wallpaperService.applyWallpaper(id, path, previewPath)
                    }
                }
            }
        }
    }

    // ── Password Dialog ─────────────────────────────────────────────────────
    Dialog {
        id: pwdDialog
        anchors.centerIn: parent; width: 320; modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property bool targetSafeMode: true
        property bool isError: false

        onOpened: { pwdInput.text = ""; isError = false; pwdInput.forceActiveFocus() }

        background: Rectangle {
            color: "#121215"
            radius: 12
            border.color: pwdDialog.isError ? "#ef4444" : "#2a2a30"
            border.width: 1
        }

        Column {
            width: parent.width; spacing: 16; padding: 16

            Text {
                text: "Security Check"
                color: "#ffffff"
                font.pixelSize: 14; font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: pwdDialog.targetSafeMode ? "Enter password to enable Safe Mode" : "Enter password to view NSFW content"
                color: "#a0a0a5"
                font.pixelSize: 11; font.family: "monospace"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: parent.width - 32; height: 38; radius: 6
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#1a1a1e"
                border.color: pwdDialog.isError ? "#ef4444" : (pwdInput.activeFocus ? "#e0e0e4" : "#3a3a40")
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextInput {
                    id: pwdInput
                    anchors.fill: parent
                    anchors.margins: 10
                    verticalAlignment: Text.AlignVCenter
                    color: "#e0e0e4"
                    font.pixelSize: 14; font.family: "monospace"
                    echoMode: TextInput.Password
                    selectionColor: "#4a4a52"
                    onAccepted: pwdConfirmBtn.trigger()
                    onTextChanged: pwdDialog.isError = false
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 12

                Rectangle {
                    width: 100; height: 34; radius: 6
                    color: pwdCancelHov.containsMouse ? "#1a1a1a" : "transparent"
                    border.color: "#444444"; border.width: 1
                    Text { anchors.centerIn: parent; text: "CANCEL"; color: "#ffffff"; font.pixelSize: 10; font.family: "monospace"; font.weight: Font.Bold }
                    HoverHandler { id: pwdCancelHov }
                    TapHandler { onTapped: pwdDialog.close() }
                }

                Rectangle {
                    id: pwdConfirmBtn
                    width: 100; height: 34; radius: 6
                    color: pwdConfirmHov.containsMouse ? "#4a4a52" : "#35353c"
                    border.color: "#4a4a52"; border.width: 1
                    Text { anchors.centerIn: parent; text: "UNLOCK"; color: "#ffffff"; font.pixelSize: 10; font.family: "monospace"; font.weight: Font.Bold }
                    HoverHandler { id: pwdConfirmHov }
                    function trigger() {
                        if (pwdInput.text === "123") {
                            root.safeMode = pwdDialog.targetSafeMode
                            pwdDialog.close()
                        } else {
                            pwdDialog.isError = true
                        }
                    }
                    TapHandler { onTapped: pwdConfirmBtn.trigger() }
                }
            }
        }
    }

    Component.onCompleted: {
        wallpaperService.scanWallpapers()
        LweSettingsService.load()
    }
}