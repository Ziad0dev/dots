import QtQuick

Rectangle {
    id: ring

    required property var theme
    property color tint: ring.theme.seal
    property real peak: 1.34
    property int  duration: 520

    function pulse() { pulseAnim.restart() }

    anchors.centerIn: parent
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    radius: parent && parent.radius !== undefined ? parent.radius : height / 2
    color: "transparent"
    border.width: 1.5
    border.color: ring.tint
    opacity: 0
    scale: 1
    z: -2

    ParallelAnimation {
        id: pulseAnim
        NumberAnimation {
            target: ring; property: "scale"
            from: 1.0; to: ring.peak; duration: ring.duration; easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation { target: ring; property: "opacity"; from: 0.0; to: 0.6; duration: 80 }
            NumberAnimation { target: ring; property: "opacity"; to: 0.0; duration: ring.duration - 80; easing.type: Easing.InCubic }
        }
    }
}
