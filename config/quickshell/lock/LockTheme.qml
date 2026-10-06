import QtQuick
import Quickshell
import Quickshell.Io
import "Palette.js" as Palette

Item {
    id: theme

    readonly property string colorsPath: Quickshell.env("HOME") + "/.local/state/dots/shell/current/theme/colors.sh"
    readonly property string backgroundPath: Quickshell.env("HOME") + "/.local/state/dots/shell/current/background"

    property color paper:      "#1f1f28"
    property color ink:        "#dcd7ba"
    property color sumi:       "#727169"
    property color color01:    "#c34043"
    property color color02:    "#76946a"
    property color color03:    "#c0a36e"
    property color color04:    "#7e9cd8"
    property color color05:    "#957fb8"
    property color color06:    "#6a9589"
    property color color07:    "#c8c093"
    property color accentHint: "#7e9cd8"
    readonly property color bg:   paper
    // the accent picked in the bar's control panel (settings.json barColor,
    // "color01"…"color07"), so lock and bar match; the palette's own accent
    // whenever that can't be read
    property string barColor: ""
    readonly property color seal: /^color0[1-7]$/.test(barColor) ? theme[barColor] : accentHint
    readonly property color err:  color01
    readonly property string mono: "JetBrainsMono Nerd Font"

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/dots/shell/settings.json"
        printErrors: false
        onLoaded: {
            try { theme.barColor = String(JSON.parse(text()).barColor || "") } catch (e) { theme.barColor = "" }
        }
    }

    Process {
        id: paletteReader
        command: ["cat", theme.colorsPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: Palette.apply(theme, Palette.parse(this.text))
        }
    }
}
