-- Quickshell (rise) layer surfaces: the bar is "quickshell", every panel/popup is "dots-*".

-- Frost blur behind the bar island and pills. ignore_alpha sits under the pill fill (0.18)
-- so pills blur, but above shadow tails and the transparent rest of the bar strip.
-- xray: the bar and frame reserve their space, so only the wallpaper is ever behind them.
-- The bar is one fullscreen surface and Qt damages all of it on every redraw, so live
-- blur re-blurred the whole screen each frame (~40 W while media played); xray reuses
-- the cached wallpaper blur.
hl.layer_rule({
    name         = "rise-bar",
    match        = { namespace = "^quickshell$" },
    blur         = true,
    ignore_alpha = 0.12,
    xray         = true,
})

-- The frame and the melting panel backgrounds (FrameWindow): a fullscreen layer
-- under the bar. Same Frost blur as the bar band, from the cached wallpaper blur;
-- no open/close animation (it maps once per screen, under the bar).
hl.layer_rule({
    name         = "rise-frame",
    match        = { namespace = "^quickshell-frame$" },
    blur         = true,
    ignore_alpha = 0.12,
    xray         = true,
    no_anim      = true,
})

-- Panels animate their own reveal; a compositor fade/slide on top doubles the motion.
-- They are fullscreen surfaces, so ignore_alpha keeps blur to the card itself.
hl.layer_rule({
    name         = "rise-panels",
    match        = { namespace = "^dots-.*$" },
    blur         = true,
    blur_popups  = true,
    ignore_alpha = 0.12,
    no_anim      = true,
})

-- The click-away catcher is an invisible fullscreen layer: never blur or animate it.
hl.layer_rule({
    name    = "rise-dismiss",
    match   = { namespace = "^quickshell-popup-dismiss$" },
    no_anim = true,
})
