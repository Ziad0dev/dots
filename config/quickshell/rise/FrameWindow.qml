import QtQuick
import Quickshell
import Quickshell.Wayland

// The screen frame and the melting panel backgrounds, in their own fullscreen
// layer under the bar (BarSlot creates it, so it maps first and stacks below).
//
// Split out of BarSlot for the GPU: Qt damages a whole window on every redraw,
// so while the frame shared the bar's window, any bar animation (the media
// marquee, the equaliser) made Hyprland re-composite and re-blur the entire
// screen each frame. Now this window only redraws when the frame itself changes
// (a panel opening, the bar band auto-hiding), and the bar's window is a strip.
//
// It also carries the frame-edge hover triggers, which live on the frame bands.
PanelWindow {
    id: fw
    required property var root
    required property var bar                // the BarSlot of this screen

    readonly property bool barOnTop: root.barPosition !== "bottom"
    readonly property int edge: root.frameThickness

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore      // FrameExclusions reserves the space
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-frame"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // input only on the hover triggers; everything else passes through
    mask: Region {
        Region { item: rightEdgeZone.visible ? rightEdgeZone : null }
        Region { item: leftEdgeZone.visible ? leftEdgeZone : null }
        Region { item: leftCornerZone.visible ? leftCornerZone : null }
        Region { item: drawerZone.visible ? drawerZone : null }
        Region { item: cornerZone.visible ? cornerZone : null }
    }

    // Both windows are on the Top layer, where a newly mapped surface stacks
    // above the rest. Whenever this one maps again (the frame switched back on,
    // or recovery below) the bar is re-mapped after it, or the frame band would
    // cover the bar's widgets (its own background is transparent in frame mode).
    visible: root.styleFrame
    onVisibleChanged: if (visible) Qt.callLater(fw.restackBar)
    function restackBar() {
        if (!fw.visible) return
        fw.bar.visible = false
        fw.bar.visible = true
    }

    // recovery: if the compositor drops this window (output reset), bring it back
    Connections {
        target: fw
        function onResourcesLost() { recover.restart() }
        function onClosed() { recover.restart() }
    }
    Timer {
        id: recover
        interval: 750
        onTriggered: {
            if (!fw.screen || fw.screen.width <= 0) return
            console.warn("[FrameWindow] window lost; recreating it under the bar")
            fw.visible = false
            fw.visible = Qt.binding(function () { return fw.root.styleFrame })
        }
    }

    // loaded by URL so a missing plugin only disables the frame, not the bar
    Loader {
        anchors.fill: parent
        active: fw.root.styleFrame
        source: "FrameBlobs.qml"
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("[frame] Caelestia.Blobs unavailable; using the classic bar")
                fw.root.frameAvailable = false
            } else if (status === Loader.Ready) {
                item.root = fw.root
                item.screenName = Qt.binding(function () { return fw.screen ? fw.screen.name : "" })
                item.barEdge = Qt.binding(function () { return fw.bar.bandHeight })
            }
        }
    }

    // ── frame-edge hover triggers (frame on, locked bar only) ──
    // right band → notification sidebar; the bottom band's right end (the corner
    // the cursor rests in, since nothing is below a screen) → utilities, its
    // middle → theme drawer; the lower-left corner → dashboard. A right edge
    // shared with another monitor doesn't stop the cursor, so the corner lives
    // on the bottom band where it always does.
    readonly property int cornerSpan: 140
    readonly property bool armed: root.frameOn && !root.barUnlocked
    function openByHover(which) {
        var r = fw.root
        if (which === "notif" && !r.notifVisible) {
            r.activatePopupScreen(fw.screen); r.notifHoverOpened = true; r.notifVisible = true
        } else if (which === "utilities" && !r.utilitiesVisible) {
            r.activatePopupScreen(fw.screen); r.utilitiesHoverOpened = true; r.utilitiesVisible = true
        } else if (which === "dashboard" && !r.dashboardVisible) {
            r.activatePopupScreen(fw.screen); r.dashboardHoverOpened = true; r.dashboardVisible = true
        } else if (which === "drawer" && !r.drawerVisible) {
            r.activatePopupScreen(fw.screen); r.drawerHoverOpened = true; r.drawerVisible = true
        }
    }
    component EdgeZone: Item {
        id: zone
        required property string opens
        HoverHandler { id: hover; onHoveredChanged: hovered ? dwell.restart() : dwell.stop() }
        Timer { id: dwell; interval: 120; onTriggered: if (hover.hovered) fw.openByHover(zone.opens) }
    }
    EdgeZone {
        id: rightEdgeZone
        opens: "notif"
        visible: fw.armed
        x: fw.width - fw.edge
        width: fw.edge
        y: fw.barOnTop ? 35 : fw.edge
        height: fw.height - y - (fw.barOnTop ? fw.edge : 35)
    }
    // dashboard: only the lower-left corner (the left band's bottom end and the
    // bottom band's left end), so passing the whole left edge doesn't open it
    EdgeZone {
        id: leftEdgeZone
        opens: "dashboard"
        visible: fw.armed
        x: 0
        width: fw.edge
        height: 160
        y: fw.height - height - (fw.barOnTop ? fw.edge : 35)
    }
    EdgeZone {
        id: leftCornerZone
        opens: "dashboard"
        visible: fw.armed && fw.barOnTop
        x: 0
        width: fw.cornerSpan
        y: fw.height - fw.edge
        height: fw.edge
    }
    EdgeZone {
        id: drawerZone
        opens: "drawer"
        visible: fw.armed && fw.barOnTop
        width: 320
        x: Math.round((fw.width - width) / 2)
        y: fw.height - fw.edge
        height: fw.edge
    }
    EdgeZone {
        id: cornerZone
        opens: "utilities"
        // the bottom band (the bar's band when the bar sits at the bottom: skip)
        visible: fw.armed && fw.barOnTop
        x: fw.width - fw.cornerSpan
        width: fw.cornerSpan
        y: fw.height - fw.edge
        height: fw.edge
    }
}
