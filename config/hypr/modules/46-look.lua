local util = require("lib.util")

local shader = util.state("shader")
if shader then
    hl.config({ decoration = { screen_shader = util.config_dir .. "/shaders/" .. shader .. ".glsl" } })
end

if util.state("blur") == "off" then
    hl.config({ decoration = { blur = { enabled = false } } })
end
