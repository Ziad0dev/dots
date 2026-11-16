// Ported from dhrruvsharma/shell (quickshell/components/StyledScrollBar.qml), GPL-3.0-or-later.
import QtQuick
import QtQuick.Controls
import qs.ext.colors

// The thin translucent scrollbar used by every list and grid in the shell.
ScrollBar {
    id: root

    property real thickness: 3
    property real handleRadius: 2
    property color handleColor: Colors.primary
    property real handleOpacity: 0.45

    policy: ScrollBar.AsNeeded

    contentItem: Rectangle {
        // a custom handle drops the style's own check: with nothing to scroll
        // (an empty list) it would otherwise draw the full length
        visible: root.policy === ScrollBar.AlwaysOn || root.size < 1.0
        implicitWidth: root.thickness
        radius: root.handleRadius
        color: root.handleColor
        opacity: root.handleOpacity
    }
}
