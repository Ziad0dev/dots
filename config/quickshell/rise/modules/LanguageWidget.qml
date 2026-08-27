import QtQuick
import Quickshell
import Quickshell.Io
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root

    LanguageData { id: lang }
    readonly property string activeLabel: lang.activeLabel
    readonly property string tooltipText: "Keyboard: " + lang.layouts[lang.activeIndex].full

    visible: implicitWidth > 0.5
    implicitWidth: row.implicitWidth + 18
    implicitHeight: 28

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: IconMap.icon("language")
            color: root.seal
            font.pixelSize: 15
            font.weight: Font.Medium
            fill: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.activeLabel
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 0.5
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onWheel: (e) => lang.cycle(e.angleDelta.y > 0 ? 1 : -1)
        onClicked: {
            tip.hide()
            root.langVisible = !root.langVisible
        }
    }
}
