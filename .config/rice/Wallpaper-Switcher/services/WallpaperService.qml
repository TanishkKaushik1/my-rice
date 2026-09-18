import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Public state ──────────────────────────────────────────────────────
    property ListModel wallpapers: ListModel {}
    property bool isApplying: false
    property string statusMessage: ""
    property string currentWallpaper: ""

    // ── Paths ─────────────────────────────────────────────────────────────
    readonly property string lweBinary:
        "/usr/bin/linux-wallpaperengine"
readonly property string workshopRoot:
    Quickshell.env("HOME") + "/.local/share/Steam/steamapps/workshop/content/431960"
readonly property string assetsDir:
    Quickshell.env("HOME") + "/.local/share/Steam/steamapps/common/wallpaper_engine/assets"
readonly property string lastWallpaperFile:
    Quickshell.env("HOME") + "/.config/rice/Wallpaper-Switcher/last_wallpaper.json"
readonly property string matugenConfig:
    Quickshell.env("HOME") + "/.config/rice/matugen/config.toml"

    property string _pendingPreviewPath: ""

    // ── Pending batch from scan ───────────────────────────────────────────
    property var _pendingBatch: []
    property int _batchOffset:  0

    // ── Process: scan ALL project.json files ──────────────────────────────
    property var _scanProcess: Process {
        id: scanProcess
        property string _buffer: ""
        onStarted: _buffer = ""
        stdout: SplitParser {
            onRead: function(line) { scanProcess._buffer += line + "\n" }
        }
        onExited: function(code, _) {
            if (code !== 0) {
                root.statusMessage = "Failed to read workshop folder"
                return
            }

            var lines   = scanProcess._buffer.split("\n")
            var entries = []
            var curPath = ""
            var curId   = ""

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (line.indexOf("FOLDER:") === 0) {
                    curPath = line.substring(7)
                    var parts = curPath.split("/")
                    curId = parts[parts.length - 1]
                } else if (line.indexOf("JSON:") === 0 && curPath !== "") {
                    entries.push({ id: curId, path: curPath, raw: line.substring(5) })
                    curPath = ""
                    curId   = ""
                }
            }

            var items = []
            for (var j = 0; j < entries.length; j++) {
                var e = entries[j]
                try {
                    var d     = JSON.parse(e.raw)
                    var title = d.title   || ("Workshop " + e.id)
                    var prev  = d.preview || ""
                    var type  = d.type    || "unknown"

                    var contentrating = d.contentrating || ""
                    var tags          = d.tags          || []
                    var isNsfw = (contentrating.toLowerCase() === "mature" ||
                                  contentrating.toLowerCase() === "questionable")

                    if (!isNsfw && Array.isArray(tags)) {
                        for (var k = 0; k < tags.length; k++) {
                            var t = String(tags[k]).toLowerCase()
                            if (t === "mature" || t === "nsfw" || t === "questionable") {
                                isNsfw = true; break
                            }
                        }
                    }

                    items.push({
                        workshopId:    e.id,
                        title:         title,
                        wallpaperType: type,
                        previewPath:   prev !== "" ? (e.path + "/" + prev) : "",
                        folderPath:    e.path,
                        isNsfw:        isNsfw
                    })
                } catch (err) {
                    items.push({
                        workshopId:    e.id,
                        title:         "Workshop " + e.id,
                        wallpaperType: "unknown",
                        previewPath:   "",
                        folderPath:    e.path,
                        isNsfw:        false
                    })
                }
            }

            root.wallpapers.clear()
            root._pendingBatch = items
            root._batchOffset  = 0
            root._appendChunk()
        }
    }

    function _appendChunk() {
        var batch = root._pendingBatch
        var start = root._batchOffset
        var end   = Math.min(start + 20, batch.length)

        for (var i = start; i < end; i++) {
            root.wallpapers.append(batch[i])
        }

        root._batchOffset = end

        if (end < batch.length) {
            Qt.callLater(root._appendChunk)
        } else {
            root._pendingBatch = []
            root.statusMessage = root.wallpapers.count > 0
                ? root.wallpapers.count + " wallpapers found"
                : "No wallpapers found"
            statusClearTimer.restart()
        }
    }

    // ── Process: apply wallpaper via lwe ──────────────────────────────────
    property var _applyProcess: Process {
        id: applyProcess
        property string _buffer: ""
        onStarted: _buffer = ""
        stdout: SplitParser { onRead: function(line) { applyProcess._buffer += line } }
        stderr: SplitParser { onRead: function(line) { applyProcess._buffer += line } }
        onExited: function(code, _) {
            root.isApplying = false
            if (applyProcess._buffer.indexOf("lwe-missing") !== -1) {
                root.statusMessage = "Error: linux-wallpaperengine not found"
                statusClearTimer.restart()
            } else if (applyProcess._buffer.indexOf("assets-missing") !== -1) {
                root.statusMessage = "Error: WE assets folder not found"
                statusClearTimer.restart()
            } else if (code === 0) {
                root.statusMessage = "Wallpaper applied ✓"
            } else {
                root.statusMessage = "Error (" + code + "): " + applyProcess._buffer.substring(0, 60)
                statusClearTimer.restart()
            }
        }
    }

    // ── Process: save last wallpaper ──────────────────────────────────────
    property var _saveProcess: Process { id: saveProcess }

    function _saveLastWallpaper(workshopId, wallpaperPath) {
        var json = JSON.stringify({ workshopId: workshopId, wallpaperPath: wallpaperPath })
        var safe = json.replace(/'/g, "'\\''")
        saveProcess.command = [
            "bash", "-c",
            "echo '" + safe + "' > \"" + root.lastWallpaperFile + "\""
        ]
        saveProcess.running = true
    }

    // ── Process: matugen ──────────────────────────────────────────────────
    property var _matugenProcess: Process {
        id: matugenProcess
        property string _buffer: ""
        onStarted: _buffer = ""
        stdout: SplitParser { onRead: function(line) { matugenProcess._buffer += line + "\n" } }
        stderr: SplitParser { onRead: function(line) { matugenProcess._buffer += line + "\n" } }
        onExited: function(code, _) {
            if (code === 0) {
                root.statusMessage = "Wallpaper applied ✓ — colors updated ✓"
              reloadProcess.command = [
                    "bash", "-c",
                    "nohup bash \"$HOME/.config/rice/scripts/reload-ui.sh\" >/dev/null 2>&1 &"
                ]
                reloadProcess.running = true
            }
            statusClearTimer.restart()
        }
    }

    // ── Process: reload UI colors ─────────────────────────────────────────
    property var _reloadProcess: Process { id: reloadProcess }

    // ── Process: kill and relaunch ────────────────────────────────────────
    property var _killProcess: Process {
        id: killProcess
        property string _requestedWallpaperPath: ""
        property string _requestedWallpaperId:   ""
        onExited: function(code, _) {
            var wp    = killProcess._requestedWallpaperPath || ""
            var wid   = killProcess._requestedWallpaperId || ""
            var adir  = root.assetsDir
            var lwe   = root.lweBinary
            var flags = LweSettingsService.buildFlags(adir, wp, wid)

            var cmd = "if [ ! -x \"" + lwe + "\" ] && ! command -v linux-wallpaperengine >/dev/null 2>&1; then\n"
                    + "  echo 'lwe-missing'; exit 2\n"
                    + "fi\n"
                    + "if [ ! -d \"" + adir + "\" ]; then\n"
                    + "  echo 'assets-missing'; exit 3\n"
                    + "fi\n"
                    + "export __GL_THREADED_OPTIMIZATIONS=0\n"
                    + "export __GL_YIELD=USLEEP\n"
                    + "if [ -x \"" + lwe + "\" ]; then\n"
                    + "  nohup \"" + lwe + "\" " + flags + " > /tmp/lwe.log 2>&1 &\n"
                    + "else\n"
                    + "  nohup linux-wallpaperengine " + flags + " > /tmp/lwe.log 2>&1 &\n"
                    + "fi\n"
                    + "disown -a\n"
                    + "exit 0\n"

            applyProcess._buffer = ""
            applyProcess.command = ["bash", "-c", cmd]
            applyProcess.running = true
        }
    }

    property Timer _statusClearTimer: Timer {
        id: statusClearTimer
        interval: 2500; repeat: false
        onTriggered: {
            root.statusMessage = ""
            root.isApplying = false 
        }
    }

    // ── Public API ────────────────────────────────────────────────────────
    function scanWallpapers() {
        wallpapers.clear()
        statusMessage = "Scanning…"

        var cmd =
            "find \"" + workshopRoot + "\" -maxdepth 2 -name 'project.json' | " +
            "sort | " +
            "while IFS= read -r f; do " +
            "  dir=$(dirname \"$f\"); " +
            "  echo \"FOLDER:$dir\"; " +
            "  printf 'JSON:%s\\n' \"$(tr -d '\\n\\r' < \"$f\")\"; " +
            "done"

        scanProcess.command = ["bash", "-c", cmd]
        scanProcess.running = true
    }

    function applyWallpaper(workshopId, wallpaperPath, previewPath) {
        isApplying           = true
        statusMessage        = "Applying…"
        currentWallpaper     = workshopId
        _pendingPreviewPath  = previewPath !== undefined ? previewPath : ""

        _saveLastWallpaper(workshopId, wallpaperPath)

        if (_pendingPreviewPath !== "") {
            matugenProcess._buffer = ""
            matugenProcess.command = [
                "bash", "-c",
                "\"$HOME/.local/bin/peachy-matugen.sh\" \"" +
                root._pendingPreviewPath + "\" \"" + root.matugenConfig + "\" 2>&1"
            ]
            matugenProcess.running = true
        }

        killProcess._requestedWallpaperPath = wallpaperPath
        killProcess._requestedWallpaperId   = workshopId
        killProcess.command = [
            "bash", "-lc",
            "pkill -f '[l]inux-wallpaperengine' 2>/dev/null; " +
            "i=0; " +
            "while pgrep -f '[l]inux-wallpaperengine' > /dev/null 2>&1 && [ $i -lt 15 ]; do " +
            "  sleep 0.1; i=$((i+1)); " +
            "done; " +
            "pkill -9 -f '[l]inux-wallpaperengine' 2>/dev/null || true"
        ]
        killProcess.running = true
    }
}