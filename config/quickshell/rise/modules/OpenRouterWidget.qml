import QtQuick
import Quickshell

Item {
    id: rootMod
    required property var root

    implicitWidth: 24
    implicitHeight: 28

    readonly property string tooltipText: "OpenRouter model tester"

    UiText {
        anchors.centerIn: parent
        text: String.fromCodePoint(0xF1719)
        renderType: Text.QtRendering
        font.family: root.mono
        font.pixelSize: 14
        color: root.openRouterVisible
            ? root.seal
            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: {
            tip.hide()
            if (!root.openRouterVisible) root.activateFocusedPopupScreen()
            root.openRouterVisible = !root.openRouterVisible
        }
    }
}
