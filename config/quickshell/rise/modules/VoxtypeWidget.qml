import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    readonly property string state: root.voxState   // idle | recording | transcribing
    readonly property string hint:  root.voxHint
    readonly property bool   hasVoxtype: root.voxAvailable

    readonly property bool recording:    state === "recording"
    readonly property bool transcribing: state === "transcribing"
    readonly property bool showing:      recording || transcribing

    readonly property string label: recording ? "REC" : (transcribing ? "···" : "")
    readonly property color  tone:  recording ? root.color01 : root.ink

    visible: showing
    implicitWidth: showing ? root.evenW(body.implicitWidth + 10) : 0
    implicitHeight: 28

    readonly property string tooltipText: hint !== "" ? hint : (recording ? "Voxtype recording" : "Voxtype transcribing")

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        radius: height / 2
        color: rootMod.recording ? Qt.rgba(rootMod.tone.r, rootMod.tone.g, rootMod.tone.b, 0.16) : "transparent"
        visible: rootMod.showing
    }

    Row {
        id: body
        anchors.centerIn: parent
        spacing: 5

        Rectangle {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: rootMod.tone
            visible: rootMod.recording

            SequentialAnimation on opacity {
                running: rootMod.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.label
            color: rootMod.tone
            font.family: rootMod.root.mono
            font.pixelSize: 11
            font.bold: rootMod.recording
        }
    }

    Process { id: modelProc;  command: ["bash", "-c", "dots-voxtype-model"] }
    Process { id: configProc; command: ["bash", "-c", "dots-voxtype-config"] }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) { configProc.running = false; configProc.running = true }
            else                             { modelProc.running = false;  modelProc.running = true }
        }
    }
}
