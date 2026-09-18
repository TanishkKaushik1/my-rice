---@module 'hl'

hl.layer_rule({ match = { namespace = "linux-wallpaperengine" }, blur = true })
hl.layer_rule({ match = { namespace = "linux-wallpaperengine" }, ignore_alpha = 0.1 })

hl.window_rule({ name  = "float_1", match = { title = "^(Wallpaper Switcher)$" }, float = true })
hl.window_rule({ name  = "float_1", match = { class = "^(io\\.github\\.airctl)$" }, float = true })
hl.window_rule({ name  = "float_1", match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({ name  = "float_1", match = { class = "^(xdg-desktop-portal.*)$" }, float = true })
hl.window_rule({ name  = "float_1", match = { title = "^(Choose what to share)$" }, float = true })
hl.window_rule({ name  = "border_size_0", match = { class = "^(airctl)$" }, border_size = 0 })
hl.window_rule({ name  = "tile_1", match = { class = "^(brave-browser)$" }, tile = true })