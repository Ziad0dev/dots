local util = require("lib.util")
local mod = util.mod

-- the quickshell OSD reacts to the PipeWire change itself, so these only set state
hl.bind("XF86AudioRaiseVolume",
    util.sh([[pactl set-sink-volume @DEFAULT_SINK@ +5%]]),
    { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume",
    util.sh([[pactl set-sink-volume @DEFAULT_SINK@ -5%]]),
    { repeating = true, locked = true })
hl.bind("XF86AudioMute",
    util.sh([[pactl set-sink-mute @DEFAULT_SINK@ toggle]]),
    { locked = true })
hl.bind("XF86AudioMicMute",
    util.sh([[pactl set-source-mute @DEFAULT_SOURCE@ toggle]]),
    { locked = true })

hl.bind(mod .. " + S", function()
    local monitor = hl.get_active_monitor()
    local number = monitor and monitor.id or 0
    hl.exec_cmd("flameshot screen --number " .. number .. " --edit")
end)

-- dots-shot saves to ~/Pictures, copies, and notifies with Open / Edit (satty)
hl.bind("Print",                     hl.dsp.exec_cmd("dots-shot region"))
hl.bind(mod .. " + Print",           hl.dsp.exec_cmd("dots-shot screen"))
hl.bind(mod .. " + SHIFT + S",       hl.dsp.exec_cmd("dots-shot window"))

hl.bind(mod .. " + SHIFT + R",
    util.sh([[systemctl --user reload gsr-replay && notify-send -t 3000 "Replay saved" "last 5 min -> ~/Videos/Replays"]]))

hl.bind(mod .. " + ALT + R", util.sh([[if systemctl --user is-active --quiet gsr-replay; then
        systemctl --user stop gsr-replay
        notify-send -t 3000 "gsr-toggle" "replay buffer disarmed"
      else
        systemctl --user start gsr-replay
        notify-send -t 3000 "gsr-toggle" "replay buffer armed - 5 min rolling"
      fi]]))

-- media keys -> whichever MPRIS player is active (Helium, Zen, mpd, mpv...)
hl.bind("XF86AudioPlay",  util.sh([[playerctl play-pause]]), { locked = true })
hl.bind("XF86AudioPause", util.sh([[playerctl pause]]),      { locked = true })
hl.bind("XF86AudioNext",  util.sh([[playerctl next]]),       { locked = true })
hl.bind("XF86AudioPrev",  util.sh([[playerctl previous]]),   { locked = true })

-- copy a video/stream URL in the browser, then: play it in mpv / download it with yt-dlp
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("dots-media-clip play"))
hl.bind(mod .. " + SHIFT + Y", hl.dsp.exec_cmd("dots-media-clip download"))

-- mic denoise owner: EasyEffects (clean) <-> Discord's Krisp (discord), never both
hl.bind(mod .. " + ALT + D", hl.dsp.exec_cmd("dots-mic-mode toggle"))
