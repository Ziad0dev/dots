local SESSION_VARS = "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE NIXOS_OZONE_WL MOZ_ENABLE_WAYLAND QT_QPA_PLATFORM"

hl.on("hyprland.start", function()
    hl.exec_cmd(string.format(
        "sh -c '\n" ..
        "dbus-update-activation-environment --systemd %s\n" ..
        "systemctl --user import-environment %s\n" ..
        "systemctl --user stop xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr xdg-desktop-portal-hyprland\n" ..
        "systemctl --user start hyprland-session.target\n" ..
        "systemctl --user start hyprpolkitagent\n'",
        SESSION_VARS, SESSION_VARS))

    hl.exec_cmd("dunst")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("easyeffects --gapplication-service")

    hl.exec_cmd("zen-beta")
    hl.exec_cmd("discord")
    hl.exec_cmd("spotify")

    hl.exec_cmd([[sh -c 'sleep 2; ghostty --class=dev.dots.sideterm']])
    hl.exec_cmd([[sh -c '
        tmux has-session -t sysmon 2>/dev/null || {
            tmux new-session -d -s sysmon -n sysmon "btop || exec fish"
            tmux split-window -v -t sysmon:sysmon "nvtop || exec fish"
        }
        ghostty --class=dev.dots.sysmon -e tmux new-session -A -s sysmon']])
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)
