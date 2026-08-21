import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root
    property string colorGid: "G3"
    readonly property color contentColor: root.widgetContentColor(colorGid, root.ink)

    implicitWidth: 26
    implicitHeight: 28

    readonly property string tooltipText: "File manager\nClick to open yazi"

    Item {
        anchors.centerIn: parent
        width: 20
        height: 20

        IconText {
            anchors.centerIn: parent
            text: "\uE2C7"
            color: rootMod.contentColor
            font.pixelSize: 14
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process { id: filesProc; command: ["bash", "-c", "ghostty --class=com.dots.float.md -e yazi"] }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: {
            tip.hide()
            filesProc.running = false; filesProc.running = true
        }
    }
}
