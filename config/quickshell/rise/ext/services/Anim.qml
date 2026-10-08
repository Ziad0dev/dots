pragma Singleton
// Ported from dhrruvsharma/shell (quickshell/services/Anim.qml), GPL-3.0-or-later.
import QtQuick
import Quickshell

// Shared animation durations (ms) for the workspace disc port.
Singleton {
    id: root
    readonly property int fast: 150
    readonly property int slow: 350
}
