import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Windows-style "Battery Low" toast. Fed battVal/battStatus from shell.qml's
// existing battProc poller (no separate polling here) — when it sees the
// battery cross below the low threshold while discharging, it shows a small
// popup at the bottom-center of the screen that scales/fades in, holds
// briefly, then fades itself back out automatically.
QtObject {
    id: root

    // Forwarded from shell.qml, same pattern as PowerMenu / BluetoothMenu.
    property color accentColor:   "#a1ced5"
    property color fgColor:       "#e0e4db"
    property color warnColor:     "#ffcc80"   // low battery
    property color criticalColor: "#ff6b6b"   // very low battery — a bit more saturated/alarming
    property string activeFont:   "Inter Nerd Font"

    // Fed from shell.qml's battProc — e.g. battVal: "15", battStatus: "Discharging"
    property string battVal:    ""
    property string battStatus: ""

    property int lowThreshold:      20   // % — popup triggers at/under this
    property int criticalThreshold: 10   // % — icon/text/glow turn red under this

    // Hysteresis: only fire once per "dip" below the threshold, not on every
    // single update while the battery sits under it. Rearms once charging
    // resumes or the battery climbs comfortably back above the threshold.
    property bool _armed: true

    function isCritical() { return parseInt(root.battVal) <= root.criticalThreshold }
    function levelColor() { return isCritical() ? root.criticalColor : root.warnColor }

    function _check() {
        var cap = parseInt(root.battVal)
        if (isNaN(cap)) return
        var discharging = root.battStatus.trim().toLowerCase() === "discharging"
        var low = discharging && cap <= root.lowThreshold

        if (low && root._armed) {
            root._armed = false
            showPopup()
        } else if (!discharging || cap > root.lowThreshold + 5) {
            root._armed = true
        }
    }

    onBattValChanged:    _check()
    onBattStatusChanged: _check()

    // ── Popup visibility / animation sequencing ─────────────────────────
    property bool popupVisible: false
    property real popupOpacity: 0
    property real popupScale:   0.9
    // Drives a slow pulse on the icon/glow while critical, purely cosmetic.
    property real pulsePhase:   0

    function showPopup() {
        popupVisible = true
        _fadeSeq.restart()
        if (isCritical()) _pulseAnim.start()
        else _pulseAnim.stop()
    }

    property var _pulseAnim: SequentialAnimation {
        id: _pulseAnim
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "pulsePhase"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulsePhase"; from: 1; to: 0; duration: 700; easing.type: Easing.InOutSine }
    }

    property var _fadeSeq: SequentialAnimation {
        id: _fadeSeq
        ParallelAnimation {
            NumberAnimation { target: root; property: "popupOpacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupScale";   from: 0.9; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        PauseAnimation { duration: 2600 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "popupOpacity"; from: 1; to: 0; duration: 400; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupScale";   from: 1; to: 0.95; duration: 400; easing.type: Easing.InCubic }
        }
        onFinished: { root.popupVisible = false; _pulseAnim.stop() }
    }

    property var _variants: Variants {
        id: batteryPopupVariants
        // Only the primary/first screen — one global notification,
        // not one per monitor.
        model: Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []

        PanelWindow {
            id: toastWin
            required property var modelData
            screen: modelData

            anchors { bottom: true }
            margins.bottom: 56
            implicitWidth: 300
            implicitHeight: 84
            visible: root.popupVisible
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.layer: WlrLayer.Overlay

            // Outer soft glow — tints toward the alert color, breathes when critical.
            Rectangle {
                anchors.fill: card
                anchors.margins: -6
                radius: card.radius + 6
                color: "transparent"
                border.width: 10
                border.color: root.levelColor()
                opacity: (root.popupOpacity * 0.18) + (root.isCritical() ? root.pulsePhase * 0.10 : 0)
                scale: card.scale
            }

            Rectangle {
                id: card
                anchors.fill: parent
                radius: 16
                opacity: root.popupOpacity
                scale: root.popupScale
                transformOrigin: Item.Bottom

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "#f0161616" }
                    GradientStop { position: 1.0; color: "#f00c0c0c" }
                }
                border.width: 1
                border.color: Qt.rgba(root.levelColor().r, root.levelColor().g, root.levelColor().b, 0.35)

                // subtle top hairline highlight for a bit of depth
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1 }
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Icon badge with a faint colored halo behind it
                        Item {
                            implicitWidth: 40
                            implicitHeight: 40

                            Rectangle {
                                anchors.centerIn: parent
                                width: 40; height: 40
                                radius: 20
                                color: Qt.rgba(root.levelColor().r, root.levelColor().g, root.levelColor().b, 0.14)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.isCritical() ? "󰂃" : "󰁻"   // nf-md-battery_alert / battery_20
                                color: root.levelColor()
                                font.family: root.activeFont
                                font.pixelSize: 22
                                scale: 1.0 + (root.isCritical() ? root.pulsePhase * 0.08 : 0)
                            }
                        }

                        ColumnLayout {
                            spacing: 3
                            Layout.fillWidth: true

                            Text {
                                text: root.isCritical() ? "Battery critically low" : "Battery low"
                                color: root.fgColor
                                font.family: root.activeFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: root.battVal + "% remaining" + (root.isCritical() ? " — plug in soon" : "")
                                color: Qt.rgba(1, 1, 1, 0.55)
                                font.family: root.activeFont
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Slim battery-level bar for a quick visual read
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * Math.max(0, Math.min(1, parseInt(root.battVal) / 100))
                            color: root.levelColor()
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }
        }
    }
}
