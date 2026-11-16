import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property int landed: 0
    property string summary: ""

    visible: landed > 0
    implicitWidth: landed > 0 ? 20 : 0
    implicitHeight: 28

    readonly property string tooltipText: summary !== "" ? summary : "Upstream fix landed"

    IconText {
        anchors.centerIn: parent
        text: ""
        color: root.seal
        font.pixelSize: 15
    }

    Process {
        id: watchProc
        command: ["dots-upstream-watch", "json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var count = 0
                var lines = []
                try {
                    var data = JSON.parse(this.text)
                    var watches = data.watches || []
                    for (var i = 0; i < watches.length; i++) {
                        if (watches[i].state === "landed") {
                            count++
                            lines.push(watches[i].description || watches[i].name)
                        }
                    }
                } catch (e) {
                    count = 0
                    lines = []
                }
                rootMod.landed = count
                rootMod.summary = lines.join("\n")
            }
        }
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { watchProc.running = false; watchProc.running = true }
    }

    Process {
        id: runProc
        command: ["bash", "-c", "dots-launch-floating-terminal-with-presentation 'dots-upstream-watch status; echo; read -r _'"]
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: {
            tip.hide()
            runProc.running = false; runProc.running = true
        }
    }
}
