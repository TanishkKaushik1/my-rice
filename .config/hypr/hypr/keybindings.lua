---@module 'hl'

local mainMod = "SUPER"

-- App Launchers
hl.bind(mainMod .. " + " .. "T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + " .. "D", hl.dsp.exec_cmd("fuzzel"))
hl.bind(mainMod .. " + " .. "Space", hl.dsp.exec_cmd("bash /home/tanishk/.config/rice/scripts/Launch-launcher.sh"))
hl.bind(mainMod .. " + " .. "W", hl.dsp.exec_cmd("bash /home/tanishk/.config/rice/scripts/toggle-wallpaper-switcher.sh"))
hl.bind(mainMod .. " + " .. "Return", hl.dsp.exec_cmd("qs -p /home/tanishk/.config/rice/task-manager ipc call taskmanager toggle"))

-- System Management
hl.bind(mainMod .. " + " .. "SHIFT" .. " + " .. "C", hl.dsp.exec_cmd("bash /home/tanishk/.config/rice/scripts/reload-ui.sh"))
hl.bind(mainMod .. " + " .. "ALT" .. " + " .. "L", hl.dsp.exec_cmd("hyprlock --config /home/tanishk/.config/rice/hyprlock/hyprlock.conf"))
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "S", hl.dsp.exec_cmd("bash /home/tanishk/.config/rice/scripts/toggle-record.sh"))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + " .. "E", hl.dsp.exit())
hl.bind("CTRL + ALT" .. " + " .. "Delete", hl.dsp.exit())

-- Window Management
hl.bind(mainMod .. " + " .. "Q", hl.dsp.window.close())
hl.bind(mainMod .. " + " .. "F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + " .. "SHIFT" .. " + " .. "F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + " .. "V", hl.dsp.window.float())

-- Focus Movement
hl.bind(mainMod .. " + " .. "left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + " .. "right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + " .. "up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + " .. "down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + " .. "H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + " .. "L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + " .. "K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + " .. "J", hl.dsp.focus({ direction = "down" }))

-- Window Movement
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. "J", hl.dsp.window.move({ direction = "down" }))

-- Workspace Switching & Moving
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + " .. "CTRL" .. " + " .. i, hl.dsp.window.move({ workspace = i }))
    hl.bind(mainMod .. " + " .. "SHIFT" .. " + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Workspace Navigation
hl.bind(mainMod .. " + " .. "Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + " .. "Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + " .. "U", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + " .. "I", hl.dsp.focus({ workspace = "e+1" }))

hl.bind(mainMod .. " + " .. "SHIFT" .. " + " .. "Page_Down", hl.dsp.window.move({ workspace = "e+1" }, { follow = false }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + " .. "Page_Up", hl.dsp.window.move({ workspace = "e-1" }, { follow = false }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + " .. "U", hl.dsp.window.move({ workspace = "e-1" }, { follow = false }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + " .. "I", hl.dsp.window.move({ workspace = "e+1" }, { follow = false }))

-- Mouse Workspace Switching
hl.bind(mainMod .. " + " .. "mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + " .. "mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Media & Hardware Keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl --class=backlight set +10%"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --class=backlight set 10%-"), { locked = true })

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd([[sh -c 'f="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"; grim -g "$(slurp)" "$f"; wl-copy -t image/png < "$f"']]))
hl.bind("CTRL + Print", hl.dsp.exec_cmd([[sh -c 'f="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"; grim "$f"; wl-copy -t image/png < "$f"']]))
hl.bind("ALT + Print", hl.dsp.exec_cmd([[sh -c 'f="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"; grim -g "$(hyprctl -j activewindow | jq -r "\"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])\"")" "$f"; wl-copy -t image/png < "$f"']]))

-- Mouse Bindings
hl.bind(mainMod .. " + " .. "mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + " .. "mouse:273", hl.dsp.window.resize(), { mouse = true })