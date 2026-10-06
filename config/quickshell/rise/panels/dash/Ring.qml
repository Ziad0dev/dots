import QtQuick
import QtQuick.Shapes
import "../../modules"

// Material 3 circular progress: the value arc, a gap, then the track for the rest.
// Angles are degrees clockwise from 3 o'clock. `wavy` draws the value arc as a
// sine wave; `phase` moves it (the caller drives it, so it can be throttled).
Item {
    id: ring
    property real value: 0                  // 0 … 1
    property real thickness: 6
    property real startAngle: -90
    property real sweep: 360
    property color color: "white"
    property color trackColor: Qt.rgba(1, 1, 1, 0.1)
    property bool wavy: false
    property real waveAmp: 2.2
    property int waveCount: 8
    property real phase: 0

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown { Anim { kind: "size"; ms: 600 } }

    readonly property real r: Math.min(width, height) / 2 - thickness / 2 - (wavy ? waveAmp : 0)
    // gap between the value arc and the track, in degrees (round caps eat into it)
    readonly property real gapDeg: r > 0 ? (thickness * 1.4 + 4) / (2 * Math.PI * r) * 360 : 0
    readonly property real valueDeg: sweep * shown
    readonly property bool full: sweep >= 360

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // track: whatever the value arc doesn't cover
        ShapePath {
            strokeColor: ring.trackColor
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.r; radiusY: ring.r
                startAngle: ring.startAngle + ring.valueDeg + (ring.shown > 0 ? ring.gapDeg : 0)
                sweepAngle: Math.max(0, ring.sweep - ring.valueDeg
                    - (ring.shown > 0 ? ring.gapDeg : 0) - (ring.full && ring.shown > 0 ? ring.gapDeg : 0))
            }
        }
        // value arc
        ShapePath {
            strokeColor: ring.shown > 0.002 ? ring.color : "transparent"
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: ring.arc(ring.startAngle, ring.valueDeg, ring.r, ring.wavy, ring.phase) }
        }
    }

    function arc(start, sweepDeg, rad, wave, ph) {
        var pts = [], n = Math.max(2, Math.ceil(Math.abs(sweepDeg) / 3))
        var cx = width / 2, cy = height / 2
        for (var i = 0; i <= n; i++) {
            var a = (start + sweepDeg * i / n) * Math.PI / 180
            var rr = rad + (wave ? waveAmp * Math.sin(a * waveCount + ph) : 0)
            pts.push(Qt.point(cx + rr * Math.cos(a), cy + rr * Math.sin(a)))
        }
        return pts
    }
}
