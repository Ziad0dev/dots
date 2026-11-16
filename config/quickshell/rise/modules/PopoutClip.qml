import QtQuick

// A hosted panel's window onto the shared popout box (PopoutMorph). Follows the
// box's geometry and clips the panel's card, which keeps its natural size and
// rides the growing edge out of the bar like Caelestia's ClipWrapper/Wrapper
// (caelestia-dots/shell, GPL-3.0-only). Draws the box background when the
// frame is off (in frame mode the frame's blob is the background).
Item {
    id: clip
    required property var root
    required property string flag   // the panel's visibility flag on Theme
    required property Item card     // the panel's card, a child of this item

    readonly property var m: root.popout
    readonly property bool active: root[flag] === true

    x: m.boxX
    y: m.boxY
    width: m.boxW
    height: m.visibleH
    clip: true

    // the card centred in the full box, slid by the hidden part (top bar: up
    // into the bar; bottom bar: down into it)
    readonly property real cardX: Math.round((m.boxW - card.width) / 2)
    readonly property real cardY: Math.round((m.boxH - card.height) / 2
        - (m.barOnTop ? m.boxH * m.offset : 0))

    function report() {
        if (card && card.width > 0 && card.height > 0) m.setSize(flag, card.width, card.height)
    }
    Connections {
        target: clip.card
        function onWidthChanged()  { clip.report() }
        function onHeightChanged() { clip.report() }
    }
    Component.onCompleted: report()
    onActiveChanged: if (active) report()

    Rectangle {
        anchors.fill: parent
        z: -1
        // only the current (or last, while closing) popout draws it, so a
        // cross-fade never stacks two translucent backgrounds
        visible: !clip.root.frameOn && clip.m.last === clip.flag
        radius: clip.root.pillRadius
        color: clip.root.cardBg
        border.color: clip.root.pillBorder
        border.width: Math.max(1, clip.root.pillBorderW)
        PillShadow { theme: clip.root; visible: clip.root.styleShadow }
    }

    HoverHandler {
        onHoveredChanged: if (clip.active) clip.m.boxHovered(hovered)
    }
    // a press anywhere in a hovered box pins it; the press goes on to the card
    MouseArea {
        anchors.fill: parent
        z: 1000
        enabled: clip.active && clip.m.hoverMode
        onPressed: function (mouse) { clip.m.pin(); mouse.accepted = false }
    }
}
