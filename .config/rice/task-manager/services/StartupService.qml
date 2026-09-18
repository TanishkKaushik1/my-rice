pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// StartupService.qml
// Singleton service. Lists XDG autostart entries via list_startup_apps.sh
// and provides setEnabled() to toggle them via toggle_startup_app.sh.
//
// Usage:
//   import "root:/services" as Services
//   Services.StartupService.apps            -> array of {id,name,comment,enabled,source}
//   Services.StartupService.setEnabled(id, true/false)

Item {
    id: root

    property var apps: []
    property int pollIntervalMs: 5000 // autostart entries change rarely, poll slowly

    Process {
        id: listProcess
        command: ["bash", Quickshell.shellDir + "/services/scripts/list_startup_apps.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.apps = JSON.parse(data)
                } catch (e) {
                    console.warn("StartupService: failed to parse startup apps JSON:", e)
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

    function refresh() {
        listProcess.running = true
    }

    function setEnabled(id, enabled) {
        const action = enabled ? "enable" : "disable"

        // Optimistic local update so the UI flips instantly
        root.apps = root.apps.map(a => a.id === id ? Object.assign({}, a, { enabled: enabled }) : a)

        const toggler = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "${Quickshell.shellDir}/services/scripts/toggle_startup_app.sh", "${id}", "${action}"]
                stdout: SplitParser { onRead: data => {} }
            }
        `, root, "toggler_" + id)

        toggler.stdout.onRead.connect(function(data) {
            try {
                const result = JSON.parse(data)
                if (!result.success) {
                    console.warn("StartupService: failed to toggle", id, result.error)
                    root.refresh() // revert optimistic update by re-reading real state
                }
            } catch (e) {
                console.warn("StartupService: bad toggle response for", id, e)
            }
            toggler.destroy()
        })

        toggler.running = true
    }
}
