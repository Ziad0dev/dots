local util = require("lib.util")
local mod = util.mod

hl.bind(mod .. " + Return",         util.sh("ghostty +new-window || ghostty"))
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("ghostty -e tmux new-session -A -s main"))

hl.bind(mod .. " + B", util.launch_or_focus("zen-beta", "zen-beta"))
hl.bind(mod .. " + O", util.launch_or_focus("obsidian", "obsidian"))
hl.bind(mod .. " + C", util.launch_or_focus("discord",  "discord"))

hl.bind(mod .. " + D", hl.dsp.exec_cmd("qs -c rise ipc call launcher toggle"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("qs -c rise ipc call overview toggle"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("qs -c rise ipc call picker wallpaper"))
hl.bind(mod .. " + SHIFT + O", hl.dsp.exec_cmd("qs -c rise ipc call openrouter toggle"))
hl.bind(mod .. " + CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("qs -c rise ipc call picker theme"))

hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("themectl next"))
hl.bind(mod .. " + CTRL + E",  hl.dsp.exec_cmd("themectl bg next"))
hl.bind(mod .. " + N",         hl.dsp.exec_cmd("dots-nightlight toggle"))

hl.bind(mod .. " + V",         hl.dsp.exec_cmd("voxtype toggle"))
hl.bind(mod .. " + period",    hl.dsp.exec_cmd("bemoji -n -t"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("qs -c rise ipc call clipboard toggle"))

hl.bind(mod .. " + ALT + A", hl.dsp.exec_cmd("dots-look anim pick"))
hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd("dots-look shader pick"))
hl.bind(mod .. " + ALT + B", hl.dsp.exec_cmd("dots-look blur toggle"))
hl.bind(mod .. " + ALT + M", hl.dsp.exec_cmd("dots-songrec"))
hl.bind(mod .. " + ALT + G", hl.dsp.exec_cmd("dots-lens"))
-- dots-say is only installed with dots.tts.enable (home/desktop-tools.nix)
hl.bind(mod .. " + ALT + T", hl.dsp.exec_cmd("command -v dots-say >/dev/null && dots-say toggle || notify-send -a dots 'Text to speech is off' 'Set dots.tts.enable = true to install dots-say'"))
hl.bind(mod .. " + ALT + I", hl.dsp.exec_cmd("ghostty --class=com.dots.float -e dots-diskio"))
