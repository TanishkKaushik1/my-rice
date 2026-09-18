import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Per-application volume mixer popup.
// Lists active PulseAudio/Pipewire sink-inputs (i.e. apps currently playing
// audio) and lets you adjust each one's volume / mute independently, using
// `pactl`. Streams sharing the same app name are grouped into a single row
// and controlled together. Positioned like WifiMenu/BluetoothMenu — same
// left-hand slot.
QtObject {
    id: root

    property color  accentColor: "#9fd49b"
    property color  fgColor:     "#e0e4db"
    property color  errorColor:  "#ffb4ab"
    property string activeFont:  "Inter Nerd Font"

    property real rightOffset: 357
    property real topOffset:   56

    property bool appMixerMenuOpen: false
    signal requestClose()

    // Model of currently playing app streams, grouped by app name:
    // [{ ids: [sink-input indices...], name, icon, volume (0-150), muted }]
    property var streams: []

    function refresh() {
        _listStreams.running = false
        _listStreams.running = true
    }

    onAppMixerMenuOpenChanged: {
        if (appMixerMenuOpen) refresh()
    }

    // Poll while open so external volume changes (e.g. media key) stay in sync
    property var _pollTimer: Timer {
        interval: 2000; repeat: true
        running: root.appMixerMenuOpen
        onTriggered: root.refresh()
    }

    // Dumps sink-inputs as JSON and groups them by app/media name so a
    // single app with multiple streams (BGM + SFX, etc.) shows as one row.
    property var _listStreams: Process {
        id: _listStreams
        command: ["sh", "-c", "pactl -f json list sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = JSON.parse(text)
                    var groups = {}   // name -> aggregated entry
                    var order = []    // preserve first-seen order

                    for (var i = 0; i < raw.length; i++) {
                        var s = raw[i]
                        var props = s.properties || {}
                        var name = props["application.name"] || props["media.name"] || "Unknown"
                        var icon = props["application.icon_name"] || ""
                        var vols = s.volume ? Object.values(s.volume) : []
                        var pct = 0
                        if (vols.length > 0 && vols[0].value_percent) {
                            pct = parseInt(vols[0].value_percent.toString().replace("%", ""))
                        }

                        if (!groups[name]) {
                            groups[name] = { ids: [], name: name, icon: icon, volume: pct, muted: true }
                            order.push(name)
                        }
                        var g = groups[name]
                        g.ids.push(s.index)
                        // Represent the group's volume as the loudest active stream,
                        // and only show "muted" if every stream in the group is muted.
                        g.volume = Math.max(g.volume, pct)
                        g.muted = g.muted && !!s.mute
                    }

                    var out = []
                    for (var j = 0; j < order.length; j++) out.push(groups[order[j]])
                    root.streams = out
                } catch (e) {
                    root.streams = []
                }
            }
        }
        onExited: (c, s) => { running = false }
    }

    // Applies a volume to every sink-input id in the group, chained with &&.
    property var _setVolume: Process {
        id: _setVolume
        property var streamIds: []
        property int vol: 100
        command: {
            var parts = []
            for (var i = 0; i < streamIds.length; i++)
                parts.push("pactl set-sink-input-volume " + streamIds[i] + " " + vol + "%")
            return ["sh", "-c", parts.join(" && ")]
        }
        onExited: (c, s) => { running = false }
    }

    // Toggles mute on every sink-input id in the group, chained with &&.
    property var _toggleMute: Process {
        id: _toggleMute
        property var streamIds: []
        command: {
            var parts = []
            for (var i = 0; i < streamIds.length; i++)
                parts.push("pactl set-sink-input-mute " + streamIds[i] + " toggle")
            return ["sh", "-c", parts.join(" && ")]
        }
        onExited: (c, s) => { running = false; root.refresh() }
    }

    function _idsKey(ids) {
        return ids.join(",")
    }

    function setVolume(streamIds, vol) {
        // reflect immediately for responsive slider
        var key = _idsKey(streamIds)
        var arr = root.streams.slice()
        for (var i = 0; i < arr.length; i++) {
            if (_idsKey(arr[i].ids) === key) arr[i] = Object.assign({}, arr[i], { volume: vol })
        }
        root.streams = arr

        _setVolume.streamIds = streamIds
        _setVolume.vol = vol
        _setVolume.running = false
        _setVolume.running = true
    }

    function toggleMute(streamIds) {
        _toggleMute.streamIds = streamIds
        _toggleMute.running = false
        _toggleMute.running = true
    }

    property var _variants: Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors { top: true; right: true }
            margins { top: root.topOffset; right: root.rightOffset }
            width: 300
            height: Math.min(360, mixerCol.implicitHeight + 40)
            visible: root.appMixerMenuOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.appMixerMenuOpen
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                onClicked: root.requestClose()
            }

            Rectangle {
                anchors.fill: parent
                color: "#ee0d0d0d"
                border.color: Qt.rgba(1, 1, 1, 0.08)
                radius: 14

                MouseArea { anchors.fill: parent } // eat clicks so they don't fall through to requestClose

                ColumnLayout {
                    id: mixerCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "App Volume"; color: root.fgColor
                            font.family: root.activeFont; font.pixelSize: 14; font.weight: Font.Bold
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "󰑐"
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.family: root.activeFont; font.pixelSize: 14
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    Text {
                        visible: root.streams.length === 0
                        Layout.fillWidth: true
                        text: "No apps playing audio"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font.family: root.activeFont; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: 8; bottomPadding: 8
                    }

                    Repeater {
                        model: root.streams
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Text {
                                    text: modelData.muted ? "󰝟" : "󰕾"
                                    color: modelData.muted ? root.errorColor : root.accentColor
                                    font.family: root.activeFont; font.pixelSize: 14
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleMute(modelData.ids)
                                    }
                                }
                                Text {
                                    text: modelData.name
                                    color: root.fgColor
                                    font.family: root.activeFont; font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    // Show stream count if the app has more than one active stream
                                    text: modelData.volume + "%" + (modelData.ids.length > 1 ? " (" + modelData.ids.length + ")" : "")
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font.family: root.activeFont; font.pixelSize: 11
                                }
                            }

                            Item {
                                Layout.fillWidth: true; height: 20
                                Rectangle {
                                    id: appTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left; anchors.right: parent.right
                                    height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                                    Rectangle {
                                        width: parent.width * Math.min(modelData.volume, 150) / 150
                                        height: parent.height; radius: parent.radius
                                        color: modelData.muted ? Qt.rgba(1, 1, 1, 0.3)
                                             : modelData.volume > 100 ? "#f0c040" : root.accentColor
                                    }
                                }
                                Rectangle {
                                    width: 12; height: 12; radius: 6
                                    color: modelData.muted ? Qt.rgba(1, 1, 1, 0.3)
                                         : modelData.volume > 100 ? "#f0c040" : root.accentColor
                                    border.color: Qt.rgba(0, 0, 0, 0.3); border.width: 1
                                    anchors.verticalCenter: appTrack.verticalCenter
                                    x: (appTrack.width - width) * Math.min(modelData.volume, 150) / 150
                                }
                                MouseArea {
                                    anchors.fill: parent; preventStealing: true; cursorShape: Qt.PointingHandCursor
                                    function update(mx) {
                                        var vol = Math.round(Math.max(0, Math.min(1, mx / width)) * 150)
                                        root.setVolume(modelData.ids, vol)
                                    }
                                    onClicked: (m) => update(m.x)
                                    onPositionChanged: (m) => { if (pressed) update(m.x) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}