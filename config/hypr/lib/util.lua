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

return M
