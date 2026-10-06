import QtQuick
import QtQuick.Effects
import Caelestia.Blobs

// Caelestia-style frame, drawn inside each BarSlot (a screen-sized layer window).
// The bar is the thick edge of one rounded frame around the screen; every open
// panel registered with FrameCard is a BlobRect in the same group, so the SDF
// smooth-union melts it out of the frame instead of floating it. Panel content
// stays in its own Overlay window above this.
//
// The accent rim is a second group of the same shapes grown by `rim` px and
// drawn first, so only a `rim`-wide outline of it shows around the fill.
//
// Caelestia.Blobs is GPL-3.0 (caelestia-dots/shell), built from upstream by
// pkgs/caelestia-blobs; this file only uses its QML API.
Item {
    id: frame

    property var root
    property string screenName: ""
    property real barEdge: 35                     // current height of the bar band

    readonly property bool barOnTop: !root || root.barPosition !== "bottom"
    readonly property int edge: root ? root.frameThickness : 0
    readonly property real rim: root && root.styleFrameEdge ? 2 : 0

    // one shadowed layer; group colours are opaque so overlapping shapes don't
    // double up, and the layer carries the bar's alpha (lower with Frost, which
    // is what lets Hyprland's layer blur show through)
    visible: root !== undefined && root !== null
    opacity: root ? root.frameOpacity : 1
    layer.enabled: visible
    // the drop shadow is a blur pass over this screen-sized layer: only when
    // STYLE → Shadow is on
    layer.effect: MultiEffect {
        shadowEnabled: frame.root ? frame.root.styleShadow : false
        blurMax: 15
        shadowColor: Qt.rgba(0, 0, 0, 0.55)
    }

    // the frame band: `grow` px further in than the fill (the rim)
    component FrameShape: BlobInvertedRect {
        required property Item host
        property real grow: 0
        anchors.fill: parent
        anchors.margins: -50          // outer edge off-screen, so smoothing can't bulge it
        radius: Math.max(0, host.root.frameRounding - grow)
        borderTop:    (host.barOnTop ? host.barEdge : host.edge) + 50 + grow
        borderBottom: (host.barOnTop ? host.edge : host.barEdge) + 50 + grow
        borderLeft:   host.edge + 50 + grow
        borderRight:  host.edge + 50 + grow
    }

    // a panel card's background, grown out of its frame edge with `reveal`
    component CardShape: BlobRect {
        required property Item host
        required property var modelData
        property real grow: 0
        // null while its Loader is still wiring it up, or tearing it down
        readonly property Item card: modelData ? modelData.card : null
        readonly property real cx: card ? card.x + modelData.offsetX : 0
        readonly property real cy: card ? card.y + modelData.offsetY : 0
        readonly property real reveal: modelData ? Math.max(0, modelData.reveal) : 0
        readonly property bool here: card !== null && modelData.screenName === host.screenName
        readonly property bool shown: here && reveal > 0.001
        // which frame edge the card grows out of ("bar" follows barPosition)
        readonly property string side: !modelData ? "top" : modelData.edge === "bar"
            ? (host.barOnTop ? "top" : "bottom") : modelData.edge
        readonly property bool vertical: side === "top" || side === "bottom"
        // inner edges of the frame bands, 1px into the band so the blob joins it
        readonly property real topIn: (host.barOnTop ? host.barEdge : host.edge) - 1
        readonly property real bottomIn: host.height - (host.barOnTop ? host.edge : host.barEdge) + 1
        readonly property real leftIn: host.edge - 1
        readonly property real rightIn: host.width - host.edge + 1
        // full extent from that edge to the card's far side; grows with reveal
        // (the spatial curve overshoots, so the blob bounces as it lands)
        readonly property real span: !card ? 0
            : side === "top" ? cy + card.height - topIn
            : side === "bottom" ? bottomIn - cy
            : side === "left" ? cx + card.width - leftIn
            : rightIn - cx
        readonly property real grown: shown ? Math.max(0, span) * reveal + grow : 0

        // hidden = zero size (the group skips empty rects); toggling `visible`
        // leaves a shape out of the group's union
        radius: Math.max(card ? card.radius : 0, 14) + grow
        width: !shown ? 0 : vertical ? card.width + 2 * grow : grown
        height: !shown ? 0 : vertical ? grown : card.height + 2 * grow
        x: !card ? 0 : vertical ? cx - grow : side === "left" ? leftIn : rightIn - width
        y: !card ? 0 : !vertical ? cy - grow : side === "top" ? topIn : bottomIn - height
        deformScale: 0.000012     // Caelestia's popout jelly (0.12 / 10000)
    }

    // A card's shapes exist only while its panel is open (Loader), so an idle
    // frame is just the frame: the group re-solves every shape it holds on each
    // change, and each shape is a scene-graph node.
    component CardSlot: Item {
        id: slot
        required property var modelData
        required property Item host
        required property var shapeGroup
        property real grow: 0
        readonly property bool open: modelData.card !== null && modelData.screenName === host.screenName
            && modelData.reveal > 0.001
        Loader {
            active: slot.open
            sourceComponent: CardShape {
                host: slot.host
                modelData: slot.modelData
                group: slot.shapeGroup
                grow: slot.grow
            }
        }
    }

    // ── rim (drawn first, behind the fill; only with STYLE → Edge) ──
    BlobGroup {
        id: rimGroup
        color: frame.root ? frame.root.frameEdge : "transparent"
        smoothing: 20
    }
    Loader {
        anchors.fill: parent
        active: frame.rim > 0
        sourceComponent: Item {
            FrameShape { host: frame; group: rimGroup; grow: frame.rim }
            Repeater {
                model: frame.root ? frame.root.frameCards : []
                delegate: CardSlot { host: frame; shapeGroup: rimGroup; grow: frame.rim }
            }
        }
    }

    // ── fill ──
    BlobGroup {
        id: blobGroup
        color: frame.root ? frame.root.frameColor : "transparent"
        smoothing: 20
    }
    Item {
        anchors.fill: parent
        FrameShape { host: frame; group: blobGroup }
        Repeater {
            model: frame.root ? frame.root.frameCards : []
            delegate: CardSlot { host: frame; shapeGroup: blobGroup }
        }
    }
}
