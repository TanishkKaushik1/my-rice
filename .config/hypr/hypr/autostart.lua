---@module 'hl'

hl.on("hyprland.start", function()
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("bash /home/tanishk/.config/rice/scripts/launch-bar.sh")
    hl.exec_cmd("bash /home/tanishk/.config/rice/scripts/game-watcher.sh")
    hl.exec_cmd("quickshell -c /home/tanishk/.config/rice/app-launcher")
    hl.exec_cmd("qs -p /home/tanishk/.config/rice/task-manager")
    hl.exec_cmd("bash /home/tanishk/.config/rice/Wallpaper-Switcher/restore-wallpaper.sh")
end)