import QtQuick
import QtQuick.Shapes
import "../../modules"

// Material 3 expressive shapes from a computed outline:
//   circle · cookie (n scallops) · sunny / burst (n soft points)
//   gem · clam · diamond · pentagon (rounded polygons) · pill (a diagonal capsule)
// The outline is scaled to fill the item, so any width × height works.
Shape {
    id: s
    property string kind: "circle"
    property int sides: 0           // lobes for cookie / sunny / burst (0 = the kind's default)
    property real spin: 0           // degrees
    property color color: "white"
    Behavior on color { CAnim {} }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillColor: s.color
        PathPolyline { path: s.outline(s.kind, s.sides, s.width, s.height, s.spin) }
    }

    function outline(kind, n, w, h, spin) {
        var pts = []
        if (w <= 0 || h <= 0) return pts
        var rot = spin * Math.PI / 180
        var i, t
        if (kind === "circle" || kind === "cookie" || kind === "sunny" || kind === "burst") {
            var lobes = n > 0 ? n : kind === "cookie" ? 9 : kind === "sunny" ? 8 : kind === "burst" ? 12 : 0
            var depth = kind === "cookie" ? 0.07 : kind === "sunny" ? 0.11 : kind === "burst" ? 0.17 : 0
            var steps = 180
            for (i = 0; i < steps; i++) {
                t = i / steps * 2 * Math.PI
                // lobes peak at r = 1, valleys at 1 - depth
                var r = 1 - depth * (1 - Math.cos(lobes * t)) / 2
                pts.push({ x: r * Math.cos(t + rot), y: r * Math.sin(t + rot) })
            }
        } else if (kind === "pill") {
            // capsule (length 1, thickness 0.62) on the diagonal
            var hw = 0.5, hr = 0.31, a = -Math.PI / 4 + rot
            for (i = 0; i <= 24; i++) {
                t = -Math.PI / 2 + i / 24 * Math.PI
                pts.push({ x: hw - hr + hr * Math.cos(t), y: hr * Math.sin(t) })
            }
            for (i = 0; i <= 24; i++) {
                t = Math.PI / 2 + i / 24 * Math.PI
                pts.push({ x: -hw + hr + hr * Math.cos(t), y: hr * Math.sin(t) })
            }
            pts = pts.map(function (p) {
                return { x: p.x * Math.cos(a) - p.y * Math.sin(a), y: p.x * Math.sin(a) + p.y * Math.cos(a) }
            })
        } else {
            // rounded regular polygon: [sides, corner rounding (fraction of the inradius), rotation°]
            var spec = ({ gem: [6, 0.34, 0], clam: [8, 0.42, 22.5], diamond: [4, 0.32, 0], pentagon: [5, 0.30, 0] })[kind] || [4, 0.3, 45]
            var k = spec[0], half = Math.PI / k
            var rc = spec[1] * Math.cos(half)                 // corner circle radius
            var toCenter = 1 - rc / Math.cos(half)            // vertex → corner-circle centre
            for (i = 0; i < k; i++) {
                var va = -Math.PI / 2 + spec[2] * Math.PI / 180 + rot + i * 2 * half
                var cx = toCenter * Math.cos(va), cy = toCenter * Math.sin(va)
                for (var j = 0; j <= 10; j++) {
                    var phi = va - half + j / 10 * 2 * half
                    pts.push({ x: cx + rc * Math.cos(phi), y: cy + rc * Math.sin(phi) })
                }
            }
        }
        // fit the outline to the item
        var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9
        for (i = 0; i < pts.length; i++) {
            minX = Math.min(minX, pts[i].x); maxX = Math.max(maxX, pts[i].x)
            minY = Math.min(minY, pts[i].y); maxY = Math.max(maxY, pts[i].y)
        }
        var sx = w / (maxX - minX), sy = h / (maxY - minY)
        var out = []
        for (i = 0; i < pts.length; i++)
            out.push(Qt.point((pts[i].x - minX) * sx, (pts[i].y - minY) * sy))
        out.push(out[0])
        return out
    }
}
