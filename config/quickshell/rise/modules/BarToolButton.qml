import QtQuick

// A quick-group icon that opens one of the tool popouts (TailscalePanel,
// WorldClockPanel, ReminderPanel): hover opens it like the other popouts,
// a click pins it. `lit` colours the icon, `badge` shows a small count.
Item {
    id: rootMod
    required property var root
    required property string flag
    property string icon: ""
    property bool lit: false
    property int badge: 0
    property string tooltipText: ""

    implicitWidth: 22
    implicitHeight: 28

    IconText {
        anchors.centerIn: parent
        text: rootMod.icon
        fill: rootMod.lit ? 1 : 0
        font.pixelSize: 16
        color: rootMod.lit ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
        Behavior on color { CAnim { ms: 150 } }
    }
    Rectangle {
        visible: rootMod.badge > 0
        anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 3
        width: Math.max(11, badgeText.implicitWidth + 4); height: 11; radius: 5.5
        color: root.seal
        UiText {
            id: badgeText
            anchors.centerIn: parent
            text: rootMod.badge
            color: root.paper; font.family: root.mono; font.pixelSize: 8; font.weight: Font.Bold
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText; popout: rootMod.flag }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: {
            tip.hide()
            rootMod.root.popout.noteItem(rootMod.flag, rootMod)
            rootMod.root.popout.click(rootMod.flag)
        }
    }
}
