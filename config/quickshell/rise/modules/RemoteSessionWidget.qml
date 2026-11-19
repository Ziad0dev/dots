import QtQuick

// Status-row warning while someone is logged in remotely (a remote logind
// session: SSH, Tailscale SSH). After Omarchy 4.5's remote-session indicator.
Item {
    id: rootMod
    required property var root

    readonly property bool on: root.remoteSessions.length > 0

    visible: on || width > 0.5
    implicitWidth: on ? 20 : 0
    implicitHeight: 28
    clip: true
    Behavior on implicitWidth { Anim { kind: "size"; ms: 250 } }

    IconText {
        anchors.centerIn: parent
        text: "connected_tv"
        fill: 1
        color: root.color01
        font.pixelSize: 15
    }

    TooltipMixin {
        id: tip; root: rootMod.root; owner: rootMod
        text: "Remote login: " + root.remoteSessions.map(function (s) {
            return s.user + (s.host !== "-" ? " from " + s.host : "") + " (" + s.service + ")"
        }).map(function (t) { return root.plain(t) }).join(", ")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tip.show()
        onExited: tip.hide()
    }
}
