import QtQuick
import "root:/styles" as Styles

// UsageGraph.qml
// Generic rolling line/area chart, driven by a `history` array of numbers (0-100).
// Reused for CPU, RAM, and future Disk/Network graphs — just bind `history`,
// `lineColor`, and `fillColor` differently per instance.
//
// Usage:
//   UsageGraph {
//       history: Services.SystemMonitor.cpuHistory
//       lineColor: Styles.Theme.cpuGraphColor
//       fillColor: Styles.Theme.cpuGraphFill
//       maxValue: 100
//   }

Item {
    id: root

    property var history: []        // array of numbers, oldest first
    property real maxValue: 100     // graph ceiling (e.g. 100 for %, or ramTotalMb for absolute)
    property color lineColor: Styles.Theme.cpuGraphColor
    property color fillColor: Styles.Theme.cpuGraphFill
    property real lineWidth: 2
    property bool showGridLines: true

    implicitHeight: Styles.Metrics.usageGraphHeight

    Canvas {
        id: canvas
        anchors.fill: parent

        // Redraw whenever the history array changes or the canvas resizes
        Connections {
            target: root
            function onHistoryChanged() { canvas.requestPaint() }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const w = width
            const h = height
            const data = root.history

            // ---- Grid lines (subtle, Win11-style horizontal guides at 25/50/75%) ----
            if (root.showGridLines) {
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
                ctx.lineWidth = 1
                for (let i = 1; i <= 3; i++) {
                    const y = h * (i / 4)
                    ctx.beginPath()
                    ctx.moveTo(0, y)
                    ctx.lineTo(w, y)
                    ctx.stroke()
                }
            }

            if (!data || data.length < 2) return

            const stepX = w / (root.historyCapacity() - 1)

            // ---- Build point list, right-aligned so newest data hugs the right edge ----
            const points = []
            const offset = root.historyCapacity() - data.length
            for (let i = 0; i < data.length; i++) {
                const x = (offset + i) * stepX
                const value = Math.max(0, Math.min(root.maxValue, data[i]))
                const y = h - (value / root.maxValue) * h
                points.push({ x, y })
            }

            // ---- Fill (area under the line) ----
            ctx.beginPath()
            ctx.moveTo(points[0].x, h)
            for (const p of points) ctx.lineTo(p.x, p.y)
            ctx.lineTo(points[points.length - 1].x, h)
            ctx.closePath()
            ctx.fillStyle = root.fillColor
            ctx.fill()

            // ---- Line ----
            ctx.beginPath()
            ctx.moveTo(points[0].x, points[0].y)
            for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y)
            ctx.strokeStyle = root.lineColor
            ctx.lineWidth = root.lineWidth
            ctx.lineJoin = "round"
            ctx.stroke()
        }
    }

    // How many slots the graph should assume total (matches SystemMonitor.historyLength).
    // Kept as a function so it's easy to override per-instance if needed.
    function historyCapacity() {
        return 60
    }
}
