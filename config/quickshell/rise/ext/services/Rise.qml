pragma Singleton
import QtQuick
import Quickshell

// rise: the host bar's Theme, for ext code that has to fit into rise itself
// (FrameDock hands panel cards to rise's frame). Set by ExtRoot; null in the
// lock screen instance, where there's no bar and panels float as upstream's.
Singleton {
    property var theme: null
}
