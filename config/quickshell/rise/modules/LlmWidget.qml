import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property string backend: "none"

    readonly property bool idle: backend === "none"
    readonly property string label: backend === "ollama" ? "ollama" : backend
    readonly property string tooltipText: idle
        ? "No inference backend loaded — click to start"
        : "Inference: " + backend + " — click to cycle, right-click to stop all"

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 28

    Process {
        id: query
        command: ["dots-llm", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim()
                rootMod.backend = t.length > 0 ? t : "none"
            }
        }
    }

    Process {
        id: cycle
        command: ["dots-llm", "next"]
        onExited: settle.restart()
    }

    Process {
        id: stopAll
        command: ["dots-llm", "off"]
        onExited: settle.restart()
    }

    // units take a moment to report ActiveState after start/stop
    Timer { id: settle; interval: 900; repeat: false; onTriggered: query.running = true }

    Timer {
        interval: 15000
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
            text: "neurology"
            color: rootMod.idle
                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                : root.seal
            font.pixelSize: 15
            font.weight: Font.DemiBold
            fill: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !rootMod.idle
            text: rootMod.label
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

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
                stopAll.running = false
                stopAll.running = true
                return
            }
            cycle.running = false
            cycle.running = true
        }
    }
}
