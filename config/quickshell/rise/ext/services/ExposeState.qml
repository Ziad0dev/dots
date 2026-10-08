pragma Singleton
// Ported from dhrruvsharma/shell (quickshell/services/ExposeState.qml), GPL-3.0-or-later.
import QtQuick
import Quickshell
import Quickshell.Io

// Visibility state for the expose / workspace overview, toggled over IPC:
//   qs ipc call expose toggle
Singleton {
    id: root

    property bool open: false

    function toggle() { root.open = !root.open }

    IpcHandler {
        target: "expose"
        function toggle(): void { root.toggle() }
        function open(): void { root.open = true } // rise: not `show` (qs's CLI takes that)
        function hide(): void { root.open = false }
    }
}
