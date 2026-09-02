import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    implicitWidth: 22
    implicitHeight: 28

    property bool on: false
    property bool busy: false
    readonly property string tooltipText: busy
        ? "VPN: switching…"
        : (on ? "Mullvad: connected" : "Mullvad: disconnected")

    Process {
        id: query
        command: ["dots-vpn", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = this.text.trim()
                if (s) { rootMod.on = (s === "on"); rootMod.busy = false }
            }
        }
    }

    Process {
        id: toggle
        command: ["dots-vpn", "toggle"]
        onExited: query.running = true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }

    UiText {
        anchors.centerIn: parent
        text: rootMod.on ? String.fromCodePoint(0xF0BD9) : String.fromCodePoint(0xF0BD8)
        renderType: Text.QtRendering
        font.family: root.mono
        font.pixelSize: 14
        color: rootMod.on
            ? root.seal
            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
        opacity: rootMod.busy ? 0.5 : 1.0
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: { tip.hide(); rootMod.busy = true; toggle.running = true }
    }
}
