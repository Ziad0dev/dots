import QtQuick
import "../../modules"

// Material 3 switch: a pill track, and a thumb that grows and slides when on.
Item {
    id: sw
    required property var dash
    property bool checked: false
    signal toggled()

    implicitWidth: 52
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? sw.dash.primary : sw.dash.surfaceContainerHighest
        border.width: sw.checked ? 0 : 2
        border.color: sw.dash.outline
        Behavior on color { CAnim {} }
    }
    Rectangle {
        readonly property real d: ma.pressed ? 28 : sw.checked ? 24 : 16
        width: d; height: d; radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? sw.width - 4 - d : 4 + (24 - d) / 2
        color: sw.checked ? sw.dash.onPrimary : sw.dash.outline
        Behavior on x { Anim { kind: "spatialFast" } }
        Behavior on width { Anim { kind: "spatialFast" } }
        Behavior on height { Anim { kind: "spatialFast" } }
        Behavior on color { CAnim {} }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
