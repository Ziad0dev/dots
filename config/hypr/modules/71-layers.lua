-- Quickshell (rise) layer surfaces: the bar is "quickshell", every panel/popup is "dots-*".

-- Frost blur behind the bar island and pills. ignore_alpha sits under the pill fill (0.18)
-- so pills blur, but above shadow tails and the transparent rest of the bar strip.
hl.layer_rule({
    name         = "rise-bar",
    match        = { namespace = "^quickshell$" },
    blur         = true,
    ignore_alpha = 0.12,
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
