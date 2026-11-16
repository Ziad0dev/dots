local profiles = {
    { output = "DP-1",     mode = "2560x1440@239.97", position = "0x0",        scale = 1,
      bitdepth = 10, cm = "hdr", supports_wide_color = 1,
      supports_hdr = 1, sdrsaturation = 1, sdrbrightness = 1.0,
      sdr_min_luminance = 0.0011, sdr_max_luminance = 350,
      min_luminance = 0.0011, max_luminance = 800, max_avg_luminance = 269 },
    { output = "HDMI-A-1", mode = "1920x1080@60",     position = "auto-right", scale = 1, transform = 3 },
}

local byOutput = {}
for _, m in ipairs(profiles) do
    byOutput[m.output] = m
    hl.monitor(m)
end

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

local function reapply()
    for _, m in ipairs(hl.get_monitors()) do
        local profile = byOutput[m.name]
        if profile then
            hl.monitor(profile)
        else
            hl.monitor({ output = m.name, mode = "preferred", position = "auto", scale = "auto" })
        end
    end
end

hl.on("monitor.added", function(m)
    reapply()
    hl.notification.create({ text = "Monitor connected: " .. m.name, timeout = 3000, icon = "ok" })
end)

hl.on("monitor.removed", function(m)
    hl.notification.create({ text = "Monitor disconnected: " .. m.name, timeout = 3000, icon = "hint" })
end)
