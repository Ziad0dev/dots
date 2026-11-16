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
