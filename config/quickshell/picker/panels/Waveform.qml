import QtQuick
import QtQuick.Shapes
import Quickshell.Services.Pipewire

Item {
    id: wf
    required property var root

    property bool  active: true
    property color lineColor: root.seal
    property int   lines: 3
    property real  lineWidth: 1.2
    property int   segments: 200
    property real  idleAmp: 0.34
    property real  maxAmp: 0.62
    property real  speed: 1.0

    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }

    PwNodePeakMonitor {
        id: peakMon
        node: Pipewire.defaultAudioSink
        enabled: wf.active && wf.visible && node !== null
    }

    property real level: 0
    property real phase: 0

    Timer {
        interval: 33
        running: wf.active && wf.visible
        repeat: true
        onTriggered: {
            var p = peakMon.peak
            if (p === undefined || isNaN(p)) p = 0
            wf.level = wf.level * 0.72 + Math.min(1, p * 1.8) * 0.28
        }
    }

    NumberAnimation on phase {
        running: wf.active && wf.visible
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: Math.round(2600 / Math.max(0.2, wf.speed))
    }

    function jitter(i, k) {
        var s = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453
        return (s - Math.floor(s)) * 2 - 1
    }

    function strand(k) {
        var n = wf.segments
        var mid = wf.height / 2
        var w = wf.width
        if (w <= 0 || n < 2)
            return [Qt.point(0, mid), Qt.point(Math.max(1, w), mid)]

        var half = wf.height / 2
        var decay = 1.0 - k * 0.26
        var amp = (wf.idleAmp + wf.level * wf.maxAmp) * half * decay
        var ph = wf.phase * Math.PI * 2 + k * 1.9
        var f = 1.0 + k * 0.37
        var pts = []

        for (var i = 0; i < n; i++) {
            var t = i / (n - 1)
            var env = Math.sin(t * Math.PI)
            var v = 0.55 * Math.sin(t * 26.0 * f + ph * 3.0)
                  + 0.28 * Math.sin(t * 61.0 * f - ph * 4.7)
                  + 0.17 * Math.sin(t * 113.0 * f + ph * 7.3)
            v += 0.22 * wf.jitter(i, k) * wf.level
            pts.push(Qt.point(t * w, mid + v * amp * (0.35 + 0.65 * env)))
        }
        return pts
    }

    readonly property var strands: {
        var out = []
        for (var k = 0; k < wf.lines; k++) out.push(wf.strand(k))
        return out
    }

    Repeater {
        model: wf.lines

        Shape {
            id: strandShape
            required property int index
            readonly property var pts: wf.strands[strandShape.index] !== undefined
                                       ? wf.strands[strandShape.index] : []
            anchors.fill: parent
            antialiasing: true
            opacity: 1.0 - strandShape.index * 0.28

            ShapePath {
                strokeColor: wf.lineColor
                strokeWidth: wf.lineWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: strandShape.pts }
            }
        }
    }
}
