pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/services" as Services

// SystemMonitor.qml
// Singleton service. Polls RAM, CPU, and GPU usage on an interval and exposes:
//   - current numeric values (ramUsedMb, ramTotalMb, ramPercent, cpuPercent,
//     gpuAvailable, gpuUtilPercent, gpuMemUsedMb, gpuMemTotalMb, gpuMemPercent, gpuTempC)
//   - rolling history arrays (ramHistory, cpuHistory, gpuHistory) for UsageGraph.qml
//   - topRamProcesses / topGpuProcesses -- ranked lists for the Performance tab
//
// Usage from anywhere:
//   import "root:/services" as Services
//   Services.SystemMonitor.ramPercent
//   Services.SystemMonitor.topRamProcesses  -- [{pid,name,mem_mb}, ...] top 8

Item {
    id: root

    // ---- Public, bindable properties ----
    property real ramUsedMb: 0
    property real ramTotalMb: 0
    property real ramAvailableMb: 0
    property real ramPercent: 0

    property real cpuPercent: 0

    // ---- GPU (NVIDIA via nvidia-smi) ----
    property bool gpuAvailable: false
    property real gpuUtilPercent: 0
    property real gpuMemUsedMb: 0
    property real gpuMemTotalMb: 0
    property real gpuMemPercent: 0
    property real gpuTempC: 0
    property var gpuProcesses: [] // [{pid, name, mem_mb}]

    // How many samples to keep for the graphs (e.g. 60 samples @ 1s = last 60s)
    property int historyLength: 60
    property var ramHistory: []
    property var cpuHistory: []
    property var gpuHistory: []

    // Poll interval in ms. GPU poll runs on the same cadence as CPU/RAM.
    property int pollIntervalMs: 1500

    // ---- Ranked lists for the Performance tab ----
    // Top RAM comes straight from ProcessService (no extra script needed --
    // per-process mem_mb is already there). Recomputed whenever the process
    // list refreshes, capped to top 8 by memory.
    // Recomputed explicitly on every poll tick (see Timer below) rather than
    // as automatic JS-block bindings -- cross-singleton dependency tracking
    // (SystemMonitor depending on ProcessService's array) wasn't reliably
    // re-firing, so these were going stale instead of updating live.
    property var topRamProcesses: []
    property var topCpuProcesses: []

    function _updateTopProcesses() {
        const procs = Services.ProcessService.filteredProcesses || Services.ProcessService.processes || []
        root.topRamProcesses = procs.slice().sort((a, b) => (b.mem_mb || 0) - (a.mem_mb || 0)).slice(0, 8)
        root.topCpuProcesses = procs.slice().sort((a, b) => (b.cpu || 0) - (a.cpu || 0)).slice(0, 8)
    }

    // Top GPU: from gpuProcesses (VRAM-based, see get_gpu_processes.sh notes
    // on why this isn't a true per-process utilization %).
    property var topGpuProcesses: {
        return root.gpuProcesses.slice().sort((a, b) => (b.mem_mb || 0) - (a.mem_mb || 0)).slice(0, 8)
    }

    // ---- CPU calc state (CPU % must be derived by diffing two /proc/stat reads) ----
    property var _prevCpuTotal: 0
    property var _prevCpuIdle: 0

    // ---- Memory polling ----
    Process {
        id: memProcess
        command: ["bash", Quickshell.shellDir + "/services/scripts/get_mem_usage.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data)
                    root.ramTotalMb = parsed.total_mb
                    root.ramUsedMb = parsed.used_mb
                    root.ramAvailableMb = parsed.available_mb
                    root.ramPercent = parsed.percent

                    root._pushHistory(root.ramHistory, parsed.percent)
                    root.ramHistory = root.ramHistory.slice() // trigger binding update
                } catch (e) {
                    console.warn("SystemMonitor: failed to parse mem usage JSON:", e, data)
                }
            }
        }
    }

    // ---- CPU polling (reads /proc/stat directly via cat, computed here in JS) ----
    Process {
        id: cpuProcess
        command: ["cat", "/proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                // First line looks like:
                // cpu  123456 0 45678 987654 1234 0 0 0 0 0
                const line = data.split("\n")[0]
                if (!line.startsWith("cpu ")) return

                const parts = line.trim().split(/\s+/).slice(1).map(Number)
                const idle = parts[3] + (parts[4] || 0) // idle + iowait
                const total = parts.reduce((a, b) => a + b, 0)

                if (root._prevCpuTotal > 0) {
                    const totalDiff = total - root._prevCpuTotal
                    const idleDiff = idle - root._prevCpuIdle
                    const usage = totalDiff > 0 ? (1 - idleDiff / totalDiff) * 100 : 0

                    root.cpuPercent = Math.max(0, Math.min(100, usage))
                    root._pushHistory(root.cpuHistory, root.cpuPercent)
                    root.cpuHistory = root.cpuHistory.slice()
                }

                root._prevCpuTotal = total
                root._prevCpuIdle = idle
            }
        }
    }

    // ---- GPU usage polling (utilization % + VRAM) ----
    Process {
        id: gpuProcess
        command: ["bash", Quickshell.shellDir + "/services/scripts/get_gpu_usage.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data)
                    root.gpuAvailable = parsed.available
                    root.gpuUtilPercent = parsed.utilization_percent
                    root.gpuMemUsedMb = parsed.mem_used_mb
                    root.gpuMemTotalMb = parsed.mem_total_mb
                    root.gpuMemPercent = parsed.mem_percent
                    root.gpuTempC = parsed.temp_c

                    if (parsed.available) {
                        root._pushHistory(root.gpuHistory, parsed.utilization_percent)
                        root.gpuHistory = root.gpuHistory.slice()
                    }
                } catch (e) {
                    console.warn("SystemMonitor: failed to parse gpu usage JSON:", e, data)
                }
            }
        }
    }

    // ---- GPU per-process VRAM polling ----
    Process {
        id: gpuProcListProcess
        command: ["bash", Quickshell.shellDir + "/services/scripts/get_gpu_processes.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.gpuProcesses = JSON.parse(data)
                } catch (e) {
                    console.warn("SystemMonitor: failed to parse gpu processes JSON:", e, data)
                }
            }
        }
    }

    Component.onCompleted: root._updateTopProcesses()

    // ---- Poll timer ----
    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            memProcess.running = true
            cpuProcess.running = true
            gpuProcess.running = true
            gpuProcListProcess.running = true
            root._updateTopProcesses()
        }
    }

    // ---- Helpers ----
    function _pushHistory(historyArray, value) {
        historyArray.push(value)
        while (historyArray.length > root.historyLength) {
            historyArray.shift()
        }
    }
}
