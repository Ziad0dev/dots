import QtQuick
import "../../modules"

// Material 3 icon button. Round at rest; the corners tighten while pressed
// (shape morph). Tonal by default; `filled` (or `checked`) uses the primary colour.
Rectangle {
    id: b
    required property var dash
    property string icon: ""
    property string label: ""
    property bool filled: false
    property bool checked: false
    property bool active: true
    property real iconSize: 18             // points
    signal clicked()

    readonly property bool strong: filled || checked
    readonly property color fg: strong ? dash.onPrimary : dash.onSecondaryContainer

    implicitHeight: 40
    implicitWidth: label !== "" ? row.implicitWidth + 28 : implicitHeight
    radius: ma.pressed ? Math.min(height / 2, 10) : height / 2
    Behavior on radius { Anim { kind: "spatialFast" } }
    color: strong ? dash.primary : dash.secondaryContainer
    Behavior on color { CAnim {} }
    opacity: active ? 1 : 0.38

    // state layer
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: b.fg
        opacity: !b.active ? 0 : ma.pressed ? 0.14 : ma.containsMouse ? 0.08 : 0
        Behavior on opacity { Anim { ms: 120 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: b.icon
            color: b.fg
            fill: b.strong ? 1 : 0
            font.pointSize: b.iconSize
        }
        DText {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.label !== ""
            text: b.label
            color: b.fg
            font.pointSize: 11
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: b.active
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
