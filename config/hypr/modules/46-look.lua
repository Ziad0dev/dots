local util = require("lib.util")

local shader = util.state("shader")
if shader then
    hl.config({ decoration = { screen_shader = util.config_dir .. "/shaders/" .. shader .. ".glsl" } })
end

-- `dots-look glass on`: OrbitOS-style frosted windows. Rounder, borderless,
-- floating a little off each other, and a soft haze blur
-- that sees through windows to the ones behind (xray off; the bar and frame
-- keep their own xray in 71-layers.lua). Alphas: themectl's glass_* keys.
if util.state("glass") == "on" then
    hl.config({
        general = { gaps_in = 5, gaps_out = 10, border_size = 0 },
        decoration = {
            rounding       = 14,
            rounding_power = 2,   -- 2: round like the shell frame; Orbit's 3 reads almost square
            dim_inactive   = true,
            dim_strength   = 0.05,
            shadow = { enabled = true, range = 24, render_power = 3, color = "rgba(00000066)" },
            blur = {
                -- haze: a soft, foggy frost. Tried and dropped: acrylic's lens
                -- (bulb, refraction, colour fringes) bent the backdrop and read
                -- as odd; kawase let bright colours behind shine through too
                -- strongly; the base config's "frost" is a
                -- cracked-ice pattern, so the variant is set explicitly here
                variant    = "haze",
                haze       = { intensity = 0.35, iridescence = 0.7 },
                size       = 10,
                passes     = 3,
                xray       = false,
                -- Orbit darkens to 0.8; over a dark wallpaper and a 55% fill
                -- that reads as plain black, not glass, so keep full brightness
                brightness = 1.0,
                contrast   = 1.0,
                noise      = 0.03,
                -- no colour boost: vibrancy saturates what's behind the glass
                vibrancy   = 0.0,
            },
        },
    })
end

if util.state("blur") == "off" then
    hl.config({ decoration = { blur = { enabled = false } } })
end

-- `dots-look game on` (SUPER + CTRL + G): game mode. Everything on windows
-- that costs GPU time or gets in the way goes: animations, window blur,
-- see-through, shadows, rounding, gaps, inactive dim. Last, so it wins over
-- glass. Blur itself stays on: the bar, frame and panels are translucent and
-- read as broken without it, and theirs is cheap (xray, the cached wallpaper
-- blur, 71-layers.lua). dots-look also silences notifications while it's on.
if util.state("game") == "on" then
    hl.config({
        animations = { enabled = false },
        general    = { gaps_in = 0, gaps_out = 0 },
        decoration = {
            rounding     = 0,
            dim_inactive = false,
            shadow       = { enabled = false },
        },
    })
    hl.window_rule({
        name      = "game-mode",
        match     = { class = ".*" },
        no_blur   = true,
        opaque    = true,
        opacity   = "1.0 override 1.0 override 1.0 override",
        no_shadow = true,
    })
end
