import QtQuick
import "Motion.js" as Motion

// NumberAnimation on the shared curve table. `kind` picks curve + default length;
// `ms` keeps a hand-tuned duration while still using the shared curve.
NumberAnimation {
    property string kind: "effects"
    property int ms: 0

    duration: ms > 0 ? ms : Motion.duration(kind)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.curve(kind)
}
