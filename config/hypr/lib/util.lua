local M = {}

M.mod = "SUPER"

function M.sh(script)
    return hl.dsp.exec_cmd("sh -c '" .. script .. "'")
end

function M.launch_or_focus(class, cmd)
    return function()
        local wins = hl.get_windows({ class = class })
        if wins and #wins > 0 then
            hl.dispatch(hl.dsp.focus({ window = wins[1] }))
        else
            hl.exec_cmd(cmd)
        end
    end
end

-- btop over nvtop in a tmux session, in a ghostty of the given class (the
-- rules place it: dev.dots.sysmon on workspace 9, the second monitor, at
-- autostart; dev.dots.sysmon.pad on the "monitor" scratchpad, SUPER + CTRL
-- + M). Each has its own session, so the two don't resize each other.
function M.sysmon_cmd(class, session)
    return string.format([[sh -c '
    tmux has-session -t %s 2>/dev/null || {
        tmux new-session -d -s %s -n sysmon "btop || exec fish"
        tmux split-window -v -t %s:sysmon "nvtop || exec fish"
    }
    exec ghostty --class=%s -e tmux new-session -A -s %s']], session, session, session, class, session)
end

M.config_dir = os.getenv("HOME") .. "/.config/hypr"
M.state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/dots/hypr"

function M.state(name)
    local ok, v = pcall(function()
        local f = io.open(M.state_dir .. "/" .. name, "r")
        if not f then return nil end
        local line = f:read("l")
        f:close()
        return line
    end)
    if not ok or v == nil or not v:match("^[%w_%-]+$") then return nil end
    return v
end

return M
