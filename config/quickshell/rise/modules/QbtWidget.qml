import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property int active: 0
    property real dlBytes: 0
    property real upBytes: 0
    property bool reachable: false

    readonly property bool busy: reachable && (active > 0 || dlBytes > 0)

    function rate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + "M"
        if (b >= 1024)    return Math.round(b / 1024) + "K"
        return "0"
    }

    readonly property string tooltipText: !reachable
        ? "qBittorrent unreachable"
        : active + " downloading · " + rate(dlBytes) + "/s down · " + rate(upBytes) + "/s up"

    visible: implicitWidth > 0.5
    implicitWidth: busy ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: busy ? 1 : 0
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity       { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Process {
        id: query
        command: ["dots-qbt"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim()
                if (t === "off" || t.length === 0) { rootMod.reachable = false; return }
                var p = t.split(" ")
                if (p.length < 3) { rootMod.reachable = false; return }
                rootMod.active = parseInt(p[0]) || 0
                rootMod.dlBytes = parseFloat(p[1]) || 0
                rootMod.upBytes = parseFloat(p[2]) || 0
                rootMod.reachable = true
            }
        }
    }

    Timer {
        interval: rootMod.busy ? 5000 : 20000
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
            text: "download"
            color: root.seal
            font.pixelSize: 15
            font.weight: Font.DemiBold
            fill: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.rate(rootMod.dlBytes)
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process {
        id: openUi
        command: ["bash", "-c",
                  "systemd-run --user --scope --quiet --collect -- xdg-open http://127.0.0.1:8081"]
    }

    MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function (e) {
            tip.hide()
            if (e.button === Qt.RightButton) { query.running = true; return }
            openUi.running = false
            openUi.running = true
        }
    }
}
