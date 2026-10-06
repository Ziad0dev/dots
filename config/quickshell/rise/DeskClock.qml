import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Desktop clock (STYLE → Desk clock): large time and date on the wallpaper,
// bottom-left, on the Bottom layer — above the wallpaper, below windows, so it
// only shows on empty workspaces. Takes no input. Palette-coloured, with a soft
// shadow so it stays legible on bright wallpapers.
PanelWindow {
    id: desk
    required property var root

    visible: root.styleDeskClock
    color: "transparent"
    anchors { bottom: true; left: true }
    margins {
        left: (root.frameOn ? root.frameThickness : 0) + 48
        bottom: (root.frameOn ? root.frameThickness : 0) + 40
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-deskclock"
    mask: Region {}
    implicitWidth: face.implicitWidth + 40
    implicitHeight: face.implicitHeight + 40

    property date now: new Date()
    Timer {
        // tick on the minute boundary: the clock shows no seconds
        interval: 60000 - (desk.now.getSeconds() * 1000 + desk.now.getMilliseconds())
        running: desk.visible
        repeat: false
        onTriggered: { desk.now = new Date(); restart() }
    }

    Column {
        id: face
        x: 20; y: 20
        spacing: 0
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.8
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowVerticalOffset: 2
        }
        Text {
            text: Qt.formatTime(desk.now, desk.root.clock12h ? "h:mm" : "HH:mm")
            color: desk.root.ink
            font.family: desk.root.mono
            font.pixelSize: 112
            font.weight: Font.Light
        }
        Text {
            text: Qt.formatDate(desk.now, "dddd").toUpperCase()
            color: desk.root.seal
            font.family: desk.root.mono
            font.pixelSize: 18
            font.letterSpacing: 6
            leftPadding: 6
        }
        Text {
            text: Qt.formatDate(desk.now, "d MMMM yyyy")
            color: desk.root.ink
            opacity: 0.8
            font.family: desk.root.mono
            font.pixelSize: 14
            font.letterSpacing: 2
            leftPadding: 6
            topPadding: 4
        }
    }
}
