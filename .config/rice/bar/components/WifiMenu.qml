import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

QtObject {
    id: root

    property bool  wifiMenuOpen: false
    property color accentColor: "#9fd49b"
    property color fgColor:     "#e0e4db"
    property color errorColor:  "#ffb4ab"
    property string activeFont: "Inter Nerd Font"

    // Offset from the right edge — set this from PowerMenu.qml so the
    // wifi popup sits just to the left of the power menu card.
    property int rightOffset: 357   // 5 (power menu rightMargin) + 340 (power menu width) + 12 (gap)
    property int topOffset:   56

    signal requestClose()

    // Shared row delegate for both the "Saved" and "Available" sections below.
    component WifiRow: ColumnLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            Layout.fillWidth: true; height: 46; radius: 10
            color: modelData.active ? Qt.rgba(0.62,0.83,0.61,0.18)
                : (root.expandedSsid === modelData.ssid ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05))

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: modelData.signal > 70 ? "󰤨" : modelData.signal > 40 ? "󰤢" : "󰤟"
                    color: modelData.active ? root.accentColor : root.fgColor
                    font.family: root.activeFont; font.pixelSize: 15
                }

                Text {
                    text: modelData.ssid
                    color: modelData.active ? root.accentColor : root.fgColor
                    font.family: root.activeFont; font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: modelData.secured
                    text: "󰌾"
                    color: Qt.rgba(1,1,1,0.4)
                    font.family: root.activeFont; font.pixelSize: 11
                }

                Text {
                    visible: modelData.active
                    text: "Connected"
                    color: root.accentColor
                    font.family: root.activeFont; font.pixelSize: 9
                }
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.active) return
                    if (root.expandedSsid === modelData.ssid) {
                        root.expandedSsid = ""
                    } else {
                        root.passwordInput = ""
                        root.connectError = false
                        if (!modelData.secured || modelData.saved) {
                            root.connectTo(modelData.ssid, modelData.secured, modelData.saved, "")
                        } else {
                            root.expandedSsid = modelData.ssid
                        }
                    }
                }
            }
        }

        // Expanded password entry for unsaved secured networks
        ColumnLayout {
            visible: root.expandedSsid === modelData.ssid
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 4
            spacing: 6

            Rectangle {
                Layout.fillWidth: true; height: 36; radius: 8
                color: Qt.rgba(1,1,1,0.07)
                border.color: Qt.rgba(1,1,1,0.12)

                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.fgColor
                    font.family: root.activeFont; font.pixelSize: 12
                    echoMode: TextInput.Password
                    focus: root.expandedSsid === modelData.ssid
                    text: root.passwordInput
                    onTextChanged: root.passwordInput = text
                    Keys.onReturnPressed: root.connectTo(modelData.ssid, true, false, root.passwordInput)
                }
            }

            Text {
                visible: root.connectError
                text: "Failed to connect. Check password."
                color: root.errorColor
                font.family: root.activeFont; font.pixelSize: 10
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 8
                    color: root.accentColor
                    Text {
                        anchors.centerIn: parent
                        text: root.connectBusy ? "Connecting…" : "Connect"
                        color: "#1a1a1a"
                        font.family: root.activeFont; font.pixelSize: 11; font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.connectTo(modelData.ssid, true, false, root.passwordInput)
                    }
                }
                Rectangle {
                    width: 70; height: 32; radius: 8
                    color: Qt.rgba(1,1,1,0.08)
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: root.fgColor
                        font.family: root.activeFont; font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.expandedSsid = ""
                    }
                }
            }
        }

        // Saved / connected network actions: Disconnect + Forget
        RowLayout {
            visible: modelData.saved && root.expandedSsid !== modelData.ssid
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 4
            spacing: 8
            Layout.leftMargin: 4

            Rectangle {
                visible: modelData.active
                width: 90; height: 26; radius: 7
                color: Qt.rgba(1,1,1,0.07)
                Text {
                    anchors.centerIn: parent
                    text: "Disconnect"
                    color: Qt.rgba(1,1,1,0.6)
                    font.family: root.activeFont; font.pixelSize: 9
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.disconnectCurrent()
                }
            }

            Rectangle {
                width: 70; height: 26; radius: 7
                color: Qt.rgba(1,1,1,0.07)
                Text {
                    anchors.centerIn: parent
                    text: "Forget"
                    color: root.errorColor
                    font.family: root.activeFont; font.pixelSize: 9
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.forget(modelData.ssid)
                }
            }
        }
    }

    property var networks: []   // list of {ssid, signal, secured, active, saved}
    property bool scanning: false
    property bool wifiPowered: true

    // Connected/saved networks bubble to their own section, sorted with the
    // currently active connection first; everything else stays in "available".
    property var savedNetworks: networks.filter(n => n.saved).sort((a,b) => (b.active - a.active) || (b.signal - a.signal))
    property var availableNetworks: networks.filter(n => !n.saved)

    // Splits a terse nmcli line on ':' while respecting '\:' escapes,
    // without relying on regex lookbehind (unsupported by some QJSEngine versions).
    function splitTerse(line) {
        var parts = []
        var cur = ""
        for (var i = 0; i < line.length; i++) {
            var ch = line.charAt(i)
            if (ch === "\\" && i + 1 < line.length && line.charAt(i+1) === ":") {
                cur += ":"
                i++
            } else if (ch === ":") {
                parts.push(cur)
                cur = ""
            } else {
                cur += ch
            }
        }
        parts.push(cur)
        return parts
    }

    function parseNetworks(raw) {
        var lines = raw.split("\n").filter(l => l.trim().length > 0)
        var seen = {}
        var out = []
        for (var i = 0; i < lines.length; i++) {
            var parts = splitTerse(lines[i])
            if (parts.length < 4) continue
            var ssid = parts[0].trim()
            if (ssid === "") continue
            var signal = parseInt(parts[1]) || 0
            var security = parts[2]
            var inUse = parts[3].trim() === "*"
            if (seen[ssid] !== undefined) {
                // keep the strongest signal entry for duplicate SSIDs
                if (out[seen[ssid]].signal < signal) {
                    out[seen[ssid]].signal = signal
                    out[seen[ssid]].active = out[seen[ssid]].active || inUse
                }
                continue
            }
            seen[ssid] = out.length
            out.push({
                ssid: ssid,
                signal: signal,
                secured: security !== "" && security !== "--",
                active: inUse,
                saved: false
            })
        }
        out.sort((a,b) => b.signal - a.signal)
        return out
    }

    property var _powerCheckProc: Process {
        id: _powerCheckProc
        command: ["sh", "-c", "nmcli radio wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiPowered = text.trim().toLowerCase() === "enabled"
            }
        }
        onExited: (c,s) => { running = false }
    }

    property var _powerToggleProc: Process {
        id: _powerToggleProc
        property bool targetOn: true
        command: ["nmcli", "radio", "wifi", targetOn ? "on" : "off"]
        onExited: (c,s) => {
            running = false
            root.wifiPowered = targetOn
            if (targetOn) root.rescan()
            else root.networks = []
        }
    }

    function toggleWifiPower() {
        _powerToggleProc.targetOn = !root.wifiPowered
        _powerToggleProc.running = false
        _powerToggleProc.running = true
    }

    property var _scanProc: Process {
        id: _scanProc
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.networks = root.parseNetworks(text)
                root.scanning = false
                _savedProc.running = false; _savedProc.running = true
            }
        }
        onExited: (c,s) => { running = false }
    }

    property var _savedProc: Process {
        id: _savedProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE con show | awk -F: '$2==\"802-11-wireless\"{print $1}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var saved = {}
                text.split("\n").forEach(l => { if (l.trim() !== "") saved[l.trim()] = true })
                var nets = root.networks
                for (var i = 0; i < nets.length; i++) nets[i].saved = !!saved[nets[i].ssid]
                root.networks = nets.slice()
            }
        }
        onExited: (c,s) => { running = false }
    }

    function rescan() {
        if (!root.wifiPowered) return
        scanning = true
        _scanProc.running = false; _scanProc.running = true
    }

    property var _connectProc: Process {
        id: _connectProc
        property string ssid: ""
        property string pass: ""
        property bool usePass: false
        command: usePass
            ? ["nmcli", "dev", "wifi", "connect", ssid, "password", pass]
            : ["nmcli", "dev", "wifi", "connect", ssid]
        onExited: (c,s) => {
            running = false
            connectBusy = false
            var ok = (c === 0)
            connectError = !ok
            if (ok) {
                root.expandedSsid = ""
                root.markConnected(ssid)
            }
        }
    }

    function markConnected(ssid) {
        var nets = root.networks.map(n => {
            var copy = Object.assign({}, n)
            if (copy.ssid === ssid) {
                copy.active = true
                copy.saved = true
            } else {
                copy.active = false
            }
            return copy
        })
        root.networks = nets
    }

    property bool connectBusy: false
    property bool connectError: false

    function connectTo(ssid, secured, saved, password) {
        connectError = false
        connectBusy = true
        _connectProc.ssid = ssid
        if (!secured || saved) {
            _connectProc.usePass = false
        } else {
            _connectProc.usePass = true
            _connectProc.pass = password || ""
        }
        _connectProc.running = false
        _connectProc.running = true
    }

    property var _forgetProc: Process {
        id: _forgetProc
        property string ssid: ""
        command: ["nmcli", "con", "delete", ssid]
        onExited: (c,s) => {
            running = false
            if (c === 0) root.markForgotten(ssid)
        }
    }

    function forget(ssid) {
        _forgetProc.ssid = ssid
        _forgetProc.running = false; _forgetProc.running = true
    }

    function markForgotten(ssid) {
        var nets = root.networks.map(n => {
            if (n.ssid !== ssid) return n
            var copy = Object.assign({}, n)
            copy.saved = false
            copy.active = false
            return copy
        })
        root.networks = nets
    }

    function disconnectCurrent() {
        _disconnectProc.running = false; _disconnectProc.running = true
    }

    property var _disconnectProc: Process {
        id: _disconnectProc
        command: ["sh", "-c", "nmcli dev disconnect $(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2==\"wifi\"{print $1; exit}')"]
        onExited: (c,s) => {
            running = false
            if (c === 0) root.markAllDisconnected()
        }
    }

    function markAllDisconnected() {
        var nets = root.networks.map(n => {
            if (!n.active) return n
            var copy = Object.assign({}, n)
            copy.active = false
            return copy
        })
        root.networks = nets
    }

    onWifiMenuOpenChanged: {
        if (wifiMenuOpen) {
            expandedSsid = ""
            passwordInput = ""
            _powerCheckProc.running = false; _powerCheckProc.running = true
            rescan()
        }
    }

    property string expandedSsid: ""
    property string passwordInput: ""

    property var _variants: Variants {
        id: wifiMenuVariants
        model: Quickshell.screens

        PanelWindow {
            id: wifiWin
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            visible: root.wifiMenuOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.wifiMenuOpen
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                onClicked: root.requestClose()
            }

            Rectangle {
                id: card
                width: 300
                height: Math.min(colLayout.implicitHeight + 40, 520)
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: root.topOffset
                anchors.rightMargin: root.rightOffset
                color: "#ee0d0d0d"
                border.color: Qt.rgba(1,1,1,0.08)
                radius: 14
                clip: true

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: colLayout
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 20
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Wi-Fi Networks"
                            color: root.fgColor
                            font.family: root.activeFont; font.pixelSize: 15; font.weight: Font.Bold
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: root.wifiPowered ? Qt.rgba(0.62,0.83,0.61,0.22) : Qt.rgba(1,1,1,0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.wifiPowered ? "󰖩" : "󰖪"
                                color: root.wifiPowered ? root.accentColor : Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 13
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleWifiPower()
                            }
                        }

                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: Qt.rgba(1,1,1,0.08)
                            opacity: root.wifiPowered ? 1 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: root.scanning ? "󰑐" : "󰑓"
                                color: root.fgColor
                                font.family: root.activeFont; font.pixelSize: 13
                                RotationAnimation on rotation {
                                    running: root.scanning
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 900
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                enabled: root.wifiPowered
                                onClicked: root.rescan()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    Text {
                        visible: !root.wifiPowered
                        text: "Wi-Fi is off"
                        color: Qt.rgba(1,1,1,0.4)
                        font.family: root.activeFont; font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                        Layout.bottomMargin: 20
                    }

                    Flickable {
                        visible: root.wifiPowered
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(listCol.implicitHeight, 420)
                        contentWidth: width
                        contentHeight: listCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: listCol
                            width: parent.width
                            spacing: 6

                            Text {
                                visible: root.networks.length === 0
                                text: root.scanning ? "Scanning…" : "No networks found"
                                color: Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 10
                            }

                            Text {
                                visible: root.savedNetworks.length > 0
                                text: "Saved"
                                color: Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                                Layout.topMargin: 2
                            }

                            Repeater {
                                model: root.savedNetworks
                                delegate: WifiRow {}
                            }

                            Rectangle {
                                visible: root.savedNetworks.length > 0 && root.availableNetworks.length > 0
                                Layout.fillWidth: true; height: 1
                                color: Qt.rgba(1,1,1,0.08)
                                Layout.topMargin: 4; Layout.bottomMargin: 2
                            }

                            Text {
                                visible: root.availableNetworks.length > 0
                                text: "Available"
                                color: Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                                Layout.topMargin: root.savedNetworks.length > 0 ? 0 : 2
                            }

                            Repeater {
                                model: root.availableNetworks
                                delegate: WifiRow {}
                            }
                        }
                    }
                }
            }
        }
    }
}