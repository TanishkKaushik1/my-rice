---@module 'hl'

-- ── Monitors ─────────────────────────────────────────────────────────────
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- ── Environment Variables ────────────────────────────────────────────────
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XCURSOR_THEME", "catppuccin-mocha-mauve-cursors")
hl.env("XCURSOR_SIZE", 18)

-- ── Input ────────────────────────────────────────────────────────────────
hl.config({
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
        },
    },
})

-- ── Layout & Visuals ─────────────────────────────────────────────────────
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 4,
        border_size = 0,
        layout = "dwindle",
        col = {
            active_border = "rgb(ffc87f)",
            inactive_border = "rgb(505050)",
        },
    },
    misc = {
        vrr = 1,
        disable_hyprland_logo = true,
    },
    decoration = {
        rounding = 12,
        blur = {
            enabled = true,
            size = 3,
            passes = 2,
            vibrancy = 0.1696,
        },
        shadow = {
            enabled = true,
            range = 5,
            render_power = 3,
            color = "rgba(00000077)",
            offset = { 0, 5 },
        },
    },
})