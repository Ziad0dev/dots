import QtQuick

// Hands a panel card's background to the frame: while registered, FrameBlobs
// draws it as a blob growing out of the bar edge with `reveal`, and the card
// itself stays transparent (root.frameCardBg). Non-visual.
Item {
    id: fc
    required property var root
    required property Item card
    property real reveal: 0
    // frame edge it grows out of: "bar" (top or bottom, follows the bar), or
    // "top" / "bottom" / "left" / "right"
    property string edge: "bar"
    // the screen the card is on (panels follow the active popup screen)
    property string screenName: root.activePopupScreenName
    // for cards nested in a positioned container: its offset in the window,
    // so the blob lands in screen coordinates
    property real offsetX: 0
    property real offsetY: 0

    visible: false
    width: 0
    height: 0

    Component.onCompleted: root.registerFrameCard(fc)
    Component.onDestruction: root.unregisterFrameCard(fc)
}
