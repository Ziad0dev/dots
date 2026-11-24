-- Named scratchpads, after Caelestia's special workspaces: music, chat and
-- the system monitor each live on a special workspace of their own (window
-- rules in 70-rules.lua) and slide in over whatever you're doing with one
-- key, and away with the same key. A key whose app isn't running starts it.
-- SUPER + minus stays the plain scratchpad.
local util = require("lib.util")
local mod = util.mod

-- The app's windows anywhere, by exact class (get_windows matches classes
-- exactly, not as patterns).
local function windows_of(classes)
    for _, c in ipairs(classes) do
        local wins = hl.get_windows({ class = c })
        if wins and #wins > 0 then return wins end
    end
    return nil
end

-- Not running: start it onto its scratchpad. That placement is a rule on
-- this launch only (exec rules follow its child processes), so the same app
-- opened from the launcher or the dock shows up where you are, as usual.
-- Running elsewhere (opened normally, or dragged off): bring it over.
local function scratch(name, classes, cmd)
    local ws = "special:" .. name
    return function()
        local wins = windows_of(classes)
        if not wins then
            hl.exec_cmd(cmd, { workspace = ws .. " silent" })
        else
            for _, w in ipairs(wins) do
                if not (w.workspace and w.workspace.name == ws) then
                    hl.dispatch(hl.dsp.window.move({ workspace = ws, window = w, follow = false }))
                end
            end
        end
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
    end
end

-- Tauon's class differs between its Wayland and X11 windows
hl.bind(mod .. " + M", scratch("music",
    { "Tauon Music Box", "tauonmb", "tauon", "com.github.taiko2k.tauonmb" },
    "flatpak run com.github.taiko2k.tauonmb"))
hl.bind(mod .. " + CTRL + C", scratch("chat", { "discord" }, "discord"))
-- its own copy: the one on workspace 9 stays on the second monitor
hl.bind(mod .. " + CTRL + M", scratch("monitor", { "dev.dots.sysmon.pad" },
    util.sysmon_cmd("dev.dots.sysmon.pad", "sysmon-pad")))
