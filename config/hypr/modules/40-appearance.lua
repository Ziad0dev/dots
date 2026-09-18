local colors = require("colors")

hl.config({
    general = {
        gaps_in     = 2,
        gaps_out    = 4,
        border_size = 1,

        col = {
            active_border   = { colors = { colors.color0, colors.color1 }, angle = 45 },
            inactive_border = colors.inactive_border,
        },

        layout = "dwindle",

        allow_tearing        = false,
        resize_on_border     = true,
        hover_icon_on_border = true,
    },

    decoration = {
        rounding = 0,

        active_opacity   = 1.0,
        inactive_opacity = 1,

        shadow = { enabled = false },

        blur = {
            enabled            = true,
            variant            = "frost",
            size               = 8,
            passes             = 2,
            new_optimizations  = true,
            xray               = true,
            noise              = 0.015,
            contrast           = 1.0,
            brightness         = 1.0,
            vibrancy           = 0.25,
            vibrancy_darkness  = 0.0,
            popups             = true,
            popups_ignorealpha = 0.2,

            glass = {
                refraction = 8.0,
                size       = 96.0,
                roughness  = 0.45,
            },
        },
    },
})
