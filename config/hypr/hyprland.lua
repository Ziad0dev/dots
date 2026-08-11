-- ╦ ╦╦ ╦╔═╗╦═╗╦  ╔═╗╔╗╔╔╦╗  ╔═╗╔═╗╔╗╔╔═╗╦╔═╗
-- ╠═╣╚╦╝╠═╝╠╦╝║  ╠═╣║║║ ║║  ║  ║ ║║║║╠╣ ║║ ╦
-- ╩ ╩ ╩ ╩  ╩╚═╩═╝╩ ╩╝╚╝═╩╝  ╚═╝╚═╝╝╚╝╚  ╩╚═╝
--
-- Hyprland 0.55+ Lua config — migrated from hyprland.conf (hyprlang).
-- Lives in ~/dots/hypr (symlinked to ~/.config/hypr via home.nix).
-- NOTE: while this file exists, hyprland.conf is IGNORED (checked once
-- at startup). Delete this file to fall back to hyprlang (0.55–0.56 only).

local colors = require("colors")

--------------------------------------------------------------------------
---- MONITORS
--------------------------------------------------------------------------
-- PERSISTENT HDR REMOVED. `hyprctl monitors` showed DP-1 sitting in
-- XBGR2101010 with colorManagementPreset: hdr at IDLE -- i.e. the 10-bit
-- colour-management pipeline was running every frame on the desktop, not only
-- for HDR content. cm_auto_hdr cannot switch away from it while bitdepth = 10
-- is pinned here. On NVIDIA that path is expensive: strace showed Hyprland
-- spending 73% of its time in DRM ioctls averaging ~977us per call, which is
-- what pegged one core at ~75% for an entire session.
--
-- To watch HDR content, re-add `bitdepth = 10` and `cm = "hdr"` plus the
-- luminance lines below, reload, and remove them afterwards.
hl.monitor({
    output   = "DP-1",
    mode     = "2560x1440@239.97",
    position = "0x0",
    scale    = 1,
    bitdepth = 10,
    cm       = "srgb",
    -- max_luminance     = 1000,
    -- max_avg_luminance = 300,
    -- sdr_min_luminance = 0,
    -- sdr_max_luminance = 200,
    -- sdrbrightness     = 1.7,
    -- sdrsaturation     = 1.0,
})

-- Secondary dropped 144 -> 60. This is a portrait 1080p panel for chat and
-- logs; every extra Hz on it is another pageflip through the same driver path
-- that is already the bottleneck. Raise it back if you miss it.
hl.monitor({output = "HDMI-A-1", mode = "1920x1080@60", position = "auto-right", scale = 1, transform = 3})
-- Auto-HDR: flip DP-1 into HDR only when a fullscreen surface actually signals
-- HDR content (mpv with target-colorspace-hint, or Proton with
-- PROTON_ENABLE_HDR). Desktop stays SDR otherwise, sidestepping the
-- too-bright-chrome bug. render:cm_fs_passthrough was REMOVED in 0.55 and
-- folded into this option.
-- Verify semantics on your build: hyprctl getoption render:cm_auto_hdr
-- direct_scanout lets a fullscreen surface bypass compositing entirely and go
-- straight to the display, which removes a frame of latency and a large slice
-- of the per-frame GPU/ioctl work. hyprctl monitors previously reported
-- `directScanoutBlockedBy: user settings` -- that was this option being off.
hl.config({ render = { cm_auto_hdr = 2, direct_scanout = true } })

-- Fallback for any other monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

--------------------------------------------------------------------------
---- ENVIRONMENT VARIABLES
--------------------------------------------------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "Breeze")

--------------------------------------------------------------------------
---- INPUT / CURSOR
--------------------------------------------------------------------------
hl.config({
    input = {
        kb_layout  = "us,se,ara,fr,de",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",

        follow_mouse  = 1,
        mouse_refocus = true,

        touchpad = {
            natural_scroll       = false,
            disable_while_typing = true,
            tap_to_click         = true,
            drag_lock            = true,
        },

        sensitivity   = 0,
        accel_profile = "flat",
    },

    cursor = {
        -- WAS: no_hardware_cursors = true. That forced software cursors on BOTH
        -- outputs (hyprctl monitors -> hardwareCursorsInUse: false), so every
        -- pointer move recomposited the whole 2560x1440 surface at 240 Hz.
        -- Measured cost: nvidia-smi dmon sm 10-34% just moving the mouse.
        -- On NVIDIA the HW cursor plane needs a CPU-mapped buffer, hence
        -- use_cpu_buffer. Verify after reload:
        --   hyprctl monitors | grep hardwareCursorsInUse   -> want true, true
        no_hardware_cursors = false,
        use_cpu_buffer      = true,
    },
})

--------------------------------------------------------------------------
---- GENERAL / DECORATION
--------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in     = 2,
        gaps_out    = 4,
        border_size = 1,

        -- Occult Blood Red — now actually driven by the palette
        col = {
            active_border   = { colors = { colors.color1, colors.color9 }, angle = 45 },
            inactive_border = colors.inactive_border,
        },

        layout = "dwindle",

        allow_tearing        = false,
        resize_on_border     = true,
        hover_icon_on_border = true,
    },

    decoration = {
        rounding = 8,

        active_opacity     = 1.0,
        inactive_opacity   = 0.95,
        fullscreen_opacity = 1.0,

        -- Blur (dual_kawase-ish, ported from picom days)
        blur = {
            enabled            = true,
            size               = 3,
            passes             = 2,   -- WAS 4. Passes are ~quadratic in cost at
                                      -- 1440p240; size 3 / passes 2 looks nearly
                                      -- identical to size 2 / passes 4.
            new_optimizations  = true,
            xray               = false,
            ignore_opacity     = true,
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
})

--------------------------------------------------------------------------
---- ANIMATIONS (144/240Hz-friendly)
--------------------------------------------------------------------------
hl.curve("wind",     { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05}  } })
hl.curve("winIn",    { type = "bezier", points = { {0.1, 1.1},  {0.1, 1.0}   } })
hl.curve("winOut",   { type = "bezier", points = { {0.3, -0.3}, {0, 1}       } })
hl.curve("linear",   { type = "bezier", points = { {0.0, 0.0},  {1.0, 1.0}   } })
hl.curve("slow",     { type = "bezier", points = { {0, 0.85},   {0.3, 1}     } })
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.1}   } })
hl.curve("bounce",   { type = "bezier", points = { {1, 1.6},    {0.1, 0.85}  } })
hl.curve("sligshot", { type = "bezier", points = { {1, -1},     {0.15, 1.25} } })
hl.curve("nice",     { type = "bezier", points = { {0, 1.9},    {0.5, -1.0} } })
-- Front-loaded curve: most of the travel happens in the first third, so the
-- motion reads as "already done" even though it is still settling.
hl.curve("snap",     { type = "bezier", points = { {0.2, 0.9},  {0.3, 1.0}   } })

-- Windows
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 2, bezier = "snap",  style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2, bezier = "snap",   style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "snap",   style = "slide" })

-- Fades
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2, bezier = "snap" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2, bezier = "snap" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1, bezier = "snap" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1, bezier = "snap" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 1, bezier = "snap" })

-- Border
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "linear" })
-- borderangle loop = continuous GPU redraw; enable knowingly
-- hl.animation({ leaf = "borderangle", enabled = true, speed = 120, bezier = "linear", style = "loop" })

-- Workspaces
hl.animation({ leaf = "workspaces",       enabled = true, speed = 2, bezier = "snap", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "snap", style = "slidevert" })

--------------------------------------------------------------------------
---- LAYOUTS / GESTURES / MISC
--------------------------------------------------------------------------
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
        -- WAS 2 (fullscreen-only). Both outputs still reported `vrr: false`, so
        -- it was never actually engaging -- just another thing for the driver
        -- to renegotiate. Set to 1 to try always-on once CPU is sane again.
        vrr                         = 0,
        animate_manual_resizes      = false,  -- WAS true: animates on every
        animate_mouse_windowdragging = false, -- pointer sample while dragging,
                                              -- which is exactly where the lag
                                              -- was most noticeable.
        enable_swallow              = true,
        swallow_regex               = "^(ghostty)$",
        focus_on_activate           = true,
        mouse_move_focuses_monitor  = true,
    },
})

--------------------------------------------------------------------------
---- KEYBINDINGS
--------------------------------------------------------------------------
local mainMod = "SUPER"

-- Terminal
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty"))

-- Kill focused window
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())

-- Program launchers
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd("rofi -show drun -show-icons"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("rofi -show run"))

-- Clipboard manager
hl.bind(mainMod .. " + SHIFT + C",
    hl.dsp.exec_cmd([[sh -c 'cliphist list | rofi -dmenu -p "clipboard" | cliphist decode | wl-copy']]))

-- Window focus (VI + arrow keys)
local focusDirs = { H = "left", L = "right", K = "up", J = "down",
                    left = "left", right = "right", up = "up", down = "down" }
for key, dir in pairs(focusDirs) do
    hl.bind(mainMod .. " + " .. key,              hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. key,      hl.dsp.window.move({ direction = dir }))
end

-- Fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Layout modes
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprctl keyword general:layout master"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("hyprctl keyword general:layout dwindle"))
hl.bind(mainMod .. " + E",
    hl.dsp.exec_cmd([[env PATH="$HOME/.local/bin:$PATH" bash ~/.config/rofi/scripts/wallpaper-switcher.sh]]))

-- Floating
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))
-- TODO(verify): old `focuscurrentorlast` — check `hyprctl configerrors` /
-- Dispatchers wiki for the exact lua name if this errors on press.
hl.bind(mainMod .. " + space", hl.dsp.focus({ window = "current_or_last" }))

-- Scratchpad (special workspace)
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + minus",         hl.dsp.workspace.toggle_special())

-- Workspaces 1-10: switch and move
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Workspace cycling
hl.bind(mainMod .. " + TAB",          hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + TAB",  hl.dsp.focus({ workspace = "e-1" }))

-- Mouse bindings
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Resize mode (i3-style submap)
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

-- Media keys
hl.bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd([[sh -c 'pactl set-sink-volume @DEFAULT_SINK@ +5% && notify-send "Volume" "$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP "\d+%" | head -1)"']]),
    { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd([[sh -c 'pactl set-sink-volume @DEFAULT_SINK@ -5% && notify-send "Volume" "$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP "\d+%" | head -1)"']]),
    { repeating = true, locked = true })
hl.bind("XF86AudioMute",
    hl.dsp.exec_cmd([[sh -c 'pactl set-sink-mute @DEFAULT_SINK@ toggle && notify-send "Volume" "Toggled"']]),
    { locked = true })

-- Screenshots (Wayland)
hl.bind("Print",
    hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | satty --filename - --fullscreen --output-filename ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png']]))
hl.bind(mainMod .. " + Print",
    hl.dsp.exec_cmd([[sh -c 'grim - | wl-copy && notify-send "Screenshot" "Full screen copied to clipboard"']]))

-- Exit/Lock/Reload
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + CTRL + L",  hl.dsp.exec_cmd("hyprlock"))

--------------------------------------------------------------------------
---- WINDOW RULES
--------------------------------------------------------------------------
-- Zathura. decoration.inactive_opacity is 0.95 globally, which is fine for
-- terminals and miserable for body text you're reading for an hour. The
-- override keyword makes these absolute rather than multiplicative.
hl.window_rule({
    name    = "zathura-readable",
    match   = { class = "^(org\\.pwmt\\.zathura)$" },
    opacity = "1.0 override 1.0 override 1.0 override",
    no_blur = true,
})

-- Separate call on purpose: if this effect key is wrong on your build, the
-- error pops a notification and the opacity rule above still applies.
hl.window_rule({
    match        = { class = "^(org\\.pwmt\\.zathura)$" },
    idle_inhibit = "fullscreen",
})

--------------------------------------------------------------------------
---- AUTOSTART
--------------------------------------------------------------------------
hl.on("hyprland.start", function()
    -- One shell, so these run IN ORDER. hl.exec_cmd is asynchronous, so
    -- issuing them as separate calls raced: the session target could start
    -- before the environment was imported, leaving services without
    -- WAYLAND_DISPLAY. Starting hyprland-session.target (defined in
    -- home.nix) is what finally activates graphical-session.target and with
    -- it udiskie, gsr-replay, and friends.
    hl.exec_cmd([[sh -c '
        dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
        systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
        systemctl --user start hyprland-session.target
        systemctl --user start hyprpolkitagent
    ']])
    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("awww-daemon")   -- restores cached wallpaper on start
    hl.exec_cmd("flameshot")
    hl.exec_cmd("gammastep")
end)

-- Tear the session down on exit so a re-login gets a clean target state.
hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)

--------------------------------------------------------------------------
---- LOCK + REPLAY BINDS
--------------------------------------------------------------------------
-- SUPER+L / SUPER+SHIFT+L are taken by vim-style focus/move, so Escape
-- carries the lock. Routing through loginctl means hypridle's guarded
-- lock_cmd runs (single instance + --grace 5) — same path before-sleep
-- and the idle timeout use, so all three behave identically.
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("loginctl lock-session"))

-- Save the last 5 minutes of the gsr-replay ring buffer
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(
    [[sh -c 'systemctl --user reload gsr-replay && notify-send -t 3000 "Replay saved" "last 5 min -> /data/replays"']]))
