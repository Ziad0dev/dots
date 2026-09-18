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

for _, app in ipairs({ { "discord", "^(discord)$" }, { "spotify", "^(spotify)$" } }) do
    hl.window_rule({
        name      = app[1],
        match     = { class = app[2] },
        opacity   = "0.98",
        workspace = "10 silent",
    })
end

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
    workspace        = "9 silent",
    no_initial_focus = true,
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

hl.window_rule({
    name      = "qbittorrent-place",
    match     = { class = "^(org\\.qbittorrent\\.qBittorrent)$" },
    workspace = "3 silent",
})
