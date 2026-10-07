import QtQuick

// One morphing popout box per shell, after Caelestia's bar popouts
// (caelestia-dots/shell, GPL-3.0-only: modules/bar/popouts/Wrapper.qml and
// ClipWrapper.qml), turned for a horizontal bar.
//
// The bar-anchored panels stay their own windows with their own logic, but
// none of them owns its card geometry any more: each one's content sits in a
// PopoutClip that follows this box. Switching between popouts moves and
// resizes the one box (expressive spatial, 500 ms) while the contents
// cross-fade (default effects, 200 ms); opening grows it out of the bar and
// closing pulls it back in (Caelestia's offsetScale). In frame mode the box is
// a single blob in the frame, so the frame itself morphs.
//
// Hover opens a popout and leaving both the widget and the box closes it, as
// in Caelestia; clicking the widget pins it (keyboard focus, outside click
// closes), clicking again closes it.
Item {
    id: m
    required property var root

    visible: false
    width: 0
    height: 0

    // the panels hosted in the box: their visibility flags on Theme
    readonly property var hosted: [
        "volVisible", "networkVisible", "bluetoothVisible", "batteryVisible",
        "brightnessVisible", "mprisVisible", "weatherVisible", "calendarVisible",
        "cpuVisible", "memVisible", "gpuVisible", "thermalVisible", "storageVisible",
        "powerProfileVisible", "langVisible", "aiUsageVisible", "githubVisible",
        "trayVisible", "workspaceVisible"
    ]
    function hosts(flag) { return hosted.indexOf(flag) >= 0 }

    readonly property string current: {
        for (var i = 0; i < hosted.length; i++)
            if (root[hosted[i]]) return hosted[i]
        return ""
    }
    readonly property bool open: current !== ""
    // the last popout keeps its size while the box closes
    property string last: ""
    // hoverMode is left as it was on close: the closing window keeps its
    // box-only input mask until it unmaps; the next click resets it
    onCurrentChanged: {
        if (current !== "") last = current
        else closeTimer.stop()
    }

    // natural card sizes, reported by each PopoutClip
    property var sizes: ({})
    function setSize(flag, w, h) {
        var s = sizes[flag]
        if (s && s.w === w && s.h === h) return
        var next = {}
        for (var k in sizes) next[k] = sizes[k]
        next[flag] = { w: w, h: h }
        sizes = next
    }
    readonly property var target: sizes[last] || ({ w: 0, h: 0 })

    // ── geometry ──
    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property int edgeMargin: 6
    readonly property bool barOnTop: root.barPosition !== "bottom"
    readonly property real screenW: root.activePopupScreen ? root.activePopupScreen.width : 0
    readonly property real screenH: root.activePopupScreen ? root.activePopupScreen.height : 0

    // the widget's centre (Caelestia centres on the item): the item hovered for
    // each popout is kept and re-measured whenever the bar republishes its
    // layout; the group anchors from BarSlot are the fallback (IPC, keybinds)
    property var widgetItem: ({})
    property var widgetX: ({})
    function measure(item) {
        try { return item ? item.mapToItem(null, item.width / 2, 0).x : 0 } catch (e) { return 0 }
    }
    function refreshX() {
        var next = {}
        for (var k in widgetItem) {
            var x = measure(widgetItem[k])
            if (x > 0) next[k] = x
        }
        widgetX = next
    }
    Connections {
        target: m.root
        function onBarAnchorsByScreenChanged() { m.refreshX() }
    }
    property real anchorX: 0
    readonly property real liveAnchorX: (widgetX[current] || 0) > 0 ? widgetX[current] : root.activePanelCaretX
    onLiveAnchorXChanged: if (open && liveAnchorX > 0) anchorX = liveAnchorX
    onOpenChanged: if (open && liveAnchorX > 0) anchorX = liveAnchorX

    // 1 = tucked into the bar, 0 = out (Caelestia's offsetScale)
    property real offset: open ? 0 : 1
    Behavior on offset { Anim { kind: m.open ? "spatial" : "exit" } }
    readonly property bool shown: offset < 1
    // fully tucked away (the windows unmap now): back to plain panels, so one
    // opened next by a keybind or another panel isn't treated as hovered
    onShownChanged: if (!shown && !open) hoverMode = false

    // size and position only animate while the box is already out; a fresh
    // open snaps to the new popout and grows from the bar
    property real boxW: target.w
    property real boxH: target.h
    property real centerX: anchorX
    Behavior on boxW    { enabled: m.shown; Anim { kind: "spatial" } }
    Behavior on boxH    { enabled: m.shown; Anim { kind: "spatial" } }
    Behavior on centerX { enabled: m.shown; Anim { kind: "spatial" } }

    readonly property real boxX: Math.round(Math.max(edgeMargin,
        Math.min(centerX - boxW / 2, screenW - boxW - edgeMargin)))
    readonly property real visibleH: Math.max(0, boxH * (1 - offset))
    readonly property real boxY: barOnTop ? barBottom + gap : screenH - barBottom - gap - visibleH

    // the frame blob for the box (frame mode); its shape follows the box
    Item {
        id: blobCard
        x: m.boxX
        y: m.boxY
        width: m.boxW
        height: m.visibleH
        property real radius: m.root.pillRadius
    }
    FrameCard {
        root: m.root
        card: blobCard
        // keyed off the open state, not visibleH: the frame's card slot is
        // created when this flips and reads visibleH, which must not be mid-update
        reveal: m.open || m.shown ? 1 : 0
    }

    // ── hover: open on a widget, close once the pointer is on neither ──
    property bool hoverMode: false
    property bool hoverEnabled: root.popoutHover

    function noteItem(flag, item) {
        if (!item) return
        var items = {}
        for (var k in widgetItem) items[k] = widgetItem[k]
        items[flag] = item
        widgetItem = items
        var x = measure(item)
        if (!(x > 0) || widgetX[flag] === x) return
        var next = {}
        for (var j in widgetX) next[j] = widgetX[j]
        next[flag] = x
        widgetX = next
    }
    // the popup screen is already the hovered bar's (BarSlot's HoverHandler)
    function hoverOpen(flag, item) {
        if (!hoverEnabled || !hosts(flag)) return
        noteItem(flag, item)
        if (open && !hoverMode) return          // a pinned popout ignores hover
        closeTimer.stop()
        hoverMode = true
        if (!root[flag]) root[flag] = true
    }
    function hoverLeave() {
        if (hoverMode) closeTimer.restart()
    }
    function boxHovered(hovered) {
        if (!hoverMode) return
        if (hovered) closeTimer.stop()
        else closeTimer.restart()
    }
    // a click on the widget pins a hovered popout, or toggles as before
    function click(flag) {
        closeTimer.stop()
        if (root[flag] && hoverMode) { hoverMode = false; return }
        hoverMode = false
        root[flag] = !root[flag]
    }
    // a click inside a hovered box pins it too (keyboard focus, e.g. a Wi-Fi password)
    function pin() {
        if (!open || !hoverMode) return
        closeTimer.stop()
        hoverMode = false
    }
    // IPC (core/IpcRouter.qml): short names for the hosted flags
    readonly property var names: ({
        volume: "volVisible", network: "networkVisible", bluetooth: "bluetoothVisible",
        battery: "batteryVisible", brightness: "brightnessVisible", media: "mprisVisible",
        weather: "weatherVisible", calendar: "calendarVisible", cpu: "cpuVisible",
        memory: "memVisible", gpu: "gpuVisible", thermals: "thermalVisible",
        storage: "storageVisible", power: "powerProfileVisible", language: "langVisible",
        ai: "aiUsageVisible", github: "githubVisible", tray: "trayVisible",
        workspaces: "workspaceVisible"
    })
    function command(action, name) {
        var flag = names[name] || name
        if (action === "close") { if (current !== "") root[current] = false; return }
        if (!hosts(flag)) return
        if (!open) root.activateFocusedPopupScreen()
        if (action === "hover") {
            hoverEnabled = true
            hoverOpen(flag)
            hoverEnabled = Qt.binding(function () { return m.root.popoutHover })
        } else if (!root[flag] || hoverMode) {
            if (root[flag]) hoverMode = false
            else click(flag)
        }
    }

    Timer {
        id: closeTimer
        interval: 160
        onTriggered: if (m.hoverMode && m.current !== "") m.root[m.current] = false
    }
}
