for i = 1, 8 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1", default = (i == 1) })
end

hl.workspace_rule({ workspace = "10", monitor = "DP-1" })
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1", persistent = true, default = true })
