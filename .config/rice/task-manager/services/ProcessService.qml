pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ProcessService.qml
// Singleton service. Polls the running process list via get_processes.sh and
// exposes it as a ListModel-friendly array. Also provides killProcess(pid)
// which is called from ProcessContextMenu.qml's "End Task" item.
//
// Usage:
//   import "root:/services" as Services
//   Services.ProcessService.processes        -> array of process objects
//   Services.ProcessService.killProcess(pid)  -> terminate a process

Item {
    id: root

    // Array of { pid, name, cpu, mem_mb, mem_percent, user }
    property var processes: []

    // Set while a kill is in-flight, so UI can show a small spinner/disable the row
    property var pendingKillPids: []

    // How often to refresh the process list. Slightly slower than RAM/CPU polling
    // since enumerating + sorting all processes is heavier.
    property int pollIntervalMs: 2000

    // Optional search/filter text, bound from SearchBar.qml. ProcessesView.qml
    // can also just filter `processes` itself, but keeping it here means the
    // filtered list is available to anything that binds to ProcessService.
    property string filterText: ""

    readonly property var filteredProcesses: {
        if (filterText.trim().length === 0) return processes
        const needle = filterText.toLowerCase().trim()
        return processes.filter(p =>
            p.name.toLowerCase().includes(needle) ||
            String(p.pid).includes(needle) ||
            (p.user && p.user.toLowerCase().includes(needle))
        )
    }

    // ---- Process list polling ----
    Process {
        id: listProcess
        command: ["bash", Quickshell.shellDir + "/services/scripts/get_processes.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data)
                    root.processes = parsed
                } catch (e) {
                    console.warn("ProcessService: failed to parse process list JSON:", e)
                }
            }
        }
    }

    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: listProcess.running = true
    }

    // ---- Kill process ----
    // Keeps a small pool of one-shot Process objects so multiple kills
    // (e.g. rapid double right-click) don't clobber each other.
    property var _killProcesses: ({})

    function killProcess(pid) {
        if (pendingKillPids.includes(pid)) return // already killing this one

        pendingKillPids = pendingKillPids.concat([pid])

        const killer = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "${Quickshell.shellDir}/services/scripts/kill_process.sh", "${pid}"]
                stdout: SplitParser {
                    onRead: data => {}
                }
            }
        `, root, "killer_" + pid)

        killer.stdout.onRead.connect(function(data) {
            try {
                const result = JSON.parse(data)
                if (result.success) {
                    // Optimistically drop it from the list immediately;
                    // next poll cycle will confirm/reconcile.
                    root.processes = root.processes.filter(p => p.pid !== result.pid)
                } else {
                    console.warn("ProcessService: failed to kill pid", pid, result.error)
                }
            } catch (e) {
                console.warn("ProcessService: bad kill response for pid", pid, e)
            }
            root.pendingKillPids = root.pendingKillPids.filter(p => p !== pid)
            killer.destroy()
        })

        killer.running = true
    }

    // Force refresh on demand (e.g. after a kill, or a manual refresh button)
    function refresh() {
        listProcess.running = true
    }

    // Kill every PID in a group at once (e.g. all "code" or "brave" processes
    // belonging to one grouped app row). Each kill still goes through the
    // normal killProcess() path/dedup logic individually.
   function killGroup(pids) {
        if (!pids || typeof pids.length !== "number" || pids.length === 0) {
            console.warn("ProcessService: killGroup called with invalid pids:", pids)
            return
        }
        for (const pid of pids) {
            killProcess(pid)
        }
    }
}
