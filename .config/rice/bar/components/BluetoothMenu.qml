import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

QtObject {
    id: root

    property bool  bluetoothMenuOpen: false
    property color accentColor: "#a1ced5"
    property color fgColor:     "#e0e4db"
    property color errorColor:  "#ffb4ab"
    property string activeFont: "Inter Nerd Font"

    // Offset from the right edge — set this from PowerMenu.qml so this popup
    // sits just to the left of the power menu card (same spot as WifiMenu).
    property int rightOffset: 357
    property int topOffset:   56

    signal requestClose()

    // Icon glyph per device category. "audio" covers headsets/earbuds/speakers/mics,
    // "phone" covers handsets, everything else falls back to the generic bluetooth glyph.
    function iconFor(category, connected) {
        if (category === "audio") return "󰋋" // nf-md-headphones
        if (category === "phone") return "󰄜" // nf-md-cellphone
        return connected ? "󰂱" : "󰂯"           // generic bluetooth (connected / not)
    }

    function categoryFor(mac) {
        var info = root._iconCache[mac]
        return info ? info.category : "other"
    }

    // Windows-style connected label: audio devices show which profiles are
    // active ("Music", "Mic", or both); everything else just says "Connected".
    function connectedLabel(mac) {
        var info = root._iconCache[mac]
        if (!info || info.category !== "audio") return "Connected"
        var parts = []
        if (info.music) parts.push("Music")
        if (info.mic) parts.push("Mic")
        return parts.length ? "Connected · " + parts.join(", ") : "Connected"
    }

    // Shared row delegate for both the "Paired" and "Available" sections below.
    component BtRow: ColumnLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            Layout.fillWidth: true; height: 46; radius: 10
            color: modelData.connected ? Qt.rgba(0.63,0.81,0.84,0.18)
                : (root.expandedMac === modelData.mac ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05))

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: root.iconFor(root.categoryFor(modelData.mac), modelData.connected)
                    color: modelData.connected ? root.accentColor : root.fgColor
                    font.family: root.activeFont; font.pixelSize: 15
                }

                Text {
                    text: modelData.name
                    color: modelData.connected ? root.accentColor : root.fgColor
                    font.family: root.activeFont; font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: modelData.connected
                    text: root.connectedLabel(modelData.mac)
                    color: root.accentColor
                    font.family: root.activeFont; font.pixelSize: 9
                }
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.connected) return
                    root.expandedMac = (root.expandedMac === modelData.mac) ? "" : modelData.mac
                }
            }
        }

        // Expanded action row: Connect (+ Pair first if unpaired) / Cancel
        RowLayout {
            visible: root.expandedMac === modelData.mac
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 4
            spacing: 8

            Text {
                visible: root.connectError
                text: "Failed to connect."
                color: root.errorColor
                font.family: root.activeFont; font.pixelSize: 10
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true; height: 32; radius: 8
                color: root.accentColor
                Text {
                    anchors.centerIn: parent
                    text: root.connectBusy ? (modelData.paired ? "Connecting…" : "Pairing…") : (modelData.paired ? "Connect" : "Pair & Connect")
                    color: "#1a1a1a"
                    font.family: root.activeFont; font.pixelSize: 11; font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.connectTo(modelData.mac, modelData.paired)
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
                    onClicked: root.expandedMac = ""
                }
            }
        }

        // Paired device actions: Disconnect + Forget
        RowLayout {
            visible: modelData.paired && root.expandedMac !== modelData.mac
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 4
            spacing: 8
            Layout.leftMargin: 4

            Rectangle {
                visible: modelData.connected
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
                    onClicked: root.disconnectDevice(modelData.mac)
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
                    onClicked: root.forget(modelData.mac)
                }
            }
        }
    }

    property bool btPowered: true

    property var _powerCheckProc: Process {
        id: _powerCheckProc
        command: ["sh", "-c", "bluetoothctl show | grep -i 'Powered:'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.btPowered = /Powered:\s*yes/i.test(text)
            }
        }
        onExited: (c,s) => { running = false }
    }

    property var _powerToggleProc: Process {
        id: _powerToggleProc
        property bool targetOn: true
        command: ["bluetoothctl", "power", targetOn ? "on" : "off"]
        onExited: (c,s) => {
            running = false
            root.btPowered = targetOn
            if (targetOn) root.refresh()
            else root.devices = []
        }
    }

    function toggleBtPower() {
        _powerToggleProc.targetOn = !root.btPowered
        _powerToggleProc.running = false
        _powerToggleProc.running = true
    }

    property var devices: []   // list of {mac, name, paired, connected}
    property var _iconCache: ({})   // mac -> "audio" | "phone" | "other"
    property var _iconQueue: []
    property bool scanning: _scanProc.running
    property string expandedMac: ""
    property bool connectBusy: false
    property bool connectError: false

    // Splits "Device AA:BB:CC:DD:EE:FF Some Name" -> {mac, name}
    function parseDeviceLine(line) {
        var parts = line.trim().split(" ")
        if (parts.length < 3 || parts[0] !== "Device") return null
        var mac = parts[1]
        var name = parts.slice(2).join(" ").trim()
        if (name === "") name = mac
        return { mac: mac, name: name }
    }

    function macSet(raw) {
        var out = {}
        raw.split("\n").forEach(l => {
            var d = parseDeviceLine(l)
            if (d) out[d.mac] = true
        })
        return out
    }

    property var _devicesProc: Process {
        id: _devicesProc
        command: ["bluetoothctl", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {}
                var out = []
                text.split("\n").forEach(l => {
                    var d = root.parseDeviceLine(l)
                    if (d && !seen[d.mac]) { seen[d.mac] = true; out.push(d) }
                })
                root._rawDevices = out
                _pairedProc.running = false; _pairedProc.running = true
            }
        }
        onExited: (c,s) => { running = false }
    }

    property var _pairedProc: Process {
        id: _pairedProc
        command: ["bluetoothctl", "devices", "Paired"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._pairedSet = root.macSet(text)
                _connectedProc.running = false; _connectedProc.running = true
            }
        }
        onExited: (c,s) => { running = false }
    }

    property var _connectedProc: Process {
        id: _connectedProc
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                var connectedSet = root.macSet(text)
                var paired = root._pairedSet
                var merged = root._rawDevices.map(d => ({
                    mac: d.mac,
                    name: d.name,
                    paired: !!paired[d.mac],
                    connected: !!connectedSet[d.mac]
                }))
                root.devices = merged
                root.queueIconFetch(merged.map(d => d.mac))
            }
        }
        onExited: (c,s) => { running = false }
    }

    // Classifies a device from its `bluetoothctl info <mac>` output.
    // Not every device reports a usable "Icon:" line, so we also decode the
    // Class-of-Device bitmask (same signal blueman/GNOME use) as a fallback,
    // and detect which audio profiles (A2DP "Music", HSP/HFP "Mic") it exposes.
    function classifyDevice(infoText) {
        var iconMatch = infoText.match(/Icon:\s*(\S+)/)
        var classMatch = infoText.match(/Class:\s*0x([0-9A-Fa-f]+)/)
        var icon = iconMatch ? iconMatch[1].toLowerCase() : ""

        var category = "other"
        if (icon.indexOf("audio") !== -1 || icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1 || icon.indexOf("microphone") !== -1) {
            category = "audio"
        } else if (icon.indexOf("phone") !== -1) {
            category = "phone"
        } else if (classMatch) {
            // Bits 12-8 of the 24-bit Class of Device = Major Device Class.
            // 0x04 = Audio/Video, 0x02 = Phone (Bluetooth Assigned Numbers).
            var major = (parseInt(classMatch[1], 16) >> 8) & 0x1F
            if (major === 0x04) category = "audio"
            else if (major === 0x02) category = "phone"
        }

        return {
            category: category,
            music: /Audio Sink|A2DP/i.test(infoText),
            mic: /Handsfree|Headset|HFP|HSP/i.test(infoText)
        }
    }

    function queueIconFetch(macs) {
        macs.forEach(m => {
            if (!(m in root._iconCache) && root._iconQueue.indexOf(m) === -1)
                root._iconQueue.push(m)
        })
        _processIconQueue()
    }

    function _processIconQueue() {
        if (_iconProc.running) return
        if (root._iconQueue.length === 0) return
        _iconProc.mac = root._iconQueue.shift()
        _iconProc.running = false
        _iconProc.running = true
    }

    property var _iconProc: Process {
        id: _iconProc
        property string mac: ""
        command: ["sh", "-c", "bluetoothctl info '" + mac + "' | grep -E 'Icon:|Class:|UUID:'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var cache = Object.assign({}, root._iconCache)
                cache[_iconProc.mac] = root.classifyDevice(text)
                root._iconCache = cache   // NEW object reference so bindings actually re-evaluate
            }
        }
        onExited: (c,s) => { running = false; root._processIconQueue() }
    }

    property var _rawDevices: []
    property var _pairedSet: ({})

    property var pairedDevices: devices.filter(d => d.paired).sort((a,b) => (b.connected - a.connected))
    // Devices bluetoothd has seen but never resolved a name for are almost
    // always BLE random-address adverts (phones doing MAC randomization,
    // beacons, etc.) rather than real discoverable devices — blueman and
    // GNOME Settings hide these too, so we do the same.
    property var availableDevices: devices.filter(d => !d.paired && d.name !== d.mac)

    function refresh() {
        _devicesProc.running = false; _devicesProc.running = true
    }

    property var _powerOnProc: Process {
        id: _powerOnProc
        command: ["bluetoothctl", "power", "on"]
        onExited: (c,s) => { running = false; root.btPowered = true; root.refresh() }
    }

    property var _scanProc: Process {
        id: _scanProc
        // Root cause found: each `busctl call` opens its own D-Bus
        // connection and closes it the instant the call returns. BlueZ ties
        // a discovery session to the connection that started it, so
        // discovery was being auto-stopped the moment StartDiscovery's
        // process exited — our "5 second scan" was really ~0 seconds.
        // Fix: hold a single bluetoothctl connection open for the whole
        // window by piping "scan on" / "scan off" into its stdin, instead
        // of making separate one-shot calls.
        command: ["sh", "-c",
            "{ echo 'scan on'; sleep 5; echo 'scan off'; sleep 1; } | bluetoothctl >1"]
        onExited: (c,s) => { running = false; root.refresh() }
    }

    // Refreshes partway through the scan so devices appear as soon as they're
    // discovered instead of only once the whole scan window finishes.
    property var _midScanTimer: Timer {
        interval: 2500; repeat: false
        onTriggered: { if (root.scanning) root.refresh() }
    }

    function startScan() {
        if (!root.btPowered) return
        _midScanTimer.restart()
        _scanProc.running = false; _scanProc.running = true
    }

    property var _connectProc: Process {
        id: _connectProc
        property string mac: ""
        property bool needsPair: false
        command: needsPair
            ? ["sh", "-c", "bluetoothctl pair " + mac + " && bluetoothctl trust " + mac + " && bluetoothctl connect " + mac]
            : ["bluetoothctl", "connect", mac]
        onExited: (c,s) => {
            running = false
            connectBusy = false
            connectError = (c !== 0)
            if (c === 0) root.expandedMac = ""
            root.refresh()
        }
    }

    function connectTo(mac, paired) {
        connectError = false
        connectBusy = true
        _connectProc.mac = mac
        _connectProc.needsPair = !paired
        _connectProc.running = false
        _connectProc.running = true
    }

    property var _disconnectProc: Process {
        id: _disconnectProc
        property string mac: ""
        command: ["bluetoothctl", "disconnect", mac]
        onExited: (c,s) => { running = false; root.refresh() }
    }

    function disconnectDevice(mac) {
        _disconnectProc.mac = mac
        _disconnectProc.running = false; _disconnectProc.running = true
    }

    property var _forgetProc: Process {
        id: _forgetProc
        property string mac: ""
        command: ["bluetoothctl", "remove", mac]
        onExited: (c,s) => { running = false; root.refresh() }
    }

    function forget(mac) {
        _forgetProc.mac = mac
        _forgetProc.running = false; _forgetProc.running = true
    }

    onBluetoothMenuOpenChanged: {
        if (bluetoothMenuOpen) {
            expandedMac = ""
            _powerCheckProc.running = false; _powerCheckProc.running = true
            _powerOnProc.running = false; _powerOnProc.running = true
        }
    }

    property var _variants: Variants {
        id: bluetoothMenuVariants
        model: Quickshell.screens

        PanelWindow {
            id: btWin
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            visible: root.bluetoothMenuOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.bluetoothMenuOpen
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                onClicked: root.requestClose()
            }

            Rectangle {
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
                            text: "Bluetooth Devices"
                            color: root.fgColor
                            font.family: root.activeFont; font.pixelSize: 15; font.weight: Font.Bold
                            Layout.fillWidth: true
                        }

                        // Power on/off toggle
                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: root.btPowered ? Qt.rgba(0.63,0.81,0.84,0.22) : Qt.rgba(1,1,1,0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.btPowered ? "󰂯" : "󰂲"
                                color: root.btPowered ? root.accentColor : Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 13
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleBtPower()
                            }
                        }

                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: Qt.rgba(1,1,1,0.08)
                            opacity: root.btPowered ? 1 : 0.4
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
                                enabled: root.btPowered
                                onClicked: root.startScan()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    Text {
                        visible: !root.btPowered
                        text: "Bluetooth is off"
                        color: Qt.rgba(1,1,1,0.4)
                        font.family: root.activeFont; font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                        Layout.bottomMargin: 20
                    }

                    Flickable {
                        visible: root.btPowered
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
                                visible: root.devices.length === 0
                                text: root.scanning ? "Scanning…" : "No devices found — tap scan"
                                color: Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 10
                            }

                            // ── Paired ──────────────────────────────────────────────────
                            Text {
                                visible: root.pairedDevices.length > 0
                                text: "Paired"
                                color: Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                                Layout.topMargin: 2
                            }

                            Repeater {
                                model: root.pairedDevices
                                delegate: BtRow {}
                            }

                            Rectangle {
                                visible: root.pairedDevices.length > 0 && root.availableDevices.length > 0
                                Layout.fillWidth: true; height: 1
                                color: Qt.rgba(1,1,1,0.08)
                                Layout.topMargin: 4; Layout.bottomMargin: 2
                            }

                            // ── Available ───────────────────────────────────────────────
                            Text {
                                visible: root.availableDevices.length > 0
                                text: "Available"
                                color: Qt.rgba(1,1,1,0.4)
                                font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                                Layout.topMargin: root.pairedDevices.length > 0 ? 0 : 2
                            }

                            Repeater {
                                model: root.availableDevices
                                delegate: BtRow {}
                            }
                        }
                    }
                }
            }
        }
    }
}
