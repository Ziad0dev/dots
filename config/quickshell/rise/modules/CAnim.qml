import QtQuick
import "Motion.js" as Motion

// ColorAnimation on the shared "effects" curve; `ms` keeps a hand-tuned duration.
ColorAnimation {
    property int ms: 0

    duration: ms > 0 ? ms : Motion.duration("effects")
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.curve("effects")
}
