import QtQuick

// The grimoire divider under a popout's title:  ─────── ⸸ ───────
// in the window-border red, so it matches the frame and Hyprland.
Item {
    id: g
    required property var root
    readonly property color ink: root.windowBorder
    implicitHeight: 12
    height: 12
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.right: sign.left; anchors.rightMargin: 6
        height: 1; color: Qt.rgba(g.ink.r, g.ink.g, g.ink.b, 0.45)
    }
    Text {
        id: sign
        anchors.centerIn: parent
        text: "⸸"
        color: g.ink
        font.family: "Noto Serif"
        font.pixelSize: 16
        renderType: Text.NativeRendering
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: sign.right; anchors.leftMargin: 6; anchors.right: parent.right
        height: 1; color: Qt.rgba(g.ink.r, g.ink.g, g.ink.b, 0.45)
    }
}
