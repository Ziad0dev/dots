import QtQuick
import "Motion.js" as Motion

// ColorAnimation as Caelestia's CAnim: slow effects (300 ms); `ms` keeps a hand-tuned duration.
ColorAnimation {
    property int ms: 0

    duration: Motion.durationOr("effectsSlow", ms)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.curve("effectsSlow")
}
