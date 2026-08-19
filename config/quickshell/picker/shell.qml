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

    property bool launcherVisible: false
    property bool barVisible: true
    property bool waveformActive: true
    property bool controlVisible: false
    property int  waveLines: 3
    property real waveSpeed: 1.0
    property bool showWorkspaces: true
    property bool showTray: true
    property bool showSystem: true
    property bool showClock: true
    property bool showVolume: true

    readonly property string home: Quickshell.env("HOME")
    property var wallpaperSourcePaths: [ shell.home + "/Pictures/wallpapers" ]
    property var themeSourcePaths: [ shell.home + "/dots/config/themes" ]

    readonly property string mono: "JetBrainsMono Nerd Font"
    function evenW(w) { return 2 * Math.round(w / 2) }

    property color paper: "#161616"
    property color ink: "#f2f4f8"
    property color sumi: "#525252"
    property color color01: "#c4746e"
    property color color02: "#8a9a73"
    property color color03: "#c4b28a"
    property color color04: "#8ba4b0"
    property color color05: "#a292a3"
    property color color06: "#8ea4a2"
    property color color07: "#c5c9c5"
    property color accentHint: "#78a9ff"

    property string barColor: "color01"

    function paletteColor(id) {
        if (id === "color02") return shell.color02
        if (id === "color03") return shell.color03
        if (id === "color04") return shell.color04
        if (id === "color05") return shell.color05
        if (id === "color06") return shell.color06
        if (id === "color07") return shell.color07
        if (id === "foreground") return shell.foregroundSoft
        if (id === "accent") return shell.accentHint
        return shell.color01
    }

    readonly property color seal: shell.paletteColor(shell.barColor)
    readonly property color foregroundSoft: Qt.rgba(
        shell.ink.r * 0.88 + shell.paper.r * 0.12,
        shell.ink.g * 0.88 + shell.paper.g * 0.12,
        shell.ink.b * 0.88 + shell.paper.b * 0.12, 1.0)

    readonly property real barBorderMix: 0.22
    readonly property color barBorder: Qt.rgba(
        shell.paper.r * (1 - shell.barBorderMix) + shell.ink.r * shell.barBorderMix,
        shell.paper.g * (1 - shell.barBorderMix) + shell.ink.g * shell.barBorderMix,
        shell.paper.b * (1 - shell.barBorderMix) + shell.ink.b * shell.barBorderMix, 1.0)

    readonly property color sumiHi: Qt.rgba(shell.sumi.r * 0.45 + shell.ink.r * 0.55,
                                            shell.sumi.g * 0.45 + shell.ink.g * 0.55,
                                            shell.sumi.b * 0.45 + shell.ink.b * 0.55, 1.0)
    readonly property color sep: shell.barBorder
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
        if (!shell.activePopupScreen) shell.activePopupScreen = shell.focusedScreen()
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
                if (p.color01) shell.color01 = p.color01
                if (p.color02) shell.color02 = p.color02
                if (p.color03) shell.color03 = p.color03
                if (p.color04) shell.color04 = p.color04
                if (p.color05) shell.color05 = p.color05
                if (p.color06) shell.color06 = p.color06
                if (p.color07) shell.color07 = p.color07
                if (p.accentHint) shell.accentHint = p.accentHint
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

        function launcher(): void {
            if (!shell.launcherVisible) shell.activePopupScreen = shell.focusedScreen()
            shell.launcherVisible = !shell.launcherVisible
        }
        function bar(): void { shell.barVisible = !shell.barVisible }
        function waveform(): void { shell.waveformActive = !shell.waveformActive }
        function accent(id: string): void { shell.barColor = id }
        function control(): void {
            if (!shell.controlVisible) shell.activePopupScreen = shell.focusedScreen()
            shell.controlVisible = !shell.controlVisible
        }
        function reload(): void { paletteProc.running = false; paletteProc.running = true }
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

    LazyLoader {
        active: true
        Launcher { root: shell }
    }
    LazyLoader {
        active: shell.barVisible
        Bar { root: shell }
    }
    LazyLoader {
        active: true
        ControlPanel { root: shell }
    }
}
