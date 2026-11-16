import QtQuick
import QtQuick.Shapes
import "Occult.js" as Occult

// A seal: the word's sigil traced on the magic square of Saturn (Occult.sigil),
// a ring around it, and `legend` written round the ring. The trace starts at a
// small circle and ends on a bar, as sigils are drawn.
Item {
    id: s
    required property var dash
    property string word: ""
    property string legend: ""
    property color ink: dash.bloodText
    property color ringInk: dash.outlineVariant

    readonly property var cells: Occult.sigil(word)
    readonly property real r: Math.min(width, height) / 2
    readonly property real gridR: r * 0.46                   // half the square's span
    function pt(c) {
        var step = gridR
        return Qt.point(width / 2 + (c[0] - 1) * step, height / 2 + (c[1] - 1) * step)
    }

    // outer and inner ring
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: s.ringInk; border.width: 1
    }
    Rectangle {
        anchors.centerIn: parent
        width: s.r * 1.56; height: width; radius: width / 2
        color: "transparent"
        border.color: s.ringInk; border.width: 1
    }

    // the legend written round the band between the rings
    Repeater {
        model: s.legend.length
        delegate: Text {
            required property int index
            readonly property real a: (index / s.legend.length) * 2 * Math.PI - Math.PI / 2
            readonly property real rr: s.r * 0.89
            x: s.width / 2 + rr * Math.cos(a) - width / 2
            y: s.height / 2 + rr * Math.sin(a) - height / 2
            rotation: a * 180 / Math.PI + 90
            text: s.legend.charAt(index)
            color: s.dash.ash
            font.family: "Cormorant Garamond"
            font.pointSize: Math.max(6, s.r * 0.13)
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }

    // the faint square underneath
    Repeater {
        model: 9
        delegate: Rectangle {
            required property int index
            readonly property point p: s.pt([index % 3, Math.floor(index / 3)])
            x: p.x - 1; y: p.y - 1; width: 2; height: 2; radius: 1
            color: s.dash.outlineVariant
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: s.cells.length > 1
        ShapePath {
            strokeColor: s.ink
            strokeWidth: Math.max(1.4, s.r * 0.035)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: s.cells.map(function (c) { return s.pt(c) }) }
        }
    }
    // start: a small circle; end: a bar across the last stroke
    Rectangle {
        visible: s.cells.length > 0
        readonly property point p: s.cells.length ? s.pt(s.cells[0]) : Qt.point(0, 0)
        width: s.r * 0.14; height: width; radius: width / 2
        x: p.x - width / 2; y: p.y - height / 2
        color: "transparent"
        border.color: s.ink; border.width: Math.max(1.4, s.r * 0.035)
    }
    Rectangle {
        visible: s.cells.length > 1
        readonly property point a: s.cells.length > 1 ? s.pt(s.cells[s.cells.length - 2]) : Qt.point(0, 0)
        readonly property point b: s.cells.length > 1 ? s.pt(s.cells[s.cells.length - 1]) : Qt.point(0, 0)
        width: s.r * 0.22; height: Math.max(1.4, s.r * 0.035)
        x: b.x - width / 2; y: b.y - height / 2
        rotation: Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI + 90
        color: s.ink
    }
}
