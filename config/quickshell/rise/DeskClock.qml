import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Desktop clock (STYLE → Desk clock): large time and date on the wallpaper,
// bottom-left, on the Bottom layer — above the wallpaper, below windows, so it
// only shows on empty workspaces. Takes no input. Palette-coloured, over a
// feathered dark scrim: unseen on a dark wallpaper, and on a bright or busy one
// (white blossoms under it) it dims just the area behind the text, which a drop
// shadow on thin glyphs couldn't.
PanelWindow {
    id: desk
    required property var root

    visible: root.styleDeskClock
    color: "transparent"
    anchors { bottom: true; left: true }
    // the face sits padX/padY in from the window's edges, room for the scrim's
    // feathering; the margins take it back so the clock stays where it was
    readonly property int padX: 72
    readonly property int padY: 60
    margins {
        left: Math.max(0, (root.frameOn ? root.frameThickness : 0) + 68 - padX)
        bottom: Math.max(0, (root.frameOn ? root.frameThickness : 0) + 60 - padY)
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-deskclock"
    mask: Region {}
    implicitWidth: face.implicitWidth + 2 * padX
    implicitHeight: face.implicitHeight + 2 * padY

    property date now: new Date()
    Timer {
        // tick on the minute boundary: the clock shows no seconds
        interval: 60000 - (desk.now.getSeconds() * 1000 + desk.now.getMilliseconds())
        running: desk.visible
        repeat: false
        onTriggered: { desk.now = new Date(); restart() }
    }

    Rectangle {
        x: face.x - 24; y: face.y - 14
        width: face.width + 48; height: face.height + 28
        radius: 40
        color: Qt.rgba(0, 0, 0, 0.72)
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: 44
        }
    }

    Column {
        id: face
        x: desk.padX; y: desk.padY
        spacing: 0
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.6
            shadowColor: Qt.rgba(0, 0, 0, 0.8)
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
