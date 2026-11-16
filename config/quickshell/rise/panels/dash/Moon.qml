import QtQuick
import QtQuick.Shapes

// The moon at `frac` of its cycle (0 new · 0.5 full), lit side in bone, the
// dark side a faint disc. Northern-hemisphere view: waxing lit on the right.
Item {
    id: m
    required property var dash
    property real frac: 0
    readonly property real r: Math.min(width, height) / 2
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    // terminator: an ellipse whose x-radius swings from r (new/full) to 0 (quarters)
    readonly property real k: Math.cos(2 * Math.PI * frac)          // 1 new … -1 full
    readonly property bool waxing: frac < 0.5

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(m.dash.bone.r, m.dash.bone.g, m.dash.bone.b, 0.07)
        border.color: m.dash.outlineVariant; border.width: 1
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: m.dash.bone
            // the lit limb: a half circle on the lit side …
            startX: m.cx; startY: m.cy - m.r
            PathArc {
                x: m.cx; y: m.cy + m.r
                radiusX: m.r; radiusY: m.r
                direction: m.waxing ? PathArc.Clockwise : PathArc.Counterclockwise
            }
            // … closed by the terminator, bulging into or away from it
            PathArc {
                x: m.cx; y: m.cy - m.r
                radiusX: Math.max(0.01, Math.abs(m.k) * m.r); radiusY: m.r
                // crescent: back along the lit side; gibbous: across the dark one
                direction: (m.k > 0) === m.waxing ? PathArc.Counterclockwise : PathArc.Clockwise
            }
        }
    }
}
