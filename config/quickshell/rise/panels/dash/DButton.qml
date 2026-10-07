import QtQuick
import "../../modules"

// Grimoire icon button: a hairline blood frame on a faint wash; `filled` (or
// `checked`) is solid blood. Square-cornered, a lozenge-sharp press.
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
    readonly property color fg: strong ? dash.bone : dash.onSecondaryContainer

    implicitHeight: 40
    implicitWidth: label !== "" ? row.implicitWidth + 28 : implicitHeight
    radius: 2
    color: strong ? dash.blood : "transparent"
    border.color: strong ? dash.blood : dash.outlineVariant
    border.width: 1
    scale: ma.pressed ? 0.94 : 1
    Behavior on scale { Anim { kind: "spatialFast" } }
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
            visible: b.icon !== ""
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
            font.pointSize: 13
            font.weight: Font.DemiBold
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
