import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Run with: qs -p ~/.config/rice/Wallpaper-Switcher/
ShellRoot {
    Component.onCompleted: LweSettingsService.load()

    WallpaperSwitcherWindow {}
}
