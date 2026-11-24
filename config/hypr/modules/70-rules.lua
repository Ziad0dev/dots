local floats = {
    { name = "dots-float-lg",   class = "^(com\\.dots\\.float\\.lg)$", size = {1200, 750} },
    { name = "dots-float-md",   class = "^(com\\.dots\\.float\\.md)$", size = {1100, 700} },
    { name = "dots-float-sm",   class = "^(com\\.dots\\.float\\.sm)$", size = {900, 600} },
    { name = "dots-float-term", class = "^(com\\.dots\\.float)$",      size = {1200, 750} },
}

for _, f in ipairs(floats) do
    hl.window_rule({
        name   = f.name,
        match  = { class = f.class },
        float  = true,
        size   = f.size,
        center = true,
    })
end

hl.window_rule({
    name  = "flameshot",
    match = { class = "^(flameshot)$" },
    float = true,
    pin   = true,
})

hl.window_rule({
    name  = "satty",
    match = { class = "^(com.gabm.satty)$" },
    float = true,
})

-- Discord flickers under blur/opacity effects: keep it fully opaque and
-- exempt from blur, inactive dim and shadow (incl. `dots-look glass on`)
hl.window_rule({
    name      = "discord",
    match     = { class = "^(discord)$" },
    opacity   = "1.0 override 1.0 override 1.0 override",
    opaque    = true,
    no_blur   = true,
    no_dim    = true,
    no_shadow = true,
})

hl.window_rule({
    name         = "zathura",
    match        = { class = "^(org\\.pwmt\\.zathura)$" },
    opacity      = "1.0 override 1.0 override 1.0 override",
    no_blur      = true,
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name             = "sysmon",
    match            = { class = "^(dev\\.dots\\.sysmon)$" },
    -- workspace 9 is the second monitor's (20-workspaces.lua)
    workspace        = "9 silent",
    no_initial_focus = true,
})

-- the scratchpad's own copy (SUPER + CTRL + M, 64-keys-scratch.lua; only
-- that key starts this class). Discord and Tauon get their scratchpads from
-- the launch itself (autostart, the scratch keys), not from a rule, so
-- opening them normally doesn't hide them away.
hl.window_rule({
    name      = "sysmon-pad",
    match     = { class = "^(dev\\.dots\\.sysmon\\.pad)$" },
    workspace = "special:monitor silent",
})

hl.window_rule({
    name      = "zen",
    match     = { class = "^(zen-beta)$" },
    workspace = "1",
})

hl.window_rule({
    name      = "sideterm",
    match     = { class = "^(dev\\.dots\\.sideterm)$" },
    workspace = "1 silent",
})


-- Helium/Chromium video Picture-in-Picture: small, pinned over every workspace,
-- bottom-right, aspect-locked, and it must not steal focus from what you're doing
hl.window_rule({
    name              = "helium-pip",
    match             = { class = "^(helium)$", title = "^(Picture in picture)$" },
    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
    size              = {480, 270},
    move              = "100%-w-24 100%-h-24",
    no_initial_focus  = true,
})

-- Rise's settings app (Nexus.qml): a centred floating window, not a tile
hl.window_rule({
    name   = "rise-settings",
    match  = { class = "^org\\.quickshell$", title = "^Settings$" },
    float  = true,
    size   = "1000 700",
    center = true,
})
