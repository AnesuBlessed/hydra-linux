-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ◈ MONITORS & HDMI HOTPLUG CONFIGURATION

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Internal Laptop Screen (Primary)
hl.monitor({
    output = "eDP-1",
    disabled = false,
    mode = "1366x768@60.00",
    position = "0x0",
    scale = 1,
})

-- External HDMI Monitor / TV (Lock to stable 1080p @ 60Hz timing)
hl.monitor({
    output = "HDMI-A-1",
    disabled = false,
    mode = "1920x1080@60.00",
    position = "1366x0",
    scale = 1,
})

-- Fallback for any other external display / projector
hl.monitor({
    output = "",
    disabled = false,
    mode = "preferred",
    position = "auto",
    scale = 1,
})

-- Clamshell Mode: Turn off laptop screen when lid is closed
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor \"eDP-1, disable\""), {
    locked = true,
})
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor \"eDP-1, 1366x768@60.00, 0x0, 1\""), {
    locked = true,
})
