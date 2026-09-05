import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property string missing: ""

    readonly property bool alert: missing.length > 0
    readonly property string tooltipText: alert
        ? "Not mounted: " + missing.split(" ").join(", ")
        : "All mounts present"

    visible: implicitWidth > 0.5
    implicitWidth: alert ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: alert ? 1 : 0
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity       { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Process {
        id: query
        command: ["dots-mounts"]
        stdout: StdioCollector {
            onStreamFinished: rootMod.missing = String(this.text || "").trim()
        }
    }

    Timer {
        interval: 30000
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
        color: Qt.rgba(root.color01.r, root.color01.g, root.color01.b, 0.16)
        border.color: Qt.rgba(root.color01.r, root.color01.g, root.color01.b, 0.45)
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: "hard_drive"
            color: root.color01
            font.pixelSize: 15
            font.weight: Font.DemiBold
            fill: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.missing
            color: root.color01
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process {
        id: mountTui
        command: ["bash", "-c",
                  "ghostty --class=com.dots.float.md -e bash -c 'lsblk -f; echo; systemctl --failed --no-pager; exec fish'"]
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
            mountTui.running = false
            mountTui.running = true
        }
    }
}
