import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    implicitWidth: 22
    implicitHeight: 28

    property bool on: false
    readonly property string tooltipText: on ? "Night light: ON" : "Night light: OFF"

    FileView {
        id: flag
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/dots/indicators/nightlight"
        watchChanges: true
        onLoaded: rootMod.on = true
        onLoadFailed: rootMod.on = false
        onFileChanged: reload()
    }

    Process { id: toggle; command: ["dots-nightlight", "toggle"] }

    UiText {
        anchors.centerIn: parent
        text: rootMod.on ? String.fromCodePoint(0xF0594) : String.fromCodePoint(0xF0599)
        renderType: Text.QtRendering
        font.family: root.mono
        font.pixelSize: 14
        color: rootMod.on
            ? root.seal
            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: { tip.hide(); toggle.running = true }
    }
}
