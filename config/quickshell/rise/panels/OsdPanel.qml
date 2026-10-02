import QtQuick
import "../modules"
import "../IconMap.js" as IconMap
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// On-screen display for volume, mic mute, output-device switches and caps lock.
// Driven by PipeWire/LED state rather than by keybinds, so it reacts the same
// whether the change came from a key, pavucontrol or an app. Click-through and
// never focused; it follows the focused monitor.
PanelWindow {
    id: osd
    required property var root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [osd.sink, osd.source].filter(function(n) { return n }) }

    readonly property int sinkVolume: sink && sink.ready && sink.audio ? Math.round(sink.audio.volume * 100) : -1
    readonly property bool sinkMuted: sink && sink.ready && sink.audio ? sink.audio.muted : false
    readonly property bool sourceMuted: source && source.ready && source.audio ? source.audio.muted : false

    // what the pill currently shows
    property string icon: ""
    property string label: ""
    property string value: ""
    property real level: -1          // 0..1, or -1 for no bar
    property bool alert: false

    // PipeWire reports every property once as nodes bind; ignore that burst so
    // the OSD only appears for real changes.
    property bool armed: false
    Timer { running: true; interval: 1500; onTriggered: osd.armed = true }

    function show(icon_, label_, value_, level_, alert_) {
        if (!armed) return
        icon = icon_; label = label_; value = value_; level = level_; alert = alert_
        var monitor = Hyprland.focusedMonitor
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (monitor && Quickshell.screens[i].name === monitor.name) osd.screen = Quickshell.screens[i]
        shown = true
        hideTimer.restart()
    }

    function showVolume() {
        // the volume panel already shows its own slider
        if (sinkVolume < 0 || root.volVisible) return
        var name = sinkMuted ? "volume_off" : sinkVolume === 0 ? "volume_mute" : sinkVolume < 50 ? "volume_down" : "volume_up"
        show(IconMap.icons[name], sinkMuted ? "Muted" : "Volume", sinkVolume + "%", sinkVolume / 100, sinkMuted)
    }

    onSinkVolumeChanged: showVolume()
    onSinkMutedChanged: showVolume()
    onSourceMutedChanged: {
        if (source && source.ready)
            show(IconMap.icons[sourceMuted ? "mic_off" : "mic"], "Microphone", sourceMuted ? "muted" : "live", -1, sourceMuted)
    }
    onSinkChanged: {
        if (sink && !root.volVisible)
            show(IconMap.icons["headphones"], "Output", sink.description || sink.nickname || sink.name, -1, false)
    }

    // caps lock: every keyboard has its own LED; any lit means on. Builtin reads
    // and a read-timeout sleep keep the loop fork-free; it prints only changes.
    property bool capsOn: false
    Process {
        running: true
        command: ["bash", "-c",
            "exec {t}<> <(:); last=; while :; do on=0; " +
            "for f in /sys/class/leds/*::capslock/brightness; do read -r v < \"$f\" && [ \"$v\" != 0 ] && on=1; done; " +
            "[ \"$on\" != \"$last\" ] && echo $on && last=$on; read -t 0.25 -u $t; done"]
        stdout: SplitParser {
            onRead: function(line) {
                var on = line.trim() === "1"
                if (on === osd.capsOn) return
                osd.capsOn = on
                osd.show("", "Caps Lock", on ? "on" : "off", -1, on)
            }
        }
    }

    property bool shown: false
    Timer { id: hideTimer; interval: 1400; onTriggered: osd.shown = false }

    property real reveal: shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: osd.shown ? 140 : 220; easing.type: Easing.OutCubic } }

    visible: reveal > 0.001
    color: "transparent"
    anchors.bottom: true
    margins.bottom: 96
    implicitWidth: 300
    implicitHeight: 56
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "dots-osd"
    mask: Region {}

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: root.pillRadius
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        opacity: osd.reveal
        scale: 0.94 + 0.06 * osd.reveal
        PillShadow { theme: root }

        IconText {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: osd.icon
            fill: 1
            font.pixelSize: 24
            color: osd.alert ? root.sealRaw : root.seal
        }

        Column {
            anchors.left: glyph.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Item {
                width: parent.width
                height: 14
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd.label
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.62)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: osd.value
                    color: osd.alert ? root.sealRaw : root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                visible: osd.level >= 0
                color: root.fillActive
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, osd.level))
                    height: parent.height
                    radius: 3
                    color: osd.alert ? root.sumi : root.seal
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
        }
    }
}
