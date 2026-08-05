-- oxocarbon — base16 palette by shaunsingh/IBM
-- Consumed by hyprland.lua: colors.color1 / colors.color9 drive the active
-- border gradient, colors.inactive_border the unfocused one.
-- Keys kept identical to the previous Occult theme so nothing else changes.

return {
    background         = "rgb(161616)",   -- base00
    background_lighter = "rgb(262626)",   -- base01
    foreground         = "rgb(f2f4f8)",   -- base05

    -- Unfocused border: base02. Deliberately dim — on a WOLED a bright
    -- inactive border is the most static, highest-duty-cycle element on
    -- screen, which is exactly what you don't want burnt in.
    inactive_border    = "rgb(393939)",

    color0  = "rgb(161616)",  -- base00
    color1  = "rgb(ee5396)",  -- base0A pink   ← active border, stop 1
    color2  = "rgb(42be65)",  -- base0D green
    color3  = "rgb(ffe97b)",  -- IBM yellow (base16-oxocarbon defines none)
    color4  = "rgb(33b1ff)",  -- base0B blue
    color5  = "rgb(be95ff)",  -- base0E purple
    color6  = "rgb(3ddbd9)",  -- base08 cyan
    color7  = "rgb(dde1e6)",  -- base04
    color8  = "rgb(525252)",  -- base03
    color9  = "rgb(33b1ff)",  -- base0B blue   ← active border, stop 2
    color10 = "rgb(56d679)",
    color11 = "rgb(ffeb99)",
    color12 = "rgb(78a9ff)",  -- base09
    color13 = "rgb(d4bbff)",
    color14 = "rgb(08bdba)",  -- base07 teal
    color15 = "rgb(f2f4f8)",  -- base05
}
