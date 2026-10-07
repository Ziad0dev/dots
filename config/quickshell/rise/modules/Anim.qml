import QtQuick
import "Motion.js" as Motion

// NumberAnimation on the shared curve table (Caelestia's tokens, Motion.js).
// `kind` picks curve + length; `ms` keeps a hand-tuned duration.
NumberAnimation {
    property string kind: "effects"
    property int ms: 0

    duration: Motion.durationOr(kind, ms)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.curve(kind)
}
