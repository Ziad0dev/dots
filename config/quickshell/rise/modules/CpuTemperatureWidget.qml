import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root
    property string gid: "G16"

    visible: implicitWidth > 0.5
    implicitWidth: (root.modCpuTemperature && root.barTemperatureAvailable) ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: implicitWidth > 0.5 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property int tempC: root.barTemperatureC
    readonly property bool hot: tempC >= 80

    readonly property string tooltipText:
        root.barTemperatureSourceLabel(root.barTemperatureSource) + ": " + tempC + "\u00B0C"
        + (root.cpuCoreMaxTemperatureC > 0 ? "  \u00B7  core max " + root.cpuCoreMaxTemperatureC + "\u00B0C" : "")
        + (root.nvmeTemperatureC > 0 ? "  \u00B7  nvme " + root.nvmeTemperatureC + "\u00B0C" : "")

    Rectangle {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.widgetFillColor(rootMod.gid)
        border.color: root.widgetBorderColor(rootMod.gid)
        border.width: root.widgetBorderWidth(rootMod.gid)
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: "device_thermostat"
            color: rootMod.hot ? root.color01 : root.seal
            font.pixelSize: 15
            font.weight: Font.DemiBold
            fill: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.tempC + "\u00B0"
            color: rootMod.hot ? root.color01 : root.seal
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process { id: tempTui; command: ["bash", "-c", "ghostty --class=com.dots.float.lg -e btop"] }

    MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function (e) {
            tip.hide()
            if (e.button === Qt.RightButton) { tempTui.running = false; tempTui.running = true; return }
            root.thermalVisible = !root.thermalVisible
        }
    }
}
