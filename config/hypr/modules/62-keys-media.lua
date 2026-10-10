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

hl.bind(mod .. " + S",               hl.dsp.exec_cmd("flameshot gui"))

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
