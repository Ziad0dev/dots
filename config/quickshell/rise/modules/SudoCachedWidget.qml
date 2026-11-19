import QtQuick

// Status-row warning while sudo's password is cached (Theme.sudoCached, read
// from sudo's journal lines): a sudo in that terminal won't ask again. Click
// forgets every cached sudo credential (sudo -K). After Omarchy 4.5's
// passwordless-sudo indicator, which warns about the same exposure.
Item {
    id: rootMod
    required property var root

    readonly property bool on: root.sudoCached

    visible: on || width > 0.5
    implicitWidth: on ? 20 : 0
    implicitHeight: 28
    clip: true
    Behavior on implicitWidth { Anim { kind: "size"; ms: 250 } }

    function pad(n) { return (n < 10 ? "0" : "") + n }
    readonly property string until: {
        var d = new Date(root.sudoLastMs + root.sudoTimeoutMin * 60000)
        return pad(d.getHours()) + ":" + pad(d.getMinutes())
    }

    IconText {
        anchors.centerIn: parent
        text: "admin_panel_settings"
        fill: 1
        color: root.color01
        font.pixelSize: 15
    }

    TooltipMixin {
        id: tip; root: rootMod.root; owner: rootMod
        text: "sudo password cached until ~" + rootMod.until + " · click to forget it"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: { tip.hide(); root.forgetSudo() }
    }
}
