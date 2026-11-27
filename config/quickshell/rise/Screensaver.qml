import QtQuick
import Quickshell
import Quickshell.Wayland

// The screensaver (dots-screensaver, hypridle's 5-minute step): a themed clock
// over every monitor (ScreensaverFace.qml), loaded only while running.
//
// It is a layer-shell overlay on purpose, not a window. Hyprland re-checks idle
// inhibitors whenever a *window* maps, goes fullscreen or takes focus, and that
// re-check resets every ext-idle-notify timer: a window-based screensaver woke
// hypridle a second after it started, and the 10-minute lock and the 15-minute
// blackout never came. Layer surfaces, and their keyboard focus, go through
// none of those paths.
//
// Ends on any key (taken, so it doesn't reach the app underneath), a click or
// the pointer moving; hypridle's on-resume also stops it over IPC.
//
// At the lock it is paused, not stopped: black and still, but still mapped.
// Closing it hands keyboard focus back to a window, and that focus change
// resets the idle timers too, so the 15-minute blackout never came. It closes
// when someone comes back, which is activity anyway.
Item {
    id: saver
    required property var root      // the theme (palette, fonts, clock12h)
    required property var screens   // VariantRoot.outputScreens: every real output

    property bool active: false
    property bool paused: false
    property double since: 0

    function start() {
        if (active)
            return
        since = Date.now()
        paused = false
        active = true
    }
    function stop() { active = false; paused = false }
    function pause() { if (active) paused = true }

    LazyLoader {
        active: saver.active

        Variants {
            model: saver.screens

            PanelWindow {
                required property var modelData
                screen: modelData

                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "dots-screensaver"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                color: "transparent"

                ScreensaverFace {
                    anchors.fill: parent
                    theme: saver.root
                    since: saver.since
                    paused: saver.paused
                    onWake: saver.stop()
                }
            }
        }
    }
}
