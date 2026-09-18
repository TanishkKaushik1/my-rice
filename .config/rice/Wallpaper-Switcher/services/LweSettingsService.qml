pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // ── Settings state ────────────────────────────────────────────────────
    property int    volume:            50
    property bool   mute:              false
    property bool   automute:          true

    property string scaling:           "fill"
    property int    fps:               30
    property string screen:            "eDP-1"
    
    property bool   disableMouse:      false
    property bool   disableParallax:   false
    
    property bool   pauseOnFullscreen: true
    property bool   pauseOnlyActive:   false
    property string ignoreAppIds:      ""

    // ── Playlist & Custom Properties ──────────────────────────────────────
    property var    wallpapers:       []
    property int    currentIndex:     0
    
    // Format: { "3790573811": { "schemecolor": "0.819610 0.623530 0.568630", "xray": 1 } }
    property var    customProperties: ({}) 

    readonly property string currentWallpaper:
        (wallpapers && wallpapers.length > 0) ? wallpapers[currentIndex] : ""

   readonly property string settingsFile:
    Quickshell.env("HOME") + "/.config/rice/Wallpaper-Switcher/lwe_settings.json"

    property bool _loaded: false

    property var _loadProcess: Process {
        id: loadProcess
        property string _buffer: ""
        onStarted: _buffer = ""
        stdout: SplitParser {
            onRead: function(line) { loadProcess._buffer += line + "\n" }
        }
        onExited: function(code, _) {
            if (code !== 0 || loadProcess._buffer.trim() === "") {
                root._loaded = true
                return
            }
            try {
                var d = JSON.parse(loadProcess._buffer)
                if (d.volume            !== undefined) root.volume            = d.volume
                if (d.mute              !== undefined) root.mute              = d.mute
                if (d.automute          !== undefined) root.automute          = d.automute
                if (d.scaling           !== undefined) root.scaling           = d.scaling
                if (d.fps               !== undefined) root.fps               = d.fps
                if (d.screen            !== undefined) root.screen            = d.screen
                if (d.disableMouse      !== undefined) root.disableMouse      = d.disableMouse
                if (d.disableParallax   !== undefined) root.disableParallax   = d.disableParallax
                if (d.pauseOnFullscreen !== undefined) root.pauseOnFullscreen = d.pauseOnFullscreen
                if (d.pauseOnlyActive   !== undefined) root.pauseOnlyActive   = d.pauseOnlyActive
                if (d.ignoreAppIds      !== undefined) root.ignoreAppIds      = d.ignoreAppIds
                if (d.wallpapers        !== undefined) root.wallpapers        = d.wallpapers
                if (d.currentIndex      !== undefined) root.currentIndex      = d.currentIndex
                if (d.customProperties  !== undefined) root.customProperties  = d.customProperties
            } catch (e) {
                console.warn("LweSettingsService: failed to parse settings JSON:", e)
            }
            root._loaded = true
        }
    }

    property var _saveProcess: Process { id: saveProcess }

    function load() {
        loadProcess.command = ["bash", "-c", "cat \"" + settingsFile + "\" 2>/dev/null"]
        loadProcess.running = true
    }

    function save() {
        var obj = {
            volume:            root.volume,
            mute:              root.mute,
            automute:          root.automute,
            scaling:           root.scaling,
            fps:               root.fps,
            screen:            root.screen,
            disableMouse:      root.disableMouse,
            disableParallax:   root.disableParallax,
            pauseOnFullscreen: root.pauseOnFullscreen,
            pauseOnlyActive:   root.pauseOnlyActive,
            ignoreAppIds:      root.ignoreAppIds,
            wallpapers:        root.wallpapers,
            currentIndex:      root.currentIndex,
            customProperties:  root.customProperties
        }
        var json = JSON.stringify(obj, null, 2)
        var safe = json.replace(/'/g, "'\\''")
        saveProcess.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname '" + settingsFile + "')\" && " +
            "echo '" + safe + "' > \"" + settingsFile + "\""
        ]
        saveProcess.running = true
    }

    // ── Custom Properties API ─────────────────────────────────────────────
    function setCustomProperty(workshopId, propName, value) {
        if (!workshopId || workshopId === "") return
        
        var props = root.customProperties || {}
        if (!props[workshopId]) {
            props[workshopId] = {}
        }
        
        props[workshopId][propName] = value
        
        // Force QML to recognize the object change
        root.customProperties = Object.assign({}, props) 
        root.save()
    }

    function getCustomProperties(workshopId) {
        if (!workshopId || !root.customProperties) return {}
        return root.customProperties[workshopId] || {}
    }

    // ── Playlist API ──────────────────────────────────────────────────────
    function hasPlaylist() { return root.wallpapers && root.wallpapers.length > 1 }
    function next() {
        if (!root.wallpapers || root.wallpapers.length === 0) return
        root.currentIndex = (root.currentIndex + 1) % root.wallpapers.length
        root.save()
    }
    function previous() {
        if (!root.wallpapers || root.wallpapers.length === 0) return
        root.currentIndex = (root.currentIndex - 1 + root.wallpapers.length) % root.wallpapers.length
        root.save()
    }
    function setIndex(i) {
        if (!root.wallpapers || i < 0 || i >= root.wallpapers.length) return
        root.currentIndex = i
        root.save()
    }
    function addWallpaper(path) {
        var list = root.wallpapers ? root.wallpapers.slice() : []
        if (list.indexOf(path) === -1) {
            list.push(path); root.wallpapers = list; root.save()
        }
    }
    function removeWallpaper(path) {
        var list = root.wallpapers ? root.wallpapers.filter(function(w) { return w !== path }) : []
        root.wallpapers = list
        if (root.currentIndex >= list.length) root.currentIndex = Math.max(0, list.length - 1)
        root.save()
    }

    // ── Flag builder ──────────────────────────────────────────────────────
    function buildFlags(assetsDir, wallpaperPath, workshopId) {
        var wp = wallpaperPath || root.currentWallpaper
        // Attempt to extract workshop ID from path if not provided
        var wid = workshopId || (wp ? wp.split('/').pop() : "") 
        var flags = ""

        flags += "--assets-dir \"" + assetsDir + "\""
        if (root.screen !== "") flags += " --screen-root " + root.screen
        if (root.scaling !== "") flags += " --scaling " + root.scaling
        flags += " --fps " + root.fps

        if (root.mute || root.volume === 0) {
            flags += " --silent"
        } else {
            flags += " --volume " + root.volume
        }

        if (!root.automute)       flags += " --noautomute"
        if (root.disableMouse)    flags += " --disable-mouse"
        if (root.disableParallax) flags += " --disable-parallax"

        if (!root.pauseOnFullscreen) {
            flags += " --no-fullscreen-pause"
        } else {
            if (root.pauseOnlyActive) flags += " --fullscreen-pause-only-active"
            if (root.ignoreAppIds.trim() !== "") {
                var ids = root.ignoreAppIds.split(",")
                for (var i = 0; i < ids.length; i++) {
                    var id = ids[i].trim()
                    if (id !== "") flags += " --fullscreen-pause-ignore-appid " + id
                }
            }
        }

        // Inject custom properties for this specific wallpaper
        if (wid !== "" && root.customProperties && root.customProperties[wid]) {
            var props = root.customProperties[wid]
            for (var key in props) {
                flags += " --set-property \"" + key + "=" + props[key] + "\""
            }
        }

        if (wp !== "") {
            flags += " \"" + wp + "\"" 
        }
        return flags
    }
}