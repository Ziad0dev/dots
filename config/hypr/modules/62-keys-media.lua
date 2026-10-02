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

hl.bind(mod .. " + S", hl.dsp.exec_cmd("flameshot gui"))
hl.bind("Print",
    util.sh([[grim -g "$(slurp)" - | satty --filename - --fullscreen --output-filename ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png]]))
hl.bind(mod .. " + Print",
    util.sh([[grim - | wl-copy && notify-send "Screenshot" "Full screen copied to clipboard"]]))

hl.bind(mod .. " + SHIFT + R",
    util.sh([[systemctl --user reload gsr-replay && notify-send -t 3000 "Replay saved" "last 5 min -> /data/replays"]]))

hl.bind(mod .. " + ALT + R", util.sh([[if systemctl --user is-active --quiet gsr-replay; then
        systemctl --user stop gsr-replay
        notify-send -t 3000 "gsr-toggle" "replay buffer disarmed"
      else
        systemctl --user start gsr-replay
        notify-send -t 3000 "gsr-toggle" "replay buffer armed - 5 min rolling"
      fi]]))
