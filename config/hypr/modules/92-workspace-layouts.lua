-- Per-workspace layouts (lib/workspace_modes.lua): restore the saved choices.
-- After 40-appearance, whose general.layout would otherwise win over a saved
-- default. Global so `dots-layout` reaches it through `hyprctl eval`.
dots_workspace_modes = require("lib.workspace_modes")
dots_workspace_modes.load()
