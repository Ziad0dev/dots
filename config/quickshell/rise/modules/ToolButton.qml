import QtQuick

// A panel button in the Weather panel's style: `primary` is the solid seal
// button, otherwise the outlined secondary one. Used by the Omarchy-style tool
// panels (Tailscale, world clock, reminders, disk speed test).
Rectangle {
    id: btn
    required property var root
    property string text: ""
    property bool primary: false
    property bool busy: false
    signal clicked()

    height: 26
    radius: root.tileRadius
    color: primary
        ? (busy ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.45)
                : ma.containsMouse ? root.fillPrimaryHover : root.seal)
        : (ma.containsMouse ? root.fillHover : root.fillIdle)
    border.width: primary ? 0 : 1
    border.color: ma.containsMouse ? root.seal : root.sep
    opacity: enabled ? 1 : 0.5
    Behavior on color { CAnim { ms: 120 } }

    UiText {
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? btn.root.paper : (ma.containsMouse ? btn.root.seal : btn.root.ink)
        font.family: btn.root.mono
        font.pixelSize: 11
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !btn.busy && btn.enabled
        onClicked: btn.clicked()
    }
}
