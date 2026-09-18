pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// StorageService.qml
// Singleton service. Polls get_storage_usage.sh for disk totals + a ranked
// list of space-consuming items (dirs, pacman packages, steam games), and
// provides deleteItem() to remove one via delete_storage_item.sh.
//
// Usage:
//   import "root:/services" as Services
//   Services.StorageService.disk          -> {total, used, free, mount}
//   Services.StorageService.items         -> array, sorted desc by size
//   Services.StorageService.deleteItem(item, callback)
//   Services.StorageService.refresh()

Item {
    id: root

    property var disk: ({ total: 0, used: 0, free: 0, mount: "/" })
    property var items: []
    property bool loading: false
    property int pollIntervalMs: 30000 // storage scans (du/pacman) are heavy -- poll slowly

    Process {
        id: scanProcess
        command: ["bash", Quickshell.shellDir + "/services/scripts/get_storage_usage.sh"]
        stdout: SplitParser {
            onRead: data => {
                root.loading = false
                try {
                    const parsed = JSON.parse(data)
                    root.disk = parsed.disk || root.disk
                    const list = parsed.items || []
                    list.sort((a, b) => b.size - a.size)
                    root.items = list
                } catch (e) {
                    console.warn("StorageService: failed to parse storage JSON:", e)
                }
            }
        }
    }

    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        root.loading = true
        scanProcess.running = true
    }

    // item: one entry from `items` ({id, name, size, type, path, deletable})
    // callback: function(success, error) -- optional
    function deleteItem(item, callback) {
        if (!item || !item.deletable) {
            if (callback) callback(false, "item is not deletable")
            return
        }

        // pacman deletes pass the package name (stored in `path` for that
        // type); everything else passes the filesystem path.
        const target = item.type === "pacman" ? item.name : item.path

        const deleter = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "${Quickshell.shellDir}/services/scripts/delete_storage_item.sh", "${item.type}", "${target}"]
                stdout: SplitParser { onRead: data => {} }
            }
        `, root, "storageDeleter_" + item.id)

        deleter.stdout.onRead.connect(function(data) {
            try {
                const result = JSON.parse(data)
                if (result.success) {
                    // Optimistically drop it from the list, then do a real
                    // rescan shortly after (du totals shift after a delete).
                    root.items = root.items.filter(i => i.id !== item.id)
                    if (callback) callback(true, null)
                    Qt.callLater(root.refresh)
                } else {
                    if (callback) callback(false, result.error || "unknown error")
                }
            } catch (e) {
                if (callback) callback(false, "bad response from delete script")
            }
            deleter.destroy()
        })

        deleter.running = true
    }
}
