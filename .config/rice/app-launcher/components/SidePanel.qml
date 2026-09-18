import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var    topApps:        []
    property real   cpuUsage:       0.0
    property real   ramUsage:       0.0
    property real   diskUsage:      0.0   // 0.0–1.0
    property real   netRxKbps:      0.0   // KB/s
    property real   netTxKbps:      0.0   // KB/s
    property string uptimeStr:      ""
    property string dateStr:        ""

    // Repaints for disk strip
    onDiskUsageChanged:  diskCanvas.requestPaint()
    onNetRxKbpsChanged:  netCanvas.requestPaint()
    onNetTxKbpsChanged:  netCanvas.requestPaint()

    property color  surface:          "#10140f"
    property color  fgColor:          "#e0e4db"
    property color  primary:          "#9fd49b"
    property color  surfaceContainer: "#1c211b"
    property color  primaryContainer: "#215025"
    property color  tertiary:         "#a1ced5"
    property string activeFont:       "Inter Nerd Font"

    signal launchRequested(var app)

    color: Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, 0.75)
    radius: 0
    layer.enabled: true

    // ── Smooth gauge transitions ──────────────────────────────────────────────
    property real smoothCpu:  cpuUsage
    property real smoothRam:  ramUsage
    property real smoothDisk: diskUsage
    Behavior on smoothCpu  { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on smoothRam  { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on smoothDisk { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    onSmoothCpuChanged:  { cpuGauge.requestPaint();  cpuRipple.requestPaint()  }
    onSmoothRamChanged:  { ramGauge.requestPaint();  ramRipple.requestPaint()  }
    onSmoothDiskChanged: { diskCanvas.requestPaint() }

    // ── Ripple ticker ─────────────────────────────────────────────────────────
    property real ripplePhase: 0.0
    NumberAnimation on ripplePhase {
        from: 0.0; to: 1.0; duration: 2200
        loops: Animation.Infinite; running: true
    }
    onRipplePhaseChanged: { cpuRipple.requestPaint(); ramRipple.requestPaint() }

    // ── Net smoothing (log scale so idle doesn't look flat) ───────────────────
    function fmtNet(kbps) {
        if (kbps >= 1024) return (kbps/1024).toFixed(1) + " MB/s"
        if (kbps >= 1)    return kbps.toFixed(0)        + " KB/s"
        return "0 KB/s"
    }
    // Map KB/s to 0-1 on a log scale capped at 10 MB/s
    function netScale(kbps) {
        if (kbps <= 0) return 0
        return Math.min(1, Math.log10(1 + kbps) / Math.log10(1 + 10240))
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 0; spacing: 0

        // ── Image + Gauges ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height * 0.40
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(primary.r, primary.g, primary.b, 0.08)
            }

            Item {
                id: sideImage
                anchors.fill: parent

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: parent.height * 0.55
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(surface.r, surface.g, surface.b, 0.94) }
                    }
                }
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width; height: parent.height * 0.48
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(surface.r, surface.g, surface.b, 0.72) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // ── CPU gauge — top left ──────────────────────────────────────────
            Item {
                id: cpuBlock
                width: 110; height: 110
                anchors.top: parent.top; anchors.topMargin: 14
                anchors.left: parent.left; anchors.leftMargin: 14

                Canvas {
                    id: cpuRipple; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width/2, cy = height/2, val = smoothCpu
                        for (var r = 0; r < 3; r++) {
                            var phase = (ripplePhase + r*0.333) % 1.0
                            ctx.beginPath()
                            ctx.arc(cx, cy, 38+phase*18, 0, Math.PI*2)
                            ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, (1-phase)*(0.10+val*0.30))
                            ctx.lineWidth = 1.5; ctx.stroke()
                        }
                    }
                }
                Canvas {
                    id: cpuGauge; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width/2, cy = height/2, r = 34
                        var start = -Math.PI*0.75, sweep = Math.PI*1.5, val = smoothCpu
                        ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep)
                        ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.12)
                        ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                        if (val > 0.005) {
                            var heat = Math.min(val*1.4, 1.0)
                            var ar = primary.r+(1.0-primary.r)*heat*0.6
                            var ag = primary.g+(0.65-primary.g)*heat*0.6
                            var ab = primary.b*(1.0-heat*0.7)
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.28)
                            ctx.lineWidth = 11; ctx.lineCap = "round"; ctx.stroke()
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 1.0)
                            ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                        }
                        ctx.fillStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.90)
                        ctx.font = "bold 15px sans-serif"
                        ctx.textAlign = "center"; ctx.textBaseline = "middle"
                        ctx.fillText("▦", cx, cy-8)
                        ctx.font = "bold 11px sans-serif"
                        ctx.fillStyle = Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.90)
                        ctx.fillText(Math.round(val*100)+"%", cx, cy+8)
                    }
                }
                Text {
                    text: "CPU"; anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; bottomPadding: 2
                    font.family: activeFont; font.pixelSize: 9; font.weight: Font.Medium
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.45)
                }
            }

            // ── Centre: date + uptime ─────────────────────────────────────────
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 18
                width: parent.width - 268; height: 110

                Column {
                    anchors.centerIn: parent; spacing: 6
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dateStr !== "" ? dateStr : Qt.formatDate(new Date(), "ddd, dd MMM")
                        font.family: activeFont; font.pixelSize: 13; font.weight: Font.Medium
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.88)
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 36; height: 1
                        color: Qt.rgba(primary.r, primary.g, primary.b, 0.50)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: uptimeStr !== "" ? uptimeStr : ""
                        visible: uptimeStr !== ""
                        font.family: activeFont; font.pixelSize: 10
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.58)
                    }
                }
            }

            // ── RAM gauge — top right ─────────────────────────────────────────
            Item {
                id: ramBlock
                width: 110; height: 110
                anchors.top: parent.top; anchors.topMargin: 14
                anchors.right: parent.right; anchors.rightMargin: 14

                Canvas {
                    id: ramRipple; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width/2, cy = height/2, val = smoothRam
                        for (var r = 0; r < 3; r++) {
                            var phase = (ripplePhase + r*0.333 + 0.5) % 1.0
                            ctx.beginPath()
                            ctx.arc(cx, cy, 38+phase*18, 0, Math.PI*2)
                            ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, (1-phase)*(0.10+val*0.30))
                            ctx.lineWidth = 1.5; ctx.stroke()
                        }
                    }
                }
                Canvas {
                    id: ramGauge; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width/2, cy = height/2, r = 34
                        var start = -Math.PI*0.75, sweep = Math.PI*1.5, val = smoothRam
                        ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep)
                        ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.12)
                        ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                        if (val > 0.005) {
                            var heat = Math.min(val*1.3, 1.0)
                            var ar = tertiary.r+(1.0-tertiary.r)*heat*0.6
                            var ag = tertiary.g*(1.0-heat*0.55)
                            var ab = tertiary.b*(1.0-heat*0.75)
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.28)
                            ctx.lineWidth = 11; ctx.lineCap = "round"; ctx.stroke()
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 1.0)
                            ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                        }
                        ctx.fillStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.90)
                        ctx.font = "bold 15px sans-serif"
                        ctx.textAlign = "center"; ctx.textBaseline = "middle"
                        ctx.fillText("▤", cx, cy-8)
                        ctx.font = "bold 11px sans-serif"
                        ctx.fillStyle = Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.90)
                        ctx.fillText(Math.round(val*100)+"%", cx, cy+8)
                    }
                }
                Text {
                    text: "RAM"; anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; bottomPadding: 2
                    font.family: activeFont; font.pixelSize: 9; font.weight: Font.Medium
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.45)
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // ── Info strip — disk arc left, net speeds right ───────────────────
            // ══════════════════════════════════════════════════════════════════
            Item {
                anchors.left:   parent.left;  anchors.leftMargin:  12
                anchors.right:  parent.right; anchors.rightMargin: 12
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                height: 52

                // ── Disk mini arc + label (left half) ─────────────────────────
                Item {
                    id: diskItem
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.45
                    height: parent.height

                    Canvas {
                        id: diskCanvas
                        width: 44; height: 44
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width/2, cy = height/2, r = 18
                            var start = -Math.PI*0.75, sweep = Math.PI*1.5
                            var val = smoothDisk

                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep)
                            ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.12)
                            ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()

                            if (val > 0.005) {
                                var heat = Math.min((val - 0.5) * 2, 1.0)
                                heat = Math.max(0, heat)
                                var dr = primary.r + (1.0  - primary.r) * heat * 0.7
                                var dg = primary.g + (0.6  - primary.g) * heat * 0.7
                                var db = primary.b * (1.0  - heat * 0.8)
                                ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                                ctx.strokeStyle = Qt.rgba(dr, dg, db, 0.25)
                                ctx.lineWidth = 8; ctx.lineCap = "round"; ctx.stroke()
                                ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                                ctx.strokeStyle = Qt.rgba(dr, dg, db, 1.0)
                                ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()
                            }

                            ctx.fillStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.85)
                            ctx.font = "bold 10px sans-serif"
                            ctx.textAlign = "center"; ctx.textBaseline = "middle"
                            ctx.fillText("◉", cx, cy-5)
                            ctx.font = "bold 8px sans-serif"
                            ctx.fillStyle = Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.85)
                            ctx.fillText(Math.round(val*100)+"%", cx, cy+6)
                        }
                    }

                    Column {
                        anchors.left: diskCanvas.right; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "disk"
                            font.family: activeFont; font.pixelSize: 9; font.weight: Font.Medium
                            color: Qt.rgba(primary.r, primary.g, primary.b, 0.70)
                        }
                        Text {
                            text: Math.round(smoothDisk * 100) + "% used"
                            font.family: activeFont; font.pixelSize: 8
                            color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.50)
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 32
                    color: Qt.rgba(1, 1, 1, 0.07)
                }

                // ── Network TX/RX (right half) ────────────────────────────────
                Item {
                    id: netItem
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.50
                    height: parent.height

                    Canvas {
                        id: netCanvas
                        width: 44; height: 44
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width/2, cy = height/2

                            var rxVal = netScale(netRxKbps)
                            var txVal = netScale(netTxKbps)

                            ctx.beginPath()
                            ctx.arc(cx, cy, 18, -Math.PI, 0)
                            ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.10)
                            ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()

                            if (rxVal > 0.01) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, 18, -Math.PI, -Math.PI + Math.PI*rxVal)
                                ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.28)
                                ctx.lineWidth = 8; ctx.lineCap = "round"; ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(cx, cy, 18, -Math.PI, -Math.PI + Math.PI*rxVal)
                                ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 1.0)
                                ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()
                            }

                            ctx.beginPath()
                            ctx.arc(cx, cy, 18, 0, Math.PI)
                            ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.10)
                            ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()

                            if (txVal > 0.01) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, 18, 0, Math.PI*txVal)
                                ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.28)
                                ctx.lineWidth = 8; ctx.lineCap = "round"; ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(cx, cy, 18, 0, Math.PI*txVal)
                                ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 1.0)
                                ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()
                            }

                            ctx.fillStyle = Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.55)
                            ctx.font = "bold 11px sans-serif"
                            ctx.textAlign = "center"; ctx.textBaseline = "middle"
                            ctx.fillText("⇅", cx, cy)
                        }
                    }

                    Column {
                        anchors.left: netCanvas.right; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Row {
                            spacing: 4
                            Text {
                                text: "↓"
                                font.pixelSize: 9
                                color: Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.80)
                            }
                            Text {
                                text: fmtNet(netRxKbps)
                                font.family: activeFont; font.pixelSize: 9
                                color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.65)
                            }
                        }

                        Row {
                            spacing: 4
                            Text {
                                text: "↑"
                                font.pixelSize: 9
                                color: Qt.rgba(primary.r, primary.g, primary.b, 0.80)
                            }
                            Text {
                                text: fmtNet(netTxKbps)
                                font.family: activeFont; font.pixelSize: 9
                                color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.65)
                            }
                        }
                    }
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // ── Most used apps ────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 0

                Text {
                    text: "Frequent"
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.45)
                    font.family: activeFont; font.pixelSize: 10; font.weight: Font.Medium
                    bottomPadding: 10
                }

                Repeater {
                    model: topApps
                    Rectangle {
                        width: parent.width; height: 44; radius: 0
                        color: rowHover.containsMouse
                            ? Qt.rgba(primary.r, primary.g, primary.b, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 8; spacing: 10
                            Image {
                                width: 26; height: 26
                                anchors.verticalCenter: parent.verticalCenter
                                fillMode: Image.PreserveAspectFit; smooth: true
                                source: modelData.icon !== "" ? "file://"+modelData.icon : ""
                                visible: modelData.icon !== "" && status !== Image.Error
                                Rectangle {
                                    visible: parent.status === Image.Error || modelData.icon === ""
                                    anchors.fill: parent; radius: 6; color: primaryContainer
                                    Text { anchors.centerIn: parent; text: modelData.name.charAt(0)
                                        color: primary; font.pixelSize: 13; font.bold: true }
                                }
                            }
                            Text {
                                text: modelData.name; color: fgColor
                                font.family: activeFont; font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight; width: parent.parent.width - 60
                            }
                        }
                        MouseArea {
                            id: rowHover; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: launchRequested(modelData)
                        }
                    }
                }

                Item {
                    visible: !Array.isArray(topApps) || topApps.length === 0
                    width: parent.width; height: 60
                    Text {
                        anchors.centerIn: parent; text: "No recent apps"
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.25)
                        font.family: activeFont; font.pixelSize: 11
                    }
                }
            }
        }
    }
}