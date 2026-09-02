local colors = require("colors")

local monitorProfiles = {
    { output = "DP-1",     mode = "2560x1440@239.97", position = "0x0",        scale = 1,
      bitdepth = 10, cm = "hdr", supports_wide_color = 1,
      sdrbrightness = 1.0, sdrsaturation = 1.0,
      sdr_min_luminance = 0.0011, sdr_max_luminance = 350,
      min_luminance = 0.0011, max_luminance = 800, max_avg_luminance = 269 },
    { output = "HDMI-A-1", mode = "1920x1080@60",     position = "auto-right", scale = 1, transform = 3 },
}

local monitors = {}
for _, m in ipairs(monitorProfiles) do
    monitors[m.output] = m
    hl.monitor(m)
end

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

for i = 1, 8 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1", default = (i == 1) })
end
hl.workspace_rule({ workspace = "10", monitor = "DP-1" })
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1", persistent = true, default = true })

hl.env("XCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.config({
    input = {
        kb_layout  = "us,se,ara,fr,de",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:rctrl_toggle,compose:caps",
        kb_rules   = "",

        follow_mouse  = 1,
        mouse_refocus = true,

        touchpad = {
            natural_scroll       = false,
            disable_while_typing = true,
            tap_to_click         = true,
            drag_lock            = true,
        },

        repeat_rate   = 40,
        repeat_delay  = 250,
        numlock_by_default = true,

        sensitivity   = 0,
        accel_profile = "flat",
    },

    cursor = {

        no_hardware_cursors = false,
        use_cpu_buffer      = true,
        hide_on_key_press   = true,
        warp_on_change_workspace = 1,
    },

    binds = {
        hide_special_on_workspace_change = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    ecosystem = {
        no_update_news = true,
    },
})

hl.config({
    general = {
        gaps_in     = 2,
        gaps_out    = 4,
        border_size = 1,

        col = {
            active_border   = { colors = { colors.color0, colors.color1 }, angle = 45 },
            inactive_border = colors.inactive_border,
        },

        layout = "dwindle",

        allow_tearing        = false,
        resize_on_border     = true,
        hover_icon_on_border = true,
    },

    decoration = {
        rounding = 0,

        active_opacity     = 1.0,
        inactive_opacity   = 1,

        blur = {
            enabled            = true,
            size               = 3,
            passes             = 2,
            new_optimizations  = true,
            xray               = false,
            noise              = 0.02,
            contrast           = 1.0,
            brightness         = 1.0,
            vibrancy           = 0.25,
            vibrancy_darkness  = 0.0,
            popups             = true,
            popups_ignorealpha = 0.2,
        },
    },

    animations = { enabled = true },
    render = { direct_scanout = 1 },
})

hl.curve("linear",   { type = "bezier", points = { {0.0, 0.0},  {1.0, 1.0}   } })

hl.curve("snap",     { type = "bezier", points = { {0.2, 0.9},  {0.3, 1.0}   } })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 2, bezier = "snap",  style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2, bezier = "snap",   style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "snap",   style = "slide" })

hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2, bezier = "snap" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2, bezier = "snap" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1, bezier = "snap" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1, bezier = "snap" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 1, bezier = "snap" })

hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "linear" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 2, bezier = "snap", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "snap", style = "slidevert" })

hl.config({
    dwindle = {
        preserve_split = true,
        smart_split    = false,
        smart_resizing = true,
        force_split    = 2,
    },

    master = {
        mfact = 0.5,
    },

    gestures = {
        workspace_swipe_distance           = 300,
        workspace_swipe_cancel_ratio       = 0.5,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_create_new         = true,
    },

    misc = {
        disable_hyprland_logo       = true,
        disable_splash_rendering    = true,
        mouse_move_enables_dpms     = true,
        key_press_enables_dpms      = true,

        vrr                         = 0,
        animate_manual_resizes      = false,
        animate_mouse_windowdragging = false,

        enable_swallow              = true,
        swallow_regex               = "^(com\\.mitchellh\\.ghostty)$",
        focus_on_activate           = true,
        mouse_move_focuses_monitor  = true,

        allow_session_lock_restore  = true,
        anr_missed_pings            = 3,
        initial_workspace_tracking  = 0,
    },
})

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("ghostty -e tmux new-session -A -s main"))

hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs -c rise ipc call launcher toggle"))
local focusDirs = { H = "left", L = "right", K = "up", J = "down",
                    left = "left", right = "right", up = "up", down = "down" }
for key, dir in pairs(focusDirs) do
    hl.bind(mainMod .. " + " .. key,              hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. key,      hl.dsp.window.move({ direction = dir }))
end
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("voxtype toggle"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd([[sh -c 'cliphist list | fuzzel --dmenu | cliphist decode | wl-copy']]))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("bemoji -n -t"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("qs -c rise ipc call picker theme"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("themectl next"))
hl.bind(mainMod .. " + CTRL + E",  hl.dsp.exec_cmd("themectl bg next"))
hl.bind(mainMod .. " + E",
    hl.dsp.exec_cmd([[qs -c rise ipc call picker wallpaper]]))
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))

hl.bind(mainMod .. " + space", hl.dsp.focus({ window = "current_or_last" }))

hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + minus",         hl.dsp.workspace.toggle_special())

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + TAB",          hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + TAB",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + Z", function()
    hl.config({ cursor = { zoom_factor = (hl.get_config("cursor.zoom_factor") or 1) + 1 } })
end)

hl.bind(mainMod .. " + CTRL + ALT + Z", function()
    hl.config({ cursor = { zoom_factor = 1 } })
end)
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local resizeDirs = { H = {-20, 0}, L = {20, 0}, K = {0, -20}, J = {0, 20},
                         left = {-20, 0}, right = {20, 0}, up = {0, -20}, down = {0, 20} }
    for key, d in pairs(resizeDirs) do
        hl.bind(key, hl.dsp.window.resize({ x = d[1], y = d[2] }), { repeating = true })
    end
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

hl.bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd([[sh -c 'pactl set-sink-volume @DEFAULT_SINK@ +5% && notify-send "Volume" "$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP "\d+%" | head -1)"']]),
    { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd([[sh -c 'pactl set-sink-volume @DEFAULT_SINK@ -5% && notify-send "Volume" "$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP "\d+%" | head -1)"']]),
    { repeating = true, locked = true })
hl.bind("XF86AudioMute",
    hl.dsp.exec_cmd([[sh -c 'pactl set-sink-mute @DEFAULT_SINK@ toggle && notify-send "Volume" "Toggled"']]),
    { locked = true })

hl.bind("Print",
    hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | satty --filename - --fullscreen --output-filename ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png']]))
hl.bind(mainMod .. " + Print",
    hl.dsp.exec_cmd([[sh -c 'grim - | wl-copy && notify-send "Screenshot" "Full screen copied to clipboard"']]))

hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + CTRL + L",  hl.dsp.exec_cmd("quickshell -c lock"))

hl.window_rule({
    name   = "dots-float-lg",
    match  = { class = "^(com\\.dots\\.float\\.lg)$" },
    float  = true,
    size   = {1200, 750},
    center = true,
})

hl.window_rule({
    name   = "dots-float-md",
    match  = { class = "^(com\\.dots\\.float\\.md)$" },
    float  = true,
    size   = {1100, 700},
    center = true,
})

hl.window_rule({
    name   = "dots-float-sm",
    match  = { class = "^(com\\.dots\\.float\\.sm)$" },
    float  = true,
    size   = {900, 600},
    center = true,
})

hl.window_rule({
    name   = "dots-float-term",
    match  = { class = "^(com\\.dots\\.float)$" },
    float  = true,
    size   = {1200, 750},
    center = true,
})

hl.window_rule({
    name    = "zathura-readable",
    match   = { class = "^(org\\.pwmt\\.zathura)$" },
    opacity = "1.0 override 1.0 override 1.0 override",
    no_blur = true,
})

hl.window_rule({
    match        = { class = "^(org\\.pwmt\\.zathura)$" },
    idle_inhibit = "fullscreen",
})
hl.window_rule({
    name  = "sysmon-place",
    match = { class = "^(dev\\.dots\\.sysmon)$" },
    workspace = "9 silent",
})

hl.window_rule({
    match = { class = "^(dev\\.dots\\.sysmon)$" },
    no_initial_focus = true,
})

hl.window_rule({
    name  = "zen",
    match = { class = "^(zen-beta)$" },
    workspace = "1",
})

hl.window_rule({
    name  = "sideterm",
    match = { class = "^(dev\\.dots\\.sideterm)$" },
    workspace = "1 silent",
})

hl.window_rule({
    name  = "discord",
    match = { class = "^(discord)$" },
    workspace = "10 silent",
})

hl.window_rule({
    name  = "spotify",
    match = { class = "^(spotify)$" },
    workspace = "10 silent",
})

hl.window_rule({
    name  = "qbittorrent-place",
    match = { class = "^(org\\.qbittorrent\\.qBittorrent)$" },
    workspace = "3 silent",
})

hl.on("hyprland.start", function()

    hl.exec_cmd([[sh -c '
        dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE NIXOS_OZONE_WL MOZ_ENABLE_WAYLAND QT_QPA_PLATFORM
        systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE NIXOS_OZONE_WL MOZ_ENABLE_WAYLAND QT_QPA_PLATFORM
        systemctl --user start hyprland-session.target
        systemctl --user start hyprpolkitagent
    ']])
    hl.exec_cmd("dunst")
    hl.exec_cmd("awww-daemon")

    hl.exec_cmd("zen-beta")
    hl.exec_cmd([[sh -c 'sleep 2; ghostty --class=dev.dots.sideterm']])
    hl.exec_cmd([[sh -c '
        tmux has-session -t sysmon 2>/dev/null || {
            tmux new-session -d -s sysmon -n sysmon "btop || exec fish"
            tmux split-window -v -t sysmon:sysmon "nvtop || exec fish"
        }
        ghostty --class=dev.dots.sysmon -e tmux new-session -A -s sysmon']])
    hl.exec_cmd("discord")
    hl.exec_cmd("spotify")
    hl.exec_cmd("easyeffects --gapplication-service")
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)

hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("loginctl lock-session"))

hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(
    [[sh -c 'systemctl --user reload gsr-replay && notify-send -t 3000 "Replay saved" "last 5 min -> /data/replays"']]))

hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd(
    [[sh -c 'if systemctl --user is-active --quiet gsr-replay; then
        systemctl --user stop gsr-replay
        notify-send -t 3000 "gsr-toggle" "replay buffer disarmed"
      else
        systemctl --user start gsr-replay
        notify-send -t 3000 "gsr-toggle" "replay buffer armed - 5 min rolling"
      fi']]))

pcall(dofile, os.getenv("HOME") .. "/.local/state/dots/theme/hyprland.lua")


local function reapply_monitors()
    for _, m in ipairs(hl.get_monitors()) do
        local profile = monitors[m.name]
        if profile then
            hl.monitor(profile)
        else
            hl.monitor({ output = m.name, mode = "preferred", position = "auto", scale = "auto" })
        end
    end
end

hl.on("monitor.added", function(m)
    reapply_monitors()
    hl.notification.create({ text = "Monitor connected: " .. m.name, timeout = 3000, icon = "ok" })
end)

hl.on("monitor.removed", function(m)
    hl.notification.create({ text = "Monitor disconnected: " .. m.name, timeout = 3000, icon = "hint" })
end)

local function launch_or_focus(class, cmd)
    return function()
        local wins = hl.get_windows({ class = class })
        if wins and #wins > 0 then
            hl.dispatch(hl.dsp.focus({ window = wins[1].address }))
        else
            hl.exec_cmd(cmd)
        end
    end
end

hl.bind(mainMod .. " + B", launch_or_focus("zen-beta", "zen-beta"))
hl.bind(mainMod .. " + O", launch_or_focus("obsidian", "obsidian"))
hl.bind(mainMod .. " + C", launch_or_focus("discord",  "discord"))

hl.bind(mainMod .. " + G",           hl.dsp.group.toggle())
hl.bind(mainMod .. " + ALT + L",     hl.dsp.group.next())
hl.bind(mainMod .. " + ALT + H",     hl.dsp.group.prev())
hl.bind(mainMod .. " + SHIFT + G",   hl.dsp.window.move({ out_of_group = true }))
for _, d in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + ALT + SHIFT + " .. d:sub(1, 1):upper(),
            hl.dsp.window.move({ into_or_create_group = d }))
end

hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("dots-nightlight toggle"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs -c rise ipc call overview toggle"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("qs -c rise ipc call openrouter toggle"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("flameshot gui"))
