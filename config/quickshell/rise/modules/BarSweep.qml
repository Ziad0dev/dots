import QtQuick

Rectangle {
    id: sweep

    required property var theme
    property color tint: sweep.theme.seal
    property real band: 0.13
    property real strength: 0.0
    property real pos: -0.4
    property int  travelDuration: 760
    property bool reverse: false

    function run() { sweepAnim.restart() }

    color: "transparent"
    opacity: sweep.strength
    visible: sweep.strength > 0.004
    z: 1

    readonly property color edge: Qt.rgba(sweep.tint.r, sweep.tint.g, sweep.tint.b, 0.0)
    readonly property color core: Qt.rgba(sweep.tint.r, sweep.tint.g, sweep.tint.b, 0.38)

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: Math.max(0, Math.min(1, sweep.pos - sweep.band)); color: sweep.edge }
        GradientStop { position: Math.max(0, Math.min(1, sweep.pos));              color: sweep.core }
        GradientStop { position: Math.max(0, Math.min(1, sweep.pos + sweep.band)); color: sweep.edge }
    }

    ParallelAnimation {
        id: sweepAnim
        NumberAnimation {
            target: sweep; property: "pos"
            from: sweep.reverse ? 1.0 + sweep.band : -sweep.band
            to:   sweep.reverse ? -sweep.band : 1.0 + sweep.band
            duration: sweep.travelDuration
            easing.type: Easing.InOutQuad
        }
        SequentialAnimation {
            NumberAnimation { target: sweep; property: "strength"; from: 0.0; to: 1.0; duration: 140 }
            PauseAnimation  { duration: Math.max(0, sweep.travelDuration - 420) }
            NumberAnimation { target: sweep; property: "strength"; to: 0.0; duration: 280 }
        }
    }
}
