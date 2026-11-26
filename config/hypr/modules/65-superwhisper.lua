-- Superwhisper writes its own shortcuts (hold Right Alt to dictate, by
-- default) and rewrites them when they change in its settings. This config
-- is read-only, so the home module points it at a state file instead
-- (services.superwhisper.hyprlandBindingsFile, flakes/superwhisper/module.nix).
-- Its default is used unless SUPERWHISPER_HYPR_BINDINGS says otherwise, and
-- the variable is exported so the settings window started from the launcher
-- writes to the same file rather than upstream's ~/.config/hypr/bindings.lua.
local path = os.getenv("SUPERWHISPER_HYPR_BINDINGS")
if not path or path == "" then
    local base = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    path = base .. "/superwhisper/hyprland.lua"
end
hl.env("SUPERWHISPER_HYPR_BINDINGS", path)
pcall(dofile, path)
