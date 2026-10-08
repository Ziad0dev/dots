local util = require("lib.util")
local mod = util.mod

-- rise/ext: the parts ported from dhrruvsharma/shell (quickshell/rise/ExtRoot.qml)
hl.bind("ALT + TAB",                 hl.dsp.exec_cmd("qs -c rise ipc call switcher toggle"))
hl.bind(mod .. " + ALT + TAB",       hl.dsp.exec_cmd("qs -c rise ipc call expose toggle"))
hl.bind(mod .. " + slash",           hl.dsp.exec_cmd("qs -c rise ipc call keybinds toggle"))
hl.bind(mod .. " + SHIFT + W",       hl.dsp.exec_cmd("qs -c rise ipc call wallpaper toggle"))
hl.bind(mod .. " + ALT + W",         hl.dsp.exec_cmd("qs -c rise ipc call themes desktop"))
hl.bind(mod .. " + SHIFT + N",       hl.dsp.exec_cmd("qs -c rise ipc call notes toggle"))
hl.bind(mod .. " + CTRL + N",        hl.dsp.exec_cmd("qs -c rise ipc call notepad toggle"))
hl.bind(mod .. " + ALT + N",         hl.dsp.exec_cmd("qs -c rise ipc call networkMap changeVisible wifi"))
hl.bind(mod .. " + SHIFT + P",       hl.dsp.exec_cmd("qs -c rise ipc call pet toggle"))
hl.bind(mod .. " + ALT + O",         hl.dsp.exec_cmd("qs -c rise ipc call oracle toggle"))
