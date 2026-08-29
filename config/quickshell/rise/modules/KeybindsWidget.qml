import QtQuick
import Quickshell

Item {
    id: rootMod
    required property var root

    implicitWidth: 20
    implicitHeight: 28

    IconText {
        anchors.centerIn: parent
        text: "\uE312"
        color: rootMod.root.keybindsVisible ? rootMod.root.seal : rootMod.root.ink
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: "Keybinds" }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: {
            tip.hide()
            rootMod.root.keybindsVisible = !rootMod.root.keybindsVisible
        }
    }
}
