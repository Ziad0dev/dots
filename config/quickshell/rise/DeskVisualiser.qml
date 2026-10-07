import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "modules"

// Desktop visualiser (STYLE → Desktop visualiser, off by default): mirrored
// audio bars along the bottom of the wallpaper, on the Bottom layer like the
// desk clock. Built to stay cheap, since any redraw makes Hyprland
// re-composite what it covers: its window is a strip, not the screen; cava
// runs at 30 fps; and it only runs while something plays AND the workspace on
// this screen is empty (under windows it would still cost a recomposite every
// frame, for bars nobody can see).
PanelWindow {
    id: vis
    required property var root

    readonly property var monitor: Hyprland.monitorFor(vis.screen)
    readonly property var workspace: monitor ? monitor.activeWorkspace : null
    readonly property bool desktopEmpty: !!workspace && (!workspace.toplevels || workspace.toplevels.values.length === 0)
    MprisSelect { id: sel }
    readonly property bool running: root.styleDeskVisualiser && sel.playing && desktopEmpty

    visible: root.styleDeskVisualiser
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    margins {
        left: (root.frameOn ? root.frameThickness : 0)
        right: (root.frameOn ? root.frameThickness : 0)
        bottom: (root.frameOn ? root.frameThickness : 0)
    }
    implicitHeight: 160
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-deskvisualiser"
    mask: Region {}

    readonly property int bands: 48
    property var levels: []
    Process {
        running: vis.running
        command: ["bash", "-c",
            "command -v cava >/dev/null 2>&1 || exit 0; " +
            "exec cava -p <(printf '%s\\n' " +
            "'[general]' 'bars = 48' 'framerate = 30' 'autosens = 1' 'sleep_timer = 0' " +
            "'[input]' 'method = pipewire' 'source = auto' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'[smoothing]' 'monstercat = 1' 'noise_reduction = 60')"]
        stdout: SplitParser {
            onRead: function (line) {
                var p = line.split(";"), out = []
                for (var i = 0; i < vis.bands; i++) {
                    var v = parseInt(p[i])
                    out.push(isNaN(v) ? 0 : Math.min(1, v / 100))
                }
                vis.levels = out
            }
        }
        onRunningChanged: if (!running) vis.levels = []
    }

    // bars grow up from the bottom edge, mirrored around the centre so the
    // bass sits in the middle; no Behavior, cava already smooths at 30 fps
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        readonly property real slot: (vis.width - 96) / (2 * vis.bands)
        spacing: 0
        opacity: vis.running ? 0.55 : 0
        Behavior on opacity { Anim { ms: 400 } }
        Repeater {
            model: 2 * vis.bands
            delegate: Item {
                required property int index
                readonly property int band: index < vis.bands ? vis.bands - 1 - index : index - vis.bands
                readonly property real level: vis.levels.length ? vis.levels[band] : 0
                width: parent.slot
                height: vis.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(2, parent.width - 6)
                    height: Math.max(width, parent.level * (vis.height - 12))
                    radius: width / 2
                    color: vis.root.seal
                }
            }
        }
    }
}
