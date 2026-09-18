import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "modules/taskmanager" as TaskManagerModule
import "root:/styles" as Styles

// shell.qml
// QuickShell entry point for the task manager. Wraps TaskManager.qml in a
// PanelWindow so it can float above niri's tiled layout like Windows 11's
// Task Manager does (Ctrl+Shift+Esc opens it as its own top-level window).
//
// HOW TO INVOKE:
//   1. Run standalone:      quickshell -c ~/.config/rice/task-manager
//   2. Bind a niri keybind to toggle it, e.g. in niri's config.kdl:
//        Ctrl+Shift+Escape { spawn "qs" "-c" "task-manager" "ipc" "call" "taskmanager" "toggle"; }
//      (adjust to however you invoke quickshell — `qs` alias, full path, etc.)
//
// This uses WlrLayershell-style PanelWindow so it floats independent of niri's
// tiling; if you'd rather it behave as a normal floating niri window instead
// of a layer-shell overlay, swap PanelWindow for a plain Window and let niri's
// window rules float it by app-id match instead.

ShellRoot {
    id: shellRoot

    // Exposed so a keybind script can do: qs ipc call taskmanager toggle
    IpcHandler {
        target: "taskmanager"

        function toggle() {
            panelWindow.visible = !panelWindow.visible
        }
        function show() {
            panelWindow.visible = true
        }
        function hide() {
            panelWindow.visible = false
        }
    }

    PanelWindow {
        id: panelWindow
        visible: false // starts hidden; toggle via IPC/keybind

        // Center-ish floating panel rather than edge-anchored, to feel like
        // a real window launching over your workspace
        anchors {
            top: true
            left: true
        }
        margins {
            top: 80
            left: 400
        }

        implicitWidth: Styles.Metrics.windowWidth
        implicitHeight: Styles.Metrics.windowHeight

        color: "transparent" // TaskManager.qml handles its own background + radius

        exclusiveZone: 0 // don't reserve screen space, just float over

        // Layer-shell surfaces don't get keyboard focus by default -- without
        // this, TextInput fields (like SearchBar.qml) render fine but never
        // receive key events.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        TaskManagerModule.TaskManager {
            anchors.fill: parent

            onCloseRequested: panelWindow.visible = false
            onMinimizeRequested: panelWindow.visible = false
        }
    }
}
