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

    // caps lock state comes from Theme's LED watcher (shared with the bar glyph)
    Connections {
        target: osd.root
        function onCapsLockOnChanged() {
            osd.show("\uE318", "Caps Lock", osd.root.capsLockOn ? "on" : "off", -1, osd.root.capsLockOn)
        }
    }

    property bool shown: false
    Timer { id: hideTimer; interval: 1400; onTriggered: osd.shown = false }

    property real reveal: shown ? 1 : 0
    Behavior on reveal { Anim { kind: osd.shown ? "spatialFast" : "exit" } }

    // a pill-sized window: with the frame on it sits on the bottom band and
    // grows out of it (FrameCard "bottom", offset to its screen position);
    // without it, it floats 96px above the bottom as before
    visible: reveal > 0.001
    color: "transparent"
    anchors.bottom: true
    margins.bottom: root.frameOn ? bottomBand : 96
    implicitWidth: 300
    implicitHeight: 56
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "dots-osd"
    mask: Region {}

    readonly property int bottomBand: root.barPosition === "bottom" ? 35 : (root.frameOn ? root.frameThickness : 0)

    FrameCard {
        root: osd.root
        card: pill
        reveal: osd.reveal
        edge: "bottom"
        screenName: osd.screen ? osd.screen.name : ""
        // the window is centred on the bottom edge
        offsetX: osd.screen ? Math.round((osd.screen.width - osd.implicitWidth) / 2) : 0
        offsetY: osd.screen ? osd.screen.height - osd.margins.bottom - osd.implicitHeight : 0
    }
    Rectangle {
        id: pill
        anchors.fill: parent
        radius: root.pillRadius
        color: root.frameOn ? "transparent" : root.cardBg
        border.color: root.pillBorder
        border.width: root.frameOn ? 0 : root.pillBorderW
        opacity: osd.reveal
        scale: root.frameOn ? 1 : 0.94 + 0.06 * osd.reveal
        transform: Translate { y: root.frameOn ? (1 - osd.reveal) * 24 : 0 }
        PillShadow { theme: root; visible: root.styleShadow && !root.frameOn }

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
                    Behavior on width { Anim { kind: "size"; ms: 250 } }
                }
            }
        }
    }
}
