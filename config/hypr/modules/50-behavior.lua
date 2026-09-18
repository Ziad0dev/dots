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

    binds = {
        hide_special_on_workspace_change = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    ecosystem = {
        no_update_news = true,
    },

    render = {
        direct_scanout = 0,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms  = true,
        key_press_enables_dpms   = true,

        vrr                          = 0,
        animate_manual_resizes       = false,
        animate_mouse_windowdragging = false,

        enable_swallow             = true,
        swallow_regex              = "^(com\\.mitchellh\\.ghostty)$",
        focus_on_activate          = true,
        mouse_move_focuses_monitor = true,

        allow_session_lock_restore = true,
        anr_missed_pings           = 3,
        initial_workspace_tracking = 0,
    },
})
