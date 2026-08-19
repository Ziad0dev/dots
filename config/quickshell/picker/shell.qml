import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Palette.js" as Palette
import "panels"

ShellRoot {
    id: shell

    property string pickerStyle: "carousel"
    property bool   imagePickerVisible: false
    property string imagePickerMode: "wallpaper"
    property var    activePopupScreen: null

    readonly property string home: Quickshell.env("HOME")
    property var wallpaperSourcePaths: [ shell.home + "/Pictures/wallpapers" ]
    property var themeSourcePaths: [ shell.home + "/dots/config/themes" ]

    readonly property string mono: "JetBrainsMono Nerd Font"
    function evenW(w) { return 2 * Math.round(w / 2) }

    property color paper: "#161616"
    property color ink: "#f2f4f8"
    property color sumi: "#525252"
    property color accentHint: "#78a9ff"

    readonly property color seal: shell.accentHint
    readonly property color sumiHi: Qt.rgba(shell.sumi.r * 0.45 + shell.ink.r * 0.55,
                                            shell.sumi.g * 0.45 + shell.ink.g * 0.55,
                                            shell.sumi.b * 0.45 + shell.ink.b * 0.55, 1.0)
    readonly property color sep: Qt.rgba(shell.ink.r, shell.ink.g, shell.ink.b, 0.18)
    readonly property color frameWeak: Qt.rgba(shell.ink.r, shell.ink.g, shell.ink.b, 0.05)

    function focusedScreen() {
        var want = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++)
            if (list[i].name === want) return list[i]
        return list.length > 0 ? list[0] : null
    }

    function open(mode) {
        shell.imagePickerMode = (mode === "theme") ? "theme" : "wallpaper"
        shell.activePopupScreen = shell.focusedScreen()
        paletteProc.running = false
        paletteProc.running = true
        shell.imagePickerVisible = true
    }

    Component.onCompleted: {
        shell.activePopupScreen = shell.focusedScreen()
        paletteProc.running = true
    }

    Process {
        id: paletteProc
        command: ["dots-picker-palette"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = Palette.parse(this.text)
                if (p.paper) shell.paper = p.paper
                if (p.ink) shell.ink = p.ink
                if (p.sumi) shell.sumi = p.sumi
                var a = p.accentHint || p.color04 || p.color06
                if (a) shell.accentHint = a
            }
        }
    }

    IpcHandler {
        target: "picker"
        function wallpaper(): void { shell.open("wallpaper") }
        function theme(): void { shell.open("theme") }
        function close(): void { shell.imagePickerVisible = false }
        function style(name: string): void { shell.pickerStyle = name }
        function current(): string { return shell.pickerStyle }
    }

    LazyLoader {
        active: shell.pickerStyle === "carousel"
        ImageCarouselCarousel { root: shell }
    }
    LazyLoader {
        active: shell.pickerStyle === "tanzaku" || shell.pickerStyle === ""
        ImageCarouselPanel { root: shell }
    }
    LazyLoader {
        active: shell.pickerStyle === "hearthstone"
        ImageCarouselHearthstone { root: shell }
    }
}
