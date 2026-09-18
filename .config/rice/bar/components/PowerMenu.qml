import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import Quickshell.Wayland
import "." // WifiMenu.qml / RecordingSettings.qml live alongside this file

QtObject {
    id: root

    property bool   powerMenuOpen: false
    property color  accentColor:   "#9fd49b"
    property color  fgColor:       "#e0e4db"
    property color  errorColor:    "#ffb4ab"
    property color  gamingColor:   "#cba6f7"   // purple accent for gaming mode
    property string activeFont:    "Inter Nerd Font"
    property string userName:      "User"

    // Dynamic Username fetcher
    property var _getUser: Process {
        id: _getUser
        command: ["whoami"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var u = data.trim()
                if (u.length > 0) {
                    root.userName = u.charAt(0).toUpperCase() + u.slice(1)
                }
            }
        }
    }

    // ── Network state (fed from shell.qml) ───────────────────────────────────
    property string wifiVal:    ""
    property string ethVal:     ""
    property string btVal:      ""
    property color  btColor:    "#a1ced5"
    property bool   hotspotOn:  false
    property bool   nightLightOn: false
    
    signal requestClose()

    // ── Wifi popup (separate component, positioned to the left of this card) ──
    property var wifiMenu: WifiMenu {
        accentColor: root.accentColor
        fgColor:     root.fgColor
        errorColor:  root.errorColor
        activeFont:  root.activeFont
        rightOffset: 357   // 5 (this card's rightMargin) + 340 (this card's width) + 12 (gap)
        topOffset:   56
        onRequestClose: wifiMenuOpen = false
        onWifiMenuOpenChanged: {
            // Only one network popup at a time — opening Wi-Fi closes Bluetooth.
            if (wifiMenuOpen) {
                root.bluetoothMenu.bluetoothMenuOpen = false
                root.appMixerMenu.appMixerMenuOpen = false
                root.recordingMenuOpen = false
            }
        }
    }

    // ── Bluetooth popup (same slot as WifiMenu; only one shows at a time) ────
    property var bluetoothMenu: BluetoothMenu {
        accentColor: root.btColor
        fgColor:     root.fgColor
        errorColor:  root.errorColor
        activeFont:  root.activeFont
        rightOffset: 357
        topOffset:   56
        onRequestClose: bluetoothMenuOpen = false
        onBluetoothMenuOpenChanged: {
            // Only one network popup at a time — opening Bluetooth closes Wi-Fi.
            if (bluetoothMenuOpen) {
                root.wifiMenu.wifiMenuOpen = false
                root.appMixerMenu.appMixerMenuOpen = false
                root.recordingMenuOpen = false
            }
        }
    }

    // ── App-wise volume mixer popup (same left-hand slot as Wifi/Bluetooth) ──
    property var appMixerMenu: AppMixerMenu {
        accentColor: root.accentColor
        fgColor:     root.fgColor
        errorColor:  root.errorColor
        activeFont:  root.activeFont
        rightOffset: 357
        topOffset:   56
        onRequestClose: appMixerMenuOpen = false
        onAppMixerMenuOpenChanged: {
            // Only one popup at a time in this slot.
            if (appMixerMenuOpen) {
                root.wifiMenu.wifiMenuOpen = false
                root.bluetoothMenu.bluetoothMenuOpen = false
                root.recordingMenuOpen = false
            }
        }
    }

    // ── Recording settings popup (same left-hand slot as Wifi/Bluetooth/Mixer) ──
    property bool recordingMenuOpen: false
    property var recordingSettings: RecordingSettings {
        accentColor: root.errorColor
        fgColor:     root.fgColor
        errorColor:  root.errorColor
        activeFont:  root.activeFont
        rightOffset: 357
        topOffset:   56
        recordingMenuOpen: root.recordingMenuOpen
        onRequestClose: root.recordingMenuOpen = false
        onRecordingMenuOpenChanged: {
            // Only one popup at a time in this slot.
            if (recordingMenuOpen) {
                root.wifiMenu.wifiMenuOpen = false
                root.bluetoothMenu.bluetoothMenuOpen = false
                root.appMixerMenu.appMixerMenuOpen = false
            }
        }
    }

    // ── Status helpers ─────────────────────────────────────────────────────
    function wifiStatusText() {
        if (!root.wifiMenu.wifiPowered) return "Off"
        if (root.wifiVal !== "") return root.wifiVal
        return "Disconnected"
    }

    function btStatusText() {
        if (!root.bluetoothMenu.btPowered) return "Off"
        if (root.btVal !== "") return root.btVal
        return "Disconnected"
    }

    // ── Recording state ───────────────────────────────────────────────────────
    property bool isRecording: false
    property int  recSeconds:  0

    function recTimeStr() {
        var s = recSeconds
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        if (h > 0)
            return h + ":" + String(m).padStart(2,"0") + ":" + String(sec).padStart(2,"0")
        return String(m).padStart(2,"0") + ":" + String(sec).padStart(2,"0")
    }

    property var _recTimer: Timer {
        interval: 1000; repeat: true
        running: root.isRecording
        onTriggered: root.recSeconds += 1
    }

    property var _pollTimer: Timer {
        interval: 2000; repeat: true
        running: root.isRecording
        onTriggered: { _checkRec.running = false; _checkRec.running = true }
    }

    property var _checkRec: Process {
        id: _checkRec
        command: ["sh", "-c", "[ -f /tmp/.wf-recorder-running ] && echo 1 || echo 0"]
        onExited: (c,s) => { running = false }
        stdout: SplitParser {
            onRead: data => {
                var rec = data.trim() === "1"
                if (!rec && root.isRecording) root.recSeconds = 0
                root.isRecording = rec
            }
        }
    }

    property var _startRec: Process {
        id: _startRec
        command: ["sh", "-c", "exec bash \"${XDG_CONFIG_HOME:-$HOME/.config}/rice/scripts/toggle-record.sh\" start"]
        onExited: (c,s) => {
            running = false
            _verifyTimer.restart()
            _notifyRecStart.running = false; _notifyRecStart.running = true
        }
    }

    property var _stopRec: Process {
        id: _stopRec
        command: ["sh", "-c", "exec bash \"${XDG_CONFIG_HOME:-$HOME/.config}/rice/scripts/toggle-record.sh\" stop"]
        onExited: (c,s) => {
            running = false
            _notifyRecStop.running = false; _notifyRecStop.running = true
        }
    }

    property var _verifyTimer: Timer {
        id: _verifyTimer
        interval: 600; repeat: false
        onTriggered: { _checkRec.running = false; _checkRec.running = true }
    }

    // ── Recording notifications ─────────────────────────────────────────────
    property var _notifyRecStart: Process {
        id: _notifyRecStart
        command: ["notify-send", "-a", "rice", "-i", "media-record",
                  "-u", "normal", "-t", "3000",
                  "Screen Recording", "Recording started"]
        onExited: (c,s) => { running = false }
    }

    property var _notifyRecStop: Process {
        id: _notifyRecStop
        property string durationText: "00:00"
        command: ["notify-send", "-a", "rice", "-i", "media-playback-stop",
                  "-u", "normal", "-t", "3000",
                  "Screen Recording", "Stopped after " + durationText]
        onExited: (c,s) => { running = false }
    }

    // ── Gaming mode state ─────────────────────────────────────────────────────
    property bool isGamingMode: false
    property bool gamingTogglePending: false

    property var _checkGaming: Process {
        id: _checkGaming
        command: ["sh", "-c", "[ -f /tmp/.wallpaper-gamemode ] && echo 1 || echo 0"]
        onExited: (c,s) => { running = false }
        stdout: SplitParser {
            onRead: data => {
                if (root.gamingTogglePending) return
                root.isGamingMode = data.trim() === "1"
            }
        }
    }

    property var _gamingPollTimer: Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: { _checkGaming.running = false; _checkGaming.running = true }
    }

    property var _gamingOn: Process {
        id: _gamingOn
        command: ["sh", "-c", "exec bash \"${XDG_CONFIG_HOME:-$HOME/.config}/rice/scripts/gaming-toggle.sh\" on"]
        onExited: (c,s) => {
            running = false
            _lowerQS.running = false; _lowerQS.running = true
            root.gamingTogglePending = false
            _checkGaming.running = false; _checkGaming.running = true
        }
    }

    property var _gamingOff: Process {
        id: _gamingOff
        command: ["sh", "-c", "exec bash \"${XDG_CONFIG_HOME:-$HOME/.config}/rice/scripts/gaming-toggle.sh\" off"]
        onExited: (c,s) => {
            running = false
            _restoreQS.running = false; _restoreQS.running = true
            root.gamingTogglePending = false
            _checkGaming.running = false; _checkGaming.running = true
        }
    }

    property var _lowerQS: Process {
        id: _lowerQS
        command: ["sh", "-c", "sudo -n renice +10 $(pgrep -x quickshell) 2>/dev/null; sudo -n ionice -c 3 -p $(pgrep -x quickshell) 2>/dev/null"]
        onExited: (c,s) => { running = false }
    }

    property var _restoreQS: Process {
        id: _restoreQS
        command: ["sh", "-c", "sudo -n renice 0 $(pgrep -x quickshell) 2>/dev/null; sudo -n ionice -c2 -n4 -p $(pgrep -x quickshell) 2>/dev/null"]
        onExited: (c,s) => { running = false }
    }

    onPowerMenuOpenChanged: {
        if (powerMenuOpen) {
            _checkRec.running = false; _checkRec.running = true
            _checkGaming.running = false; _checkGaming.running = true
        } else {
            wifiMenu.wifiMenuOpen = false
            bluetoothMenu.bluetoothMenuOpen = false
            appMixerMenu.appMixerMenuOpen = false
        }
    }

    // ── Per-screen windows ────────────────────────────────────────────────────
    property var _variants: Variants {
        id: powerMenuVariants
        model: Quickshell.screens

        PanelWindow {
            id: powerWin
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            visible: root.powerMenuOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.powerMenuOpen
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            property string powerMode: "balanced"
            property int    volume:    50

            Process {
                id: getPowerMode
                command: ["sh", "-c", "powerprofilesctl get"]
                running: root.powerMenuOpen
                onExited: (c,s) => { running = false }
                stdout: SplitParser { onRead: data => { powerWin.powerMode = data.trim() } }
            }

            Process {
                id: getVolume
                command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{v=$2*100; if(v>150)v=150; printf \"%d\",v}'"]
                running: root.powerMenuOpen
                onExited: (c,s) => { running = false }
                stdout: SplitParser {
                    onRead: data => {
                        var v = parseInt(data.trim())
                        if (!isNaN(v)) powerWin.volume = v
                    }
                }
            }

            Process {
                id: setVolume
                property int targetVol: 50
                command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (targetVol / 100).toFixed(2)]
                onExited: (c,s) => { running = false }
            }

            Process { id: setSaver;    command: ["powerprofilesctl", "set", "power-saver"];  onExited: (c,s) => { running = false } }
            Process { id: setBalanced; command: ["powerprofilesctl", "set", "balanced"];     onExited: (c,s) => { running = false } }
            Process { id: setPerf;     command: ["powerprofilesctl", "set", "performance"];  onExited: (c,s) => { running = false } }

            Process { id: lockCmd;     command: ["sh", "-c", "exec hyprlock --config \"${XDG_CONFIG_HOME:-$HOME/.config}/rice/hyprlock/hyprlock.conf\""] }
            Process { id: logoutCmd;   command: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\" || niri msg action quit --skip-confirmation"] }
            Process { id: rebootCmd;   command: ["systemctl", "reboot"] }
            Process { id: shutdownCmd; command: ["systemctl", "poweroff"] }

            // ── Network actions ───────────────────────────────────────────────
            Process { id: _hotspotOn;  command: ["sh", "-c", "nmcli con up Hotspot 2>/dev/null || nmcli dev wifi hotspot con-name Hotspot ssid Quickshell band a channel 36 &"]; onExited: (c,s) => { running = false } }
            Process { id: _hotspotOff; command: ["sh", "-c", "nmcli con down Hotspot 2>/dev/null &"]; onExited: (c,s) => { running = false } }
            Process { id: _nightLightProcess; command: ["wlsunset", "-t", "4000", "-T", "4001"] }

            MouseArea {
                anchors.fill: parent
                onClicked: root.requestClose()
            }

            Rectangle {
                width: 340
                height: menuCol.implicitHeight + 40
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 56; anchors.rightMargin: 5
                color: "#ee0d0d0d"
                border.color: Qt.rgba(1,1,1,0.08)
                radius: 14

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: root.isGamingMode ? Qt.rgba(0.8, 0.65, 0.97, 0.5) : "transparent"
                    border.width: root.isGamingMode ? 2 : 0
                    Behavior on border.color { ColorAnimation { duration: 300 } }
                    Behavior on border.width { NumberAnimation { duration: 300 } }
                }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: menuCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 20
                    spacing: 14

                    // 1. Profile
                    RowLayout {
                        Layout.fillWidth: true; spacing: 14
                        
                        Item {
                            width: 52; height: 52
                            
                            Rectangle {
                                id: maskRect
                                anchors.fill: parent
                                radius: 26
                                color: "black"
                                layer.enabled: true
                                visible: false
                            }

                            AnimatedImage {
                                id: avatarImg
                                anchors.fill: parent
                                source: "scuba-cat.gif"
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                playing: root.powerMenuOpen
                                layer.enabled: true
                                visible: false 
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: avatarImg
                                maskEnabled: true
                                maskSource: maskRect
                            }
                        }
                        
                        Column {
                            Layout.alignment: Qt.AlignVCenter; spacing: 2
                            Text {
                                text: root.userName
                                color: root.fgColor
                                font.family: root.activeFont
                                font.pixelSize: 17; font.weight: Font.Bold
                            }
                            Row {
                                visible: root.isGamingMode; spacing: 5
                                Text { text: "󰊗"; font.family: root.activeFont; font.pixelSize: 10; color: root.gamingColor; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: "Gaming Mode  ON"
                                    color: root.gamingColor
                                    font.family: root.activeFont; font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Row {
                                visible: root.isRecording && !root.isGamingMode; spacing: 5
                                Text { text: "🔴"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: "Recording  " + root.recTimeStr()
                                    color: root.errorColor
                                    font.family: root.activeFont; font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                    
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 2. Network / Connectivity
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 10

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: (root.wifiVal !== "" || root.wifiMenu.wifiMenuOpen) ? Qt.rgba(0.62, 0.83, 0.61, 0.18) : Qt.rgba(1,1,1,0.07)
                                RowLayout {
                                    anchors.centerIn: parent; spacing: 5
                                    Text {
                                        text: root.wifiMenu.wifiPowered ? "󰖩" : "󰖪"
                                        color: !root.wifiMenu.wifiPowered ? root.errorColor : (root.wifiVal !== "" ? root.accentColor : Qt.rgba(1,1,1,0.5))
                                        font.family: root.activeFont; font.pixelSize: 16
                                    }
                                    Column {
                                        Text {
                                            text: "Wi-Fi"
                                            color: root.fgColor
                                            font.family: root.activeFont; font.pixelSize: 11
                                        }
                                        Text {
                                            text: root.wifiStatusText()
                                            color: !root.wifiMenu.wifiPowered ? Qt.rgba(1,1,1,0.35) : (root.wifiVal !== "" ? root.accentColor : Qt.rgba(1,1,1,0.45))
                                            font.family: root.activeFont; font.pixelSize: 9
                                            elide: Text.ElideRight; maximumLineCount: 1
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.wifiMenu.wifiMenuOpen = !root.wifiMenu.wifiMenuOpen
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                visible: root.ethVal !== ""
                                color: Qt.rgba(0.62, 0.83, 0.61, 0.18)
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰈀"
                                        color: root.accentColor
                                        font.family: root.activeFont; font.pixelSize: 16
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.ethVal
                                        color: root.accentColor
                                        font.family: root.activeFont; font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: (root.btVal !== "" || root.bluetoothMenu.bluetoothMenuOpen) ? Qt.rgba(0.63, 0.81, 0.84, 0.18) : Qt.rgba(1,1,1,0.07)
                                RowLayout {
                                    anchors.centerIn: parent; spacing: 5
                                    Text {
                                        text: root.bluetoothMenu.btPowered ? "󰂯" : "󰂲"
                                        color: !root.bluetoothMenu.btPowered ? root.errorColor : (root.btVal !== "" ? root.btColor : Qt.rgba(1,1,1,0.5))
                                        font.family: root.activeFont; font.pixelSize: 16
                                    }
                                    Column {
                                        Text {
                                            text: "Bluetooth"
                                            color: root.fgColor
                                            font.family: root.activeFont; font.pixelSize: 11
                                        }
                                        Text {
                                            text: root.btStatusText()
                                            color: !root.bluetoothMenu.btPowered ? Qt.rgba(1,1,1,0.35) : (root.btVal !== "" ? root.btColor : Qt.rgba(1,1,1,0.45))
                                            font.family: root.activeFont; font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.bluetoothMenu.bluetoothMenuOpen = !root.bluetoothMenu.bluetoothMenuOpen
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: root.hotspotOn ? Qt.rgba(0.98, 0.75, 0.27, 0.2) : Qt.rgba(1,1,1,0.07)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰀃"
                                        color: root.hotspotOn ? "#f5c542" : Qt.rgba(1,1,1,0.5)
                                        font.family: root.activeFont; font.pixelSize: 16
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Hotspot"
                                        color: root.hotspotOn ? "#f5c542" : Qt.rgba(1,1,1,0.4)
                                        font.family: root.activeFont; font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.hotspotOn = !root.hotspotOn
                                        if (root.hotspotOn) { _hotspotOn.running = false; _hotspotOn.running = true }
                                        else                { _hotspotOff.running = false; _hotspotOff.running = true }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: root.nightLightOn ? Qt.rgba(0.98, 0.61, 0.24, 0.2) : Qt.rgba(1,1,1,0.07)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰖔"
                                        color: root.nightLightOn ? "#fa9c3e" : Qt.rgba(1,1,1,0.5)
                                        font.family: root.activeFont; font.pixelSize: 16
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Night Light"
                                        color: root.nightLightOn ? "#fa9c3e" : Qt.rgba(1,1,1,0.4)
                                        font.family: root.activeFont; font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.nightLightOn = !root.nightLightOn
                                        _nightLightProcess.running = root.nightLightOn
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 3. Screen Recording
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰻃"
                                color: root.isRecording ? root.errorColor : Qt.rgba(1,1,1,0.5)
                                font.family: root.activeFont; font.pixelSize: 16
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Text {
                                text: "Screen Recording"
                                color: root.fgColor
                                font.family: root.activeFont; font.pixelSize: 14
                                leftPadding: 6
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "󰒓"
                                color: root.recordingMenuOpen ? root.accentColor : Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 14
                                rightPadding: 4
                                Behavior on color { ColorAnimation { duration: 150 } }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.recordingMenuOpen = !root.recordingMenuOpen
                                }
                            }
                            Rectangle {
                                width: recRow.implicitWidth + 14
                                height: 20; radius: 10
                                color: root.isRecording ? Qt.rgba(1,0.35,0.32,0.18) : Qt.rgba(1,1,1,0.07)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Row {
                                    id: recRow
                                    anchors.centerIn: parent; spacing: 5
                                    Rectangle {
                                        visible: root.isRecording
                                        width: 6; height: 6; radius: 3
                                        color: root.errorColor
                                        anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on opacity {
                                            running: root.isRecording
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutQuad }
                                            NumberAnimation { to: 1.0;  duration: 650; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                    Text {
                                        text: root.isRecording ? root.recTimeStr() : "OFF"
                                        color: root.isRecording ? root.errorColor : Qt.rgba(1,1,1,0.35)
                                        font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: !root.isRecording ? root.accentColor : Qt.rgba(1,1,1,0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰻃"
                                        color: !root.isRecording ? "#1a1a1a" : root.fgColor
                                        font.family: root.activeFont; font.pixelSize: 15
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Start"
                                        color: !root.isRecording ? "#1a1a1a" : Qt.rgba(1,1,1,0.5)
                                        font.family: root.activeFont; font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.isRecording) {
                                            _startRec.running = false; _startRec.running = true
                                            root.isRecording = true; root.recSeconds = 0
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: root.isRecording ? root.errorColor : Qt.rgba(1,1,1,0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰓛"
                                        color: root.isRecording ? "#1a1a1a" : root.fgColor
                                        font.family: root.activeFont; font.pixelSize: 15
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Stop"
                                        color: root.isRecording ? "#1a1a1a" : Qt.rgba(1,1,1,0.5)
                                        font.family: root.activeFont; font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.isRecording) {
                                            _notifyRecStop.durationText = root.recTimeStr()
                                            _stopRec.running = false; _stopRec.running = true
                                            root.isRecording = false; root.recSeconds = 0
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.isRecording
                                ? "Capturing screen + audio · notified on stop"
                                : "Records full desktop with audio via wf-recorder"
                            color: Qt.rgba(1,1,1,0.3)
                            font.family: root.activeFont; font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 4. Volume 0-150%
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: powerWin.volume === 0 ? "󰝟" : powerWin.volume < 40 ? "󰕿" : powerWin.volume < 100 ? "󰖀" : "󰕾"
                                color: root.accentColor; font.family: root.activeFont; font.pixelSize: 16
                            }
                            Text { text: "Volume"; color: root.fgColor; font.family: root.activeFont; font.pixelSize: 14; Layout.fillWidth: true; leftPadding: 6 }
                            Text { text: powerWin.volume + "%"; color: Qt.rgba(1,1,1,0.5); font.family: root.activeFont; font.pixelSize: 12 }

                            Rectangle {
                                width: 24; height: 24; radius: 6
                                color: root.appMixerMenu.appMixerMenuOpen ? Qt.rgba(0.62, 0.83, 0.61, 0.18) : Qt.rgba(1,1,1,0.07)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅁"
                                    color: root.appMixerMenu.appMixerMenuOpen ? root.accentColor : Qt.rgba(1,1,1,0.5)
                                    font.family: root.activeFont; font.pixelSize: 12
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.appMixerMenu.appMixerMenuOpen = !root.appMixerMenu.appMixerMenuOpen
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true; height: 28
                            Rectangle {
                                id: track
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.right: parent.right
                                height: 5; radius: 3; color: Qt.rgba(1,1,1,0.12)
                                Rectangle { x: parent.width*(100/150)-1; width: 2; height: parent.height; color: Qt.rgba(1,1,1,0.3); radius: 1 }
                                Rectangle {
                                    width: parent.width*(powerWin.volume/150); height: parent.height; radius: parent.radius
                                    color: powerWin.volume > 100 ? "#f0c040" : root.accentColor
                                }
                            }
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: powerWin.volume > 100 ? "#f0c040" : root.accentColor
                                border.color: Qt.rgba(0,0,0,0.3); border.width: 1
                                anchors.verticalCenter: track.verticalCenter
                                x: (track.width-width)*(powerWin.volume/150)
                            }
                            MouseArea {
                                anchors.fill: parent; preventStealing: true; cursorShape: Qt.PointingHandCursor
                                function updateVol(mx) {
                                    var vol = Math.round(Math.max(0,Math.min(1,mx/width))*150)
                                    powerWin.volume = vol
                                    setVolume.targetVol = vol
                                    setVolume.running = false; setVolume.running = true
                                }
                                onClicked: (m) => updateVol(m.x)
                                onPositionChanged: (m) => { if(pressed) updateVol(m.x) }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 5. Power Mode
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "Power Mode"; color: root.fgColor; font.family: root.activeFont; font.pixelSize: 14 }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: [
                                    { label: "Saver",   mode: "power-saver",  icon: "󰌪" },
                                    { label: "Balance", mode: "balanced",      icon: "󰾆" },
                                    { label: "Perf",    mode: "performance",   icon: "󰓅" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true; height: 44; radius: 10
                                    color: powerWin.powerMode === modelData.mode ? root.accentColor : Qt.rgba(1,1,1,0.08)
                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: powerWin.powerMode === modelData.mode ? "#1a1a1a" : root.fgColor; font.family: root.activeFont; font.pixelSize: 15 }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: powerWin.powerMode === modelData.mode ? "#1a1a1a" : Qt.rgba(1,1,1,0.5); font.family: root.activeFont; font.pixelSize: 9 }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            powerWin.powerMode = modelData.mode
                                            var p = modelData.mode === "power-saver" ? setSaver : modelData.mode === "balanced" ? setBalanced : setPerf
                                            p.running = false; p.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 6. GAMING MODE
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰊗"
                                color: root.isGamingMode ? root.gamingColor : Qt.rgba(1,1,1,0.5)
                                font.family: root.activeFont; font.pixelSize: 16
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Text {
                                text: "Gaming Mode"
                                color: root.fgColor
                                font.family: root.activeFont; font.pixelSize: 14
                                leftPadding: 6
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                width: statusLabel.implicitWidth + 14
                                height: 20; radius: 10
                                color: root.isGamingMode ? Qt.rgba(0.8,0.65,0.97,0.2) : Qt.rgba(1,1,1,0.07)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Text {
                                    id: statusLabel
                                    anchors.centerIn: parent
                                    text: root.isGamingMode ? "ON" : "OFF"
                                    color: root.isGamingMode ? root.gamingColor : Qt.rgba(1,1,1,0.35)
                                    font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: !root.isGamingMode ? root.accentColor : Qt.rgba(1,1,1,0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰌾"
                                        color: !root.isGamingMode ? "#1a1a1a" : root.fgColor
                                        font.family: root.activeFont; font.pixelSize: 15
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Normal"
                                        color: !root.isGamingMode ? "#1a1a1a" : Qt.rgba(1,1,1,0.5)
                                        font.family: root.activeFont; font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.isGamingMode) {
                                            root.gamingTogglePending = true
                                            _gamingOff.running = false; _gamingOff.running = true
                                            root.isGamingMode = false
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: root.isGamingMode ? root.gamingColor : Qt.rgba(1,1,1,0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰊗"
                                        color: root.isGamingMode ? "#1a1a1a" : root.fgColor
                                        font.family: root.activeFont; font.pixelSize: 15
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Gaming"
                                        color: root.isGamingMode ? "#1a1a1a" : Qt.rgba(1,1,1,0.5)
                                        font.family: root.activeFont; font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.isGamingMode) {
                                            root.gamingTogglePending = true
                                            _gamingOn.running = false; _gamingOn.running = true
                                            root.isGamingMode = true
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.isGamingMode
                                ? "Wallpaper paused · Quickshell deprioritized"
                                : "Pauses animated wallpaper for max FPS"
                            color: Qt.rgba(1,1,1,0.3)
                            font.family: root.activeFont; font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Item { height: 2 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 7. Power Actions
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [
                                { icon: "󰌾", label: "Lock",   accent: false, action: "lock"     },
                                { icon: "󰍃", label: "Logout", accent: false, action: "logout"   },
                                { icon: "󰜉", label: "Reboot", accent: false, action: "reboot"   },
                                { icon: "󰐥", label: "Off",    accent: true,  action: "shutdown" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; height: 52; radius: 12
                                color: modelData.accent ? root.errorColor : Qt.rgba(1,1,1,0.05)
                                Column {
                                    anchors.centerIn: parent; spacing: 3
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: modelData.accent ? "#1a1a1a" : root.fgColor; font.family: root.activeFont; font.pixelSize: 17 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: modelData.accent ? "#1a1a1a" : Qt.rgba(1,1,1,0.45); font.family: root.activeFont; font.pixelSize: 9 }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if      (modelData.action === "lock")     lockCmd.running     = true
                                        else if (modelData.action === "logout")   logoutCmd.running   = true
                                        else if (modelData.action === "reboot")   rebootCmd.running   = true
                                        else if (modelData.action === "shutdown") shutdownCmd.running = true
                                        root.requestClose()
                                    }
                                }
                            }
                        }
                    }

                    Item { height: 4 }
                }
            }
        }
    }
}