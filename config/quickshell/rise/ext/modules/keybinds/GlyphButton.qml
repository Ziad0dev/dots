// Ported from dhrruvsharma/shell (quickshell/modules/keybinds/GlyphButton.qml), GPL-3.0-or-later.
import QtQuick
import qs.ext.colors
import qs.ext.components
import qs.ext.modules.lock

// A round, icon-only button with a Material Symbols glyph.
ClickableRect {
    id: button

    property string icon: ""
    property int iconSize: 17
    property color iconColor: Colors.on_surface_variant
    property color hoverColor: Colors.surface_container_highest
    property color idleColor: "transparent"
    property bool filled: false

    implicitWidth: 32
    implicitHeight: 32
    radius: width / 2
    color: hovered ? hoverColor : idleColor
    cursorShape: Qt.PointingHandCursor

    Glyph {
        anchors.centerIn: parent
        text: button.icon
        filled: button.filled
        font.pixelSize: button.iconSize
        color: button.iconColor
    }
}
