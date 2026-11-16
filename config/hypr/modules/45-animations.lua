local util = require("lib.util")

hl.config({ animations = { enabled = true } })

local preset = util.state("animation") or "snap"
local ok = pcall(dofile, util.config_dir .. "/animations/" .. preset .. ".lua")
if not ok then
    dofile(util.config_dir .. "/animations/snap.lua")
end
