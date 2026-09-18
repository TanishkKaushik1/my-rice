---@module 'hl'

hl.config({
    animations = {
        enabled = true,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Snappy, responsive curves
hl.curve("snappy", {
    type = "bezier",
    points = { { 0.1, 1.0 }, { 0.1, 1.0 } },
})

hl.curve("snappyBounce", {
    type = "bezier",
    points = { { 0.1, 1.1 }, { 0.1, 1.0 } },
})

-- Lower speed values (3-4 instead of 5-8) for much faster transitions
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "snappyBounce", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "snappy", style = "popin 85%" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "snappy" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "snappy", style = "slidefade 20%" })