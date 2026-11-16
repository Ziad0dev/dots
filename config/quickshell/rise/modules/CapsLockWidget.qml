import QtQuick

// Bar glyph while caps lock is on (state from Theme's LED watcher).
Item {
    id: rootMod
    required property var root

    readonly property bool on: root.capsLockOn

    visible: on || width > 0.5
    implicitWidth: on ? 20 : 0
    implicitHeight: 28
    clip: true
    Behavior on implicitWidth { Anim { kind: "size"; ms: 250 } }

    IconText {
        anchors.centerIn: parent
        text: ""   // keyboard_capslock
        color: root.seal
        font.pixelSize: 15
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: "Caps Lock is on" }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tip.show()
        onExited: tip.hide()
    }
}
