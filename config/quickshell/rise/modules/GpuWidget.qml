import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    // folded readings show while true (the bar sets it from hover)
    property bool detail: true
    required property var root
    property string gid: "G12"

    visible: implicitWidth > 0.5
    implicitWidth: root.modGpu ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modGpu ? 1 : 0
    Behavior on opacity { Anim { kind: "effects"; ms: 140 } }

    readonly property int percent: root.gpuPercent
    readonly property int memUsedMiB: root.gpuMemoryUsedMiB
    readonly property int memTotalMiB: root.gpuMemoryTotalMiB
    readonly property int tempC: root.gpuTemperatureC
    readonly property bool ok: root.gpuAvailable

    readonly property real memUsedGiB: memUsedMiB / 1024
    readonly property real memTotalGiB: memTotalMiB / 1024
    readonly property int memPercent: memTotalMiB > 0
        ? Math.max(0, Math.min(100, Math.round(memUsedMiB / memTotalMiB * 100)))
        : 0

    readonly property string tooltipText: ok
        ? percent + "% · " + memUsedGiB.toFixed(1) + "/" + memTotalGiB.toFixed(1) + " GiB · " + tempC + "°C"
        : "GPU: no data"

    // sampler removed: Theme.qml owns gpu telemetry

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
            text: "developer_board"
            color: root.seal
            font.pixelSize: 15
            font.weight: Font.DemiBold
            fill: 1
        }

        DetailFold {
            anchors.verticalCenter: parent.verticalCenter
            shown: rootMod.detail || (rootMod.memPercent >= 90)
            contentWidth: foldValue4.implicitWidth
            contentHeight: foldValue4.implicitHeight
            UiText {
                id: foldValue4
                anchors.verticalCenter: parent.verticalCenter
                text: String(Math.min(100, rootMod.percent)).padStart(2, '0') + "%"
                color: root.barValue
                font.family: root.mono
                font.pixelSize: 12
            }
        }

        DetailFold {
            anchors.verticalCenter: parent.verticalCenter
            shown: rootMod.detail || (rootMod.memPercent >= 90)
            contentWidth: foldValue5.implicitWidth
            contentHeight: foldValue5.implicitHeight
            UiText {
                id: foldValue5
                anchors.verticalCenter: parent.verticalCenter
                text: rootMod.memUsedGiB.toFixed(1) + "G"
                color: rootMod.memPercent >= 90 ? root.barAlert : root.barValueSoft
                font.family: root.mono
                font.pixelSize: 12
            }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText; popout: "gpuVisible" }

    Process { id: gpuTui; command: ["bash", "-c", "ghostty --class=com.dots.float.lg -e nvtop"] }

    MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function (e) {
            tip.hide()
            if (e.button === Qt.RightButton) {
                gpuTui.running = false
                gpuTui.running = true
                return
            }
            root.popout.click("gpuVisible")
        }
    }
}
