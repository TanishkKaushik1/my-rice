import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import Quickshell.Wayland

// ── Recording settings popup ────────────────────────────────────────────
// Floating card anchored top-right, driven by `recordingMenuOpen`.
// Settings are persisted to ~/.config/rice/recording-settings.conf.

QtObject {
    id: root

    property bool   recordingMenuOpen: false
    property color  accentColor: "#e35b4f"   // red-ish, matches Recording status color
    property color  fgColor:     "#e0e4db"
    property color  errorColor:  "#ffb4ab"
    property string activeFont:  "Inter Nerd Font"
    property int    rightOffset: 357
    property int    topOffset:   56

    signal requestClose()
    signal settingsApplied()

    // ── Recording options (defaults) ────────────────────────────────────
    property string captureMode: "screen"      // screen | region | window
    property string audioSource: "both"        // none | mic | system | both
    property bool   includeCursor: true
    property string videoFormat: "mp4"         // mp4 | mkv | webm
    property int    framerate: 60              // 24 | 30 | 60 | 120
    property string quality: "high"            // low | medium | high | lossless
    property string outputDir: "~/Videos/Recordings"

    property var configPath: "/home/tanishk/.config/rice/recording-settings.conf"

    // ── Per-screen full-screen overlay ──────────────────────────────────
    property var _variants: Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            visible: root.recordingMenuOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-recording-settings"
            WlrLayershell.keyboardFocus: root.recordingMenuOpen
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            // Click outside the card to dismiss
            MouseArea {
                anchors.fill: parent
                onClicked: root.requestClose()
            }

            Rectangle {
                id: card
                width: 300
                implicitHeight: layout.implicitHeight + 28
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: root.topOffset; anchors.rightMargin: root.rightOffset
                radius: 16
                color: "#1c1e1a"
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                // Swallow clicks inside the card
                MouseArea { anchors.fill: parent; onClicked: {} }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 0.6
                    shadowVerticalOffset: 6
                }

                ColumnLayout {
                    id: layout
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // ── Header ───────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰻃"
                            color: root.accentColor
                            font.family: root.activeFont; font.pixelSize: 16
                        }
                        Text {
                            text: "Recording Settings"
                            color: root.fgColor
                            font.family: root.activeFont; font.pixelSize: 14; font.weight: Font.DemiBold
                            leftPadding: 6
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "󰅖"
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.family: root.activeFont; font.pixelSize: 14
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.requestClose() }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    // ── Capture mode ─────────────────────────────────────
                    Text { text: "Capture"; color: Qt.rgba(1, 1, 1, 0.5); font.family: root.activeFont; font.pixelSize: 10 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [
                                { key: "screen", icon: "󰍹", label: "Screen" },
                                { key: "region", icon: "󰇄", label: "Region" },
                                { key: "window", icon: "󰖯", label: "Window" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; height: 40; radius: 9
                                color: root.captureMode === modelData.key ? root.accentColor : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        color: root.captureMode === modelData.key ? "#1a1a1a" : root.fgColor
                                        font.family: root.activeFont; font.pixelSize: 13
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: root.captureMode === modelData.key ? "#1a1a1a" : Qt.rgba(1, 1, 1, 0.5)
                                        font.family: root.activeFont; font.pixelSize: 8
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.captureMode = modelData.key
                                }
                            }
                        }
                    }

                    // ── Audio source ────────────────────────────────────
                    Text { text: "Audio"; color: Qt.rgba(1, 1, 1, 0.5); font.family: root.activeFont; font.pixelSize: 10; Layout.topMargin: 4 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [
                                { key: "none",   icon: "󰝟", label: "None" },
                                { key: "mic",    icon: "󰍬", label: "Mic" },
                                { key: "system", icon: "󰕾", label: "System" },
                                { key: "both",   icon: "󰗼", label: "Both" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; height: 40; radius: 9
                                color: root.audioSource === modelData.key ? root.accentColor : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        color: root.audioSource === modelData.key ? "#1a1a1a" : root.fgColor
                                        font.family: root.activeFont; font.pixelSize: 12
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: root.audioSource === modelData.key ? "#1a1a1a" : Qt.rgba(1, 1, 1, 0.5)
                                        font.family: root.activeFont; font.pixelSize: 8
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.audioSource = modelData.key
                                }
                            }
                        }
                    }

                    // ── Include cursor toggle ───────────────────────────
                    RowLayout {
                        Layout.fillWidth: true; Layout.topMargin: 4
                        Text {
                            text: "Show Cursor"
                            color: root.fgColor
                            font.family: root.activeFont; font.pixelSize: 12
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            width: 40; height: 22; radius: 11
                            color: root.includeCursor ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: "#1a1a1a"
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.includeCursor ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.includeCursor = !root.includeCursor
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    // ── Format ───────────────────────────────────────────
                    Text { text: "Format"; color: Qt.rgba(1, 1, 1, 0.5); font.family: root.activeFont; font.pixelSize: 10 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: ["mp4", "mkv", "webm"]
                            delegate: Rectangle {
                                required property string modelData
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: root.videoFormat === modelData ? root.accentColor : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.videoFormat === modelData ? "#1a1a1a" : Qt.rgba(1, 1, 1, 0.6)
                                    font.family: root.activeFont; font.pixelSize: 10
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.videoFormat = modelData
                                }
                            }
                        }
                    }

                    // ── Framerate ────────────────────────────────────────
                    Text { text: "Framerate"; color: Qt.rgba(1, 1, 1, 0.5); font.family: root.activeFont; font.pixelSize: 10; Layout.topMargin: 4 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [24, 30, 60, 120]
                            delegate: Rectangle {
                                required property int modelData
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: root.framerate === modelData ? root.accentColor : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "fps"
                                    color: root.framerate === modelData ? "#1a1a1a" : Qt.rgba(1, 1, 1, 0.6)
                                    font.family: root.activeFont; font.pixelSize: 10
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.framerate = modelData
                                }
                            }
                        }
                    }

                    // ── Quality ──────────────────────────────────────────
                    Text { text: "Quality"; color: Qt.rgba(1, 1, 1, 0.5); font.family: root.activeFont; font.pixelSize: 10; Layout.topMargin: 4 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: ["low", "medium", "high", "lossless"]
                            delegate: Rectangle {
                                required property string modelData
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: root.quality === modelData ? root.accentColor : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                    color: root.quality === modelData ? "#1a1a1a" : Qt.rgba(1, 1, 1, 0.6)
                                    font.family: root.activeFont; font.pixelSize: 9
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.quality = modelData
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    // ── Output directory ────────────────────────────────
                    Text { text: "Save To"; color: Qt.rgba(1, 1, 1, 0.5); font.family: root.activeFont; font.pixelSize: 10 }
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)
                        TextInput {
                            id: dirInput
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: root.fgColor
                            font.family: root.activeFont; font.pixelSize: 11
                            text: root.outputDir
                            selectByMouse: true
                            onEditingFinished: root.outputDir = text
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08); Layout.topMargin: 2 }

                    // ── Apply / Open folder ─────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; height: 40; radius: 10
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: "Open Folder"
                                color: root.fgColor
                                font.family: root.activeFont; font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { _openFolder.running = false; _openFolder.running = true }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 40; radius: 10
                            color: root.accentColor
                            Text {
                                anchors.centerIn: parent
                                text: "Apply"
                                color: "#1a1a1a"
                                font.family: root.activeFont; font.pixelSize: 11; font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.outputDir = dirInput.text
                                    _writeConfig.running = false; _writeConfig.running = true
                                }
                            }
                        }
                    }

                    Item { height: 2 }
                }
            }
        }
    }

    // ── Persist settings to disk ────────────────────────────────────────
    property var _writeConfig: Process {
        id: _writeConfig
        property string _content:
            "CAPTURE_MODE=" + root.captureMode + "\n" +
            "AUDIO_SOURCE=" + root.audioSource + "\n" +
            "INCLUDE_CURSOR=" + (root.includeCursor ? "1" : "0") + "\n" +
            "VIDEO_FORMAT=" + root.videoFormat + "\n" +
            "FRAMERATE=" + root.framerate + "\n" +
            "QUALITY=" + root.quality + "\n" +
            "OUTPUT_DIR=" + root.outputDir + "\n"
        command: ["sh", "-c", "mkdir -p \"$(dirname '" + root.configPath + "')\" && cat > '" + root.configPath + "' << 'EOF'\n" + _content + "EOF"]
        onExited: (c, s) => {
            running = false
            root.settingsApplied()
            _notifyApplied.running = false; _notifyApplied.running = true
        }
    }

    property var _notifyApplied: Process {
        id: _notifyApplied
        command: ["notify-send", "-a", "rice", "-i", "media-record",
                  "Recording Settings", "Settings saved"]
        onExited: (c, s) => { running = false }
    }

    property var _openFolder: Process {
        id: _openFolder
        command: ["sh", "-c", "xdg-open \"$(eval echo " + root.outputDir + ")\""]
        onExited: (c, s) => { running = false }
    }

    // Load persisted settings on startup
    property var _readConfig: Process {
        id: _readConfig
        running: true
        command: ["sh", "-c", "cat '" + root.configPath + "' 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "") return
                var idx = line.indexOf("=")
                if (idx === -1) return
                var key = line.substring(0, idx)
                var val = line.substring(idx + 1)
                switch (key) {
                    case "CAPTURE_MODE":   root.captureMode = val; break
                    case "AUDIO_SOURCE":   root.audioSource = val; break
                    case "INCLUDE_CURSOR": root.includeCursor = (val === "1"); break
                    case "VIDEO_FORMAT":   root.videoFormat = val; break
                    case "FRAMERATE":      root.framerate = parseInt(val) || 60; break
                    case "QUALITY":        root.quality = val; break
                    case "OUTPUT_DIR":     root.outputDir = val; break
                }
            }
        }
        onExited: (c, s) => { running = false }
    }
}