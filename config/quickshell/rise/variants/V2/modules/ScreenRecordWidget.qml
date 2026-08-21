import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root
    readonly property color contentColor: root.widgetContentColor("G8", root.seal)

    readonly property bool recording: root.screenRecording
    readonly property int  elapsed:   root.screenRecordingElapsed   // seconds

    visible: true
    implicitWidth: row.implicitWidth + 6
    clip: true
    implicitHeight: 28


    readonly property string elapsedStr: {
        var h = Math.floor(elapsed / 3600)
        var m = Math.floor((elapsed % 3600) / 60)
        var s = elapsed % 60
        function pad(n) { return n < 10 ? "0" + n : String(n) }
        return h > 0 ? (h + ":" + pad(m) + ":" + pad(s)) : (pad(m) + ":" + pad(s))
    }
    readonly property string tooltipText: recording
        ? ("Recording · " + elapsedStr + "\nClick to stop and save\nRight-click to save replay clip")
        : "Click to start recording\nRight-click to save replay clip"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // pulsing record dot
        IconText {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            text: "\uE061"   // fiber_manual_record
            color: rootMod.contentColor
            font.pixelSize: 13

            SequentialAnimation on opacity {
                running: rootMod.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
            }
            // reset opacity when not recording
            onVisibleChanged: if (!rootMod.recording) opacity = 1.0
        }

        // timer
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.recording ? rootMod.elapsedStr : ""
            visible: rootMod.recording
            color: rootMod.contentColor
            font.family: root.mono
            font.pixelSize: 11
        }
    }

    Process {
        id: toggleProc
        command: ["bash", "-c", "dots-capture-screenrecording"]
        onExited: root.refreshRecordingStatus()
    }

    Process {
        id: replayProc
        command: ["bash", "-c", "dots-capture-screenrecording --save-replay"]
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  { tip.hide() }
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (e) {
            tip.hide()
            if (e.button === Qt.RightButton) {
                replayProc.running = false; replayProc.running = true
                return
            }
            toggleProc.running = false; toggleProc.running = true
        }
    }
}
