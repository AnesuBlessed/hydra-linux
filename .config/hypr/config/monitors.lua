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

-- Clamshell Mode: Handled via smart lid script (respects Turbo mode & external displays)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/lid_handler.sh close"), {
    locked = true,
})
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/lid_handler.sh open"), {
    locked = true,
})

