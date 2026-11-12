local util = require("lib.util")

local shader = util.state("shader")
if shader then
    hl.config({ decoration = { screen_shader = util.config_dir .. "/shaders/" .. shader .. ".glsl" } })
end

-- `dots-look glass on`: OrbitOS-style frosted windows. Rounder, borderless,
-- floating a little off each other, and a heavier, darker, grainier blur
-- that sees through windows to the ones behind (xray off; the bar and frame
-- keep their own xray in 71-layers.lua). Alphas: themectl's glass_* keys.
if util.state("glass") == "on" then
    hl.config({
        general = { gaps_in = 5, gaps_out = 10, border_size = 0 },
        decoration = {
            rounding       = 14,
            rounding_power = 3,
            dim_inactive   = true,
            dim_strength   = 0.05,
            shadow = { enabled = true, range = 24, render_power = 3, color = "rgba(00000066)" },
            blur = {
                size       = 10,
                passes     = 3,
                xray       = false,
                brightness = 0.8,
                contrast   = 1.0,
                noise      = 0.05,
                vibrancy   = 0.1,
            },
        },
    })
end

if util.state("blur") == "off" then
    hl.config({ decoration = { blur = { enabled = false } } })
end
