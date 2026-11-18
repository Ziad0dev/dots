-- Monitor profiles (exact mode, position, rotation, HDR calibration) belong
-- to one machine, so they stay out of this public repo: this loads them from
-- ~/.config/dots-local/hypr/monitors.lua, a file returning a list of
-- hl.monitor() tables. Outputs without a profile get their preferred mode,
-- placed automatically.
local profiles = {}
local ok, loaded = pcall(dofile, os.getenv("HOME") .. "/.config/dots-local/hypr/monitors.lua")
if ok and type(loaded) == "table" then
    profiles = loaded
end

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
