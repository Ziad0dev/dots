import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Privacy dots: lit while an app records the mic, reads a video source
// (camera, or a screencast being consumed) or while the Hyprland portal is
// sharing the screen. Read from PipeWire streams, so it is event-driven.
// Quickshell's own peak meters are ignored.
Item {
    id: rootMod
    required property var root

    readonly property var streams: Pipewire.nodes.values.filter(function(n) { return n.isStream })
    PwObjectTracker { objects: rootMod.streams }

    function appName(n) {
        var p = n.properties || {}
        return p["application.name"] || p["application.process.binary"] || n.description || n.name || "app"
    }
    function isSelf(n) {
        var p = n.properties || {}
        return /quickshell/i.test((p["application.process.binary"] || "") + " " + (p["application.name"] || ""))
    }
    function users(mediaClass) {
        var names = []
        for (var i = 0; i < streams.length; i++) {
            var n = streams[i]
            var p = n.properties || {}
            if (p["media.class"] !== mediaClass || isSelf(n)) continue
            var name = appName(n)
            if (names.indexOf(name) < 0) names.push(name)
        }
        return names
    }

    readonly property var micApps: users("Stream/Input/Audio")
    readonly property var videoApps: users("Stream/Input/Video")
    // xdg-desktop-portal-hyprland creates its node only while a share is live
    readonly property bool sharing: Pipewire.nodes.values.some(function(n) { return /^xdph/i.test(n.name || "") })

    readonly property bool mic: micApps.length > 0
    readonly property bool video: videoApps.length > 0
    readonly property bool active: mic || video || sharing

    readonly property string tooltipText: {
        var lines = []
        if (mic) lines.push("Microphone · " + micApps.join(", "))
        if (video) lines.push("Camera / capture · " + videoApps.join(", "))
        if (sharing) lines.push("Screen is being shared")
        return lines.join("\n")
    }

    visible: active || width > 0.5
    implicitWidth: active ? row.implicitWidth + 4 : 0
    implicitHeight: 28
    clip: true
    Behavior on implicitWidth { Anim { kind: "size"; ms: 250 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        IconText {
            visible: rootMod.mic
            anchors.verticalCenter: parent.verticalCenter
            text: ""   // mic
            fill: 1
            color: root.sealRaw
            font.pixelSize: 14
        }
        IconText {
            visible: rootMod.video
            anchors.verticalCenter: parent.verticalCenter
            text: ""   // videocam
            fill: 1
            color: root.sealRaw
            font.pixelSize: 15
        }
        IconText {
            visible: rootMod.sharing
            anchors.verticalCenter: parent.verticalCenter
            text: ""   // screen_share
            fill: 1
            color: root.sealRaw
            font.pixelSize: 15
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tip.show()
        onExited: tip.hide()
    }
}
