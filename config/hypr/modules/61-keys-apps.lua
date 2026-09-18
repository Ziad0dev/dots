local util = require("lib.util")
local mod = util.mod

hl.bind(mod .. " + Return",         hl.dsp.exec_cmd("ghostty"))
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
hl.bind(mod .. " + SHIFT + V", util.sh([[cliphist list | fuzzel --dmenu | cliphist decode | wl-copy]]))
