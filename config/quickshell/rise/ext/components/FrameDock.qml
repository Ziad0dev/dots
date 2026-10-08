import QtQuick
import qs.ext.services as Services
import "../../modules" as RiseModules

// rise: docks an ext panel's card into rise's frame, so it grows out of the
// bar (or a side band) like rise's own panels instead of floating. In frame
// mode the card's background is drawn by rise's FrameBlobs as a blob melting
// out of the edge (rise/modules/FrameCard.qml); the card itself should then be
// transparent with no border or PanelDecor (`framed`). Without rise's theme
// (the lock screen instance) or with the frame off, it's a plain card at the
// same spot.
//
//   FrameDock { id: dock; card: card; shown: panel.opened; edge: "bar" }
//   Rectangle {
//       id: card
//       x: dock.cardX; y: dock.cardY
//       opacity: dock.reveal; transform: dock.slide
//       color: dock.framed ? "transparent" : …
//   }
//
// The card's parent must sit at the window's origin (ExtRoot's loaders fill
// the overlay), or set offsetX/offsetY. `area` is what the card is placed in
// (its parent unless set: a card sizing its own Loader names the overlay).
Item {
    id: dock

    required property Item card
    property bool shown: false
    // "bar" (follows rise's bar position), "left", "right" or "bottom"
    property string edge: "bar"
    // where along the edge the card sits: 0 = start (left/top) … 1 = end
    property real along: 0.5
    property real offsetX: 0
    property real offsetY: 0
    property Item area: card ? card.parent : null
    // the screen the card is on (ext's overlay follows rise's popup screen)
    property string screenName: theme ? theme.activePopupScreenName : ""

    readonly property var theme: Services.Rise.theme
    readonly property bool framed: theme !== null && theme.frameOn
    readonly property bool barOnTop: !theme || theme.barPosition !== "bottom"
    readonly property string side: edge === "bar" ? (barOnTop ? "top" : "bottom") : edge

    // rise's panel geometry (UtilitiesPanel, KeybindsPanel, SessionMenu)
    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property int band: framed ? theme.frameThickness : 0
    readonly property int topInset: barOnTop ? barBottom + gap : band + (framed ? 0 : gap)
    readonly property int bottomInset: !barOnTop ? barBottom + gap : band + (framed ? 0 : gap)
    readonly property int sideInset: framed ? band : gap

    readonly property real areaW: area ? area.width : 0
    readonly property real areaH: area ? area.height : 0
    readonly property real cardX: !card ? 0
        : side === "left" ? sideInset
        : side === "right" ? areaW - card.width - sideInset
        : Math.round(sideInset + (areaW - 2 * sideInset - card.width) * along)
    readonly property real cardY: !card ? 0
        : side === "top" ? topInset
        : side === "bottom" ? areaH - card.height - bottomInset
        : Math.round(topInset + (areaH - topInset - bottomInset - card.height) * along)

    // created already shown (a window made on open): start closed so the
    // reveal still animates
    property bool _ready: false
    Component.onCompleted: _ready = true
    property real reveal: _ready && shown ? 1 : 0
    Behavior on reveal {
        RiseModules.Anim { kind: dock.shown ? "spatial" : "exit" }
    }
    readonly property bool open: reveal > 0.001

    // the content slides in from the edge as the blob grows
    readonly property real _d: (1 - reveal) * 48
    readonly property Translate slide: Translate {
        x: dock.side === "left" ? -dock._d : dock.side === "right" ? dock._d : 0
        y: dock.side === "top" ? -dock._d : dock.side === "bottom" ? dock._d : 0
    }

    // rounded like rise's panels once docked
    readonly property real radius: framed ? theme.panelRadius : Services.DesktopTheme.rad(16)

    visible: false
    width: 0
    height: 0

    Loader {
        active: dock.theme !== null
        sourceComponent: RiseModules.FrameCard {
            root: dock.theme
            card: dock.card
            reveal: dock.framed ? dock.reveal : 0
            edge: dock.edge
            screenName: dock.screenName
            offsetX: dock.offsetX
            offsetY: dock.offsetY
        }
    }
}
