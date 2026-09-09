import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    visible: implicitWidth > 0.5
    implicitWidth: (root.modStorage && root.storageAvailable) ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: implicitWidth > 0.5 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property bool low: root.storagePercent >= 90

    readonly property string tooltipText: root.storagePercent + "% used  \u00B7  "
        + (root.storageTotalGiB - root.storageUsedGiB).toFixed(1) + " GiB free of "
        + root.storageTotalGiB.toFixed(1) + " GiB"

    Rectangle {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
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
            text: "hard_drive_2"
            color: rootMod.low ? root.color01 : root.seal
            font.pixelSize: 15
            font.weight: Font.DemiBold
            fill: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.storagePercent + "%"
            color: rootMod.low ? root.color01 : root.seal
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process { id: diskTui; command: ["bash", "-c", "ghostty --class=com.dots.float.lg -e yazi /"] }

    MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function (e) {
            tip.hide()
            if (e.button === Qt.RightButton) { diskTui.running = false; diskTui.running = true; return }
            root.storageVisible = !root.storageVisible
        }
    }
}
