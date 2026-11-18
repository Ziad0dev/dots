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

    // The tunnel state is read once, then pushed by the daemon on every
    // change (`mullvad status listen`), where it used to be asked for every 5 s.
    // Returns false for anything that isn't a state, so the caller can re-ask.
    function apply(text) {
        var state = ""
        try { state = JSON.parse(text).state || "" } catch (e) { return false }
        if (state === "") return false
        rootMod.on = state === "connected"
        rootMod.busy = state === "connecting" || state === "disconnecting"
        return true
    }

    Process {
        id: query
        command: ["mullvad", "status", "--json"]
        stdout: StdioCollector { onStreamFinished: rootMod.apply(this.text) }
    }

    Process {
        id: listen
        command: ["mullvad", "status", "--json", "listen"]
        running: true
        // an event that isn't a parseable state still means "something changed"
        stdout: SplitParser { onRead: line => { if (!rootMod.apply(line)) settle.restart() } }
        onStarted: query.running = true
        // the daemon restarted (or isn't up yet): listen again in a while
        onExited: relisten.restart()
    }

    Timer { id: settle; interval: 300; onTriggered: query.running = true }
    Timer { id: relisten; interval: 15000; onTriggered: listen.running = true }

    Process {
        id: toggle
        command: ["dots-vpn", "toggle"]
        onExited: query.running = true
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
        Behavior on color { CAnim { ms: 150 } }
        Behavior on opacity { Anim { kind: "effects"; ms: 150 } }
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
