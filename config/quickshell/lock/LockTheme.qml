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
    readonly property color seal: accentHint
    readonly property color err:  color01
    readonly property string mono: "JetBrainsMono Nerd Font"

    Process {
        id: paletteReader
        command: ["cat", theme.colorsPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: Palette.apply(theme, Palette.parse(this.text))
        }
    }
}
