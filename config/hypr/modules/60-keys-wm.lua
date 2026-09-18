local util = require("lib.util")
local mod = util.mod

hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + space", hl.dsp.focus({ last = true }))

local dirs = { H = "left", L = "right", K = "up", J = "down",
               left = "left", right = "right", up = "up", down = "down" }
for key, dir in pairs(dirs) do
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mod .. " + minus",         hl.dsp.workspace.toggle_special())

hl.bind(mod .. " + G",         hl.dsp.group.toggle())
hl.bind(mod .. " + ALT + L",   hl.dsp.group.next())
hl.bind(mod .. " + ALT + H",   hl.dsp.group.prev())
hl.bind(mod .. " + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))
for key, dir in pairs({ H = "left", L = "right", K = "up", J = "down" }) do
    hl.bind(mod .. " + ALT + SHIFT + " .. key, hl.dsp.window.move({ into_or_create_group = dir }))
end

hl.bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local steps = { H = {-20, 0}, L = {20, 0}, K = {0, -20}, J = {0, 20},
                    left = {-20, 0}, right = {20, 0}, up = {0, -20}, down = {0, 20} }
    for key, d in pairs(steps) do
        hl.bind(key, hl.dsp.window.resize({ x = d[1], y = d[2] }), { repeating = true })
    end
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

hl.bind(mod .. " + CTRL + Z", function()
    hl.config({ cursor = { zoom_factor = (hl.get_config("cursor.zoom_factor") or 1) + 1 } })
end)
hl.bind(mod .. " + CTRL + ALT + Z", function()
    hl.config({ cursor = { zoom_factor = 1 } })
end)

hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mod .. " + CTRL + R",  hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + CTRL + L",  hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mod .. " + Escape",    hl.dsp.exec_cmd("loginctl lock-session"))
