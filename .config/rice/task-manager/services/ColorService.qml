pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ColorService.qml
// Singleton service. Reads the matugen-generated colors.json and exposes each
// color role as a bindable property. Watches the file so that when matugen
// regenerates it (e.g. wallpaper change -> matugen apply), the whole UI
// re-themes live without restarting QuickShell.
//
// Expects the JSON shape produced by matugen/templates/colors.json, e.g.:
// { "colors": { "surface": "#1a1110", "on_surface": "#fff2f0", ... } }
//
// Usage:
//   import "root:/services" as Services
//   color: Services.ColorService.primary

Item {
    id: root

    // Path to matugen's OUTPUT file (not the template). Matches config.toml's
    // templates.quickshell_colors.output_path.
    readonly property string colorsFilePath: Quickshell.env("HOME") + "/.config/rice/matugen/colors.json"

    // ---- Color roles (sensible fallbacks match your current colors.json,
    //      so the UI still looks correct even before matugen has run once) ----
    property color surface: "#1a1110"
    property color onSurfaceColor: "#fff2f0"
    property color primary: "#F54A47"
    property color secondary: "#e7bdb7"
    property color tertiary: "#dfc38c"
    property color error: "#F54A47"
    property color surfaceContainer: "#2c2221"
    property color primaryContainer: "#aa6056"

    property bool loaded: false

    FileView {
        id: colorsFile
        path: root.colorsFilePath
        watchChanges: true

        onFileChanged: reload() // matugen wrote a new file -> re-read it
        onLoaded: _parse(text())
        onLoadFailed: error => {
            console.warn("ColorService: failed to load", root.colorsFilePath, error)
        }
    }

    function _parse(jsonText) {
        try {
            const parsed = JSON.parse(jsonText)
            const c = parsed.colors || parsed // tolerate either shape

            root.surface = c.surface || root.surface
            root.onSurfaceColor = c.on_surface || root.onSurfaceColor
            root.primary = c.primary || root.primary
            root.secondary = c.secondary || root.secondary
            root.tertiary = c.tertiary || root.tertiary
            root.error = c.error || root.error
            root.surfaceContainer = c.surface_container || root.surfaceContainer
            root.primaryContainer = c.primary_container || root.primaryContainer

            root.loaded = true
        } catch (e) {
            console.warn("ColorService: bad JSON in", root.colorsFilePath, e)
        }
    }

    // Manual re-read, e.g. wired to a "refresh theme" keybind/button
    function reload() {
        colorsFile.reload()
    }
}
