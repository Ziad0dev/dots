local util = require("lib.util")

local SESSION_VARS = "WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE NIXOS_OZONE_WL MOZ_ENABLE_WAYLAND QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME GDK_BACKEND CLUTTER_BACKEND XCURSOR_SIZE"

hl.on("hyprland.start", function()
    hl.exec_cmd(string.format(
        "sh -c '\n" ..
        "dbus-update-activation-environment --systemd %s\n" ..
        "systemctl --user import-environment %s\n" ..
        "systemctl --user stop xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr xdg-desktop-portal-hyprland\n" ..
        "systemctl --user start hyprland-session.target\n'",
        SESSION_VARS, SESSION_VARS))

    -- icons, cursor and fonts (Themes → App style): the cursor needs
    -- Hyprland up, and home-manager's dconf may have reset the rest
    hl.exec_cmd("dots-appearance apply --quiet")
    hl.exec_cmd("awww-daemon --no-cache")

    hl.exec_cmd("zen-beta")
    -- on its "chat" scratchpad (SUPER + CTRL + C), out of the way
    hl.exec_cmd("discord", { workspace = "special:chat silent" })

    hl.exec_cmd([[sh -c 'sleep 2; ghostty --class=dev.dots.sideterm']])
    hl.exec_cmd(util.sysmon_cmd("dev.dots.sysmon", "sysmon"))
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)
