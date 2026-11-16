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

        repeat_rate        = 40,
        repeat_delay       = 250,
        numlock_by_default = true,

        sensitivity   = 0,
        accel_profile = "flat",
    },

    cursor = {
        no_hardware_cursors      = false,
        use_cpu_buffer           = true,
        hide_on_key_press        = true,
        warp_on_change_workspace = 1,
    },

    gestures = {
        workspace_swipe_distance           = 300,
        workspace_swipe_cancel_ratio       = 0.5,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_create_new         = true,
    },
})
