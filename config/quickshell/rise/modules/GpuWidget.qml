import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    visible: implicitWidth > 0.5
    implicitWidth: root.modGpu ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modGpu ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    property int percent: 0
    property int memUsedMiB: 0
    property int memTotalMiB: 0
    property int tempC: 0
    property bool ok: false

    readonly property real memUsedGiB: memUsedMiB / 1024
    readonly property real memTotalGiB: memTotalMiB / 1024
    readonly property int memPercent: memTotalMiB > 0
        ? Math.max(0, Math.min(100, Math.round(memUsedMiB / memTotalMiB * 100)))
        : 0

    readonly property string tooltipText: ok
        ? percent + "% · " + memUsedGiB.toFixed(1) + "/" + memTotalGiB.toFixed(1) + " GiB · " + tempC + "°C"
        : "GPU: no data"

    Process {
        id: query
        command: ["nvidia-smi",
                  "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu",
                  "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(this.text || "").trim().split("\n")[0].split(",")
                if (parts.length < 4) { rootMod.ok = false; return }
                var u = parseInt(parts[0]), mu = parseInt(parts[1])
                var mt = parseInt(parts[2]), t = parseInt(parts[3])
                if (isNaN(u) || isNaN(mu) || isNaN(mt)) { rootMod.ok = false; return }
                rootMod.percent = Math.max(0, Math.min(100, u))
                rootMod.memUsedMiB = mu
                rootMod.memTotalMiB = mt
                rootMod.tempC = isNaN(t) ? 0 : t
                rootMod.ok = true
            }
        }
    }

    Timer {
        interval: root.modGpu ? 6000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }

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
            text: "developer_board"
            color: root.seal
            font.pixelSize: 15
            font.weight: Font.DemiBold
            fill: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: String(Math.min(100, rootMod.percent)).padStart(2, '0') + "%"
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.memUsedGiB.toFixed(1) + "G"
            color: rootMod.memPercent >= 90
                ? root.color01
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

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
            gpuTui.running = false
            gpuTui.running = true
        }
    }
}
