pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "modules"

// The app dock, after Omarchy 4.5's (shell/plugins/dock) and macOS's, on the
// left edge and part of the frame: with the frame on, its shelf is a
// FrameCard, so the frame grows it out of the left band (and it swells with
// the magnified icons, jelly included), the way Caelestia's drawers come out
// of its frame. Without the frame it draws its own glass shelf.
//
// Pinned apps, then everything running; an apps button opens the launcher;
// a mark on the frame side shows what runs (the accent while it has focus).
// Click opens, focuses, or cycles an app's windows; middle-click opens a new
// window; right-click keeps or removes it, or quits it. Icons come from the
// bar's icon theme (QS_ICON_THEME: the theme's own icons, WhiteSur-dark on
// oled).
//
// Settings → Bar → Dock (`dockMode`): "autohide" (default: every workspace,
// out of the left edge when the pointer touches it), "floating" (always on
// floating workspaces only, as in Omarchy), "always" (reserves its width),
// "off". Pins: desktop ids, one per line, in ~/.local/state/dots/dock-pins.
// Windows come from the Wayland toplevel list, which activates and closes
// them itself.
PanelWindow {
    id: dock
    required property var root

    readonly property string mode: root.dockMode
    readonly property bool framed: root.frameOn
    readonly property int edge: framed ? root.frameThickness : 0
    readonly property int pad: 9
    readonly property int gap: 6
    // the room on the left band: below the bar band (35, as FrameWindow has
    // it) and above the dashboard's zone at the band's bottom end (160)
    readonly property bool barOnTop: root.barPosition !== "bottom"
    readonly property int topReserve: (barOnTop ? 35 : edge) + 8
    readonly property int bottomReserve: (barOnTop ? edge : 35) + 160 + 8
    readonly property real room: Math.max(0, dock.height - topReserve - bottomReserve)
    // icons shrink (down to 24) when there are too many to fit, leaving room
    // for the magnified ones to push the others apart
    readonly property int iconSize: {
        const n = 1 + apps.length
        const fixed = 2 * pad + (n - 1) * gap + (apps.length > 0 ? 1 + gap : 0)
        const fit = Math.floor((room - fixed - 56) / n)
        return Math.max(24, Math.min(38, fit))
    }
    readonly property int maxIcon: Math.round(iconSize * 1.47)

    // ── when it shows ──
    readonly property var monitor: Hyprland.monitorFor(dock.screen)
    readonly property var workspace: monitor ? monitor.activeWorkspace : null
    readonly property bool fullscreen: !!workspace && workspace.hasFullscreen
    readonly property bool onFloating: !!workspace && root.wsLayoutOf(workspace.id) === "floating"
    property bool edgeHovered: false
    property bool dockHovered: false
    property bool menuOpen: false
    // whether the dock applies right now (floating: only on floating workspaces)
    readonly property bool active: mode === "autohide" || mode === "always" || (mode === "floating" && onFloating)
    onActiveChanged: if (!active) { menuOpen = false; dockHovered = false; edgeHovered = false }
    readonly property bool wanted: mode === "always" || (mode === "floating" && onFloating)
        || (mode === "autohide" && (edgeHovered || dockHovered || hideDelay.running || menuOpen))
    readonly property bool shown: active && !fullscreen && (wanted || dockHovered || menuOpen)
    Timer { id: hideDelay; interval: 600 }

    // 0 → 1 as it comes out; the frame grows the shelf with it
    property real reveal: shown ? 1 : 0
    Behavior on reveal { Anim { kind: "spatial" } }

    // unmapped when off and under a fullscreen window: a mapped Overlay
    // surface, even an empty one, stops Hyprland scanning a fullscreen game
    // out directly (latency, no tearing). It maps again above any panel
    // already open; panels open over it as usual.
    visible: mode !== "off" && !fullscreen
    color: "transparent"
    anchors { left: true; top: true; bottom: true }
    // room for the shelf at its widest plus the name bubble / menu beside it
    implicitWidth: edge + baseWidth + (maxIcon - iconSize) + 240
    // always at the screen's corner: the frame draws the shelf in screen
    // coordinates from this window's (FrameCard offsets 0). Respecting the
    // bar's and frame's zones would inset the window and split the shelf
    // from its blob; "always" reserves its width with dockSpace instead.
    exclusionMode: ExclusionMode.Ignore
    // above the frame: the frame layer (Top, mapped after this) draws the
    // shelf's background with a compositor blur, which on the same layer
    // stacked over the icons and smeared them into ghosts beside each one.
    // The dock hides for fullscreen windows itself, and maps before any panel
    // opens, so panels still stack above it.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-dock"
    // input: the shelf (and its menu) while out; while hidden, a strip on the
    // frame's left band beside the shelf, which is what calls it out
    mask: Region {
        Region { item: dock.active && !dock.fullscreen && dock.mode === "autohide" ? edgeStrip : null }
        Region { item: dock.shown ? shelf : null }
        Region { item: dock.shown && menu.visible ? menu : null }
    }

    Item {
        id: edgeStrip
        x: 0
        width: Math.max(2, dock.edge)
        // clear of the bar band and the dashboard's zone below
        y: Math.max(dock.topReserve, shelf.y - 40)
        height: Math.min(dock.height - dock.bottomReserve, shelf.y + shelf.height + 40) - y
        HoverHandler {
            onHoveredChanged: {
                dock.edgeHovered = hovered
                if (!hovered) hideDelay.restart()
            }
        }
    }

    // ── pins ──
    property var pins: []
    readonly property string pinsPath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/dots/dock-pins"
    FileView {
        id: pinsFile
        path: dock.pinsPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: dock.pins = String(text()).split("\n").map(function (s) { return s.trim() })
            .filter(function (s) { return /^[A-Za-z0-9._+-]+$/.test(s) })
        // no file yet: a terminal and a browser, if they're installed
        onLoadFailed: dock.pins = ["com.mitchellh.ghostty", "zen-beta", "zen"]
    }
    function savePins(list) {
        dock.pins = list
        pinsFile.setText(list.join("\n") + "\n")
    }
    function pin(id) { if (id && pins.indexOf(id) < 0) savePins(pins.concat([id])) }
    function unpin(id) { savePins(pins.filter(function (p) { return p !== id })) }

    // ── apps: pinned first, then running ──
    function entryFor(id) {
        return id ? (DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)) : null
    }
    function idOf(entry, appId) { return entry ? entry.id : appId }
    readonly property var toplevels: ToplevelManager.toplevels.values
    readonly property var apps: {
        const out = [], seen = {}
        for (const p of dock.pins) {
            const e = DesktopEntries.byId(p)
            if (!e || seen[e.id]) continue       // not installed: nothing to launch
            seen[e.id] = true
            out.push({ id: e.id, entry: e, pinned: true })
        }
        for (const t of dock.toplevels) {
            const e = entryFor(t.appId)
            const id = idOf(e, t.appId)
            if (!id || seen[id]) continue
            seen[id] = true
            out.push({ id: id, entry: e, pinned: false, appId: t.appId })
        }
        return out
    }
    function windowsOf(app) {
        return dock.toplevels.filter(function (t) {
            const e = dock.entryFor(t.appId)
            return dock.idOf(e, t.appId) === app.id
        })
    }
    // an app just launched bounces until a window of it shows up (macOS), or
    // for eight seconds if none does
    property var bouncing: ({})
    function launch(app) {
        if (!app.entry) return
        app.entry.execute()
        const b = Object.assign({}, bouncing); b[app.id] = windowsOf(app).length; bouncing = b
        bounceStop.restart()
    }
    Timer { id: bounceStop; interval: 8000; onTriggered: dock.bouncing = ({}) }
    onToplevelsChanged: {
        const b = Object.assign({}, bouncing); let changed = false
        for (const id in b) {
            if (windowsOf({ id: id }).length > b[id]) { delete b[id]; changed = true }
        }
        if (changed) bouncing = b
    }
    // focus the app, or cycle its windows if it already has focus
    function activate(app) {
        const wins = windowsOf(app)
        if (wins.length === 0) { launch(app); return }
        const i = wins.findIndex(function (t) { return t.activated })
        wins[(i + 1) % wins.length].activate()
    }
    function quit(app) {
        for (const t of windowsOf(app)) t.close()
    }

    // ── geometry: unmagnified slots (magnification measures from these, so
    // it can't feed back into its own layout) ──
    readonly property int slotCount: 1 + apps.length
    readonly property real dividerSpan: gap + 1 + gap
    readonly property real baseWidth: iconSize + 2 * pad
    readonly property real baseHeight: slotCount * iconSize + Math.max(0, slotCount - 1) * gap
        + (apps.length > 0 ? dividerSpan - gap : 0) + 2 * pad
    readonly property real shelfY: topReserve + Math.max(0, Math.round((room - baseHeight) / 2))
    function slotCentre(slot) {
        const top = shelfY + pad
        if (slot === 0) return top + iconSize / 2
        return top + iconSize + dividerSpan + (slot - 1) * (iconSize + gap) + iconSize / 2
    }
    // the pointer's y in the window (-1: not over the shelf)
    readonly property real my: shelfHover.hovered ? shelfHover.point.scenePosition.y : -1
    function growAt(cy) {
        if (my < 0) return 0
        const g = Math.max(0, 1 - Math.abs(my - cy) / 130)
        return (maxIcon - iconSize) * g * g
    }
    // the widest icon right now, which the shelf widens to
    readonly property real swell: {
        if (my < 0) return 0
        let best = 0
        for (let s = 0; s < slotCount; s++) best = Math.max(best, growAt(slotCentre(s)))
        return best
    }

    // ── the shelf ──
    Rectangle {
        id: shelf
        x: dock.edge
        y: dock.shelfY - Math.round((height - dock.baseHeight) / 2)
        width: dock.baseWidth + dock.swell
        height: column.implicitHeight + 2 * dock.pad
        radius: 22
        Behavior on width { Anim { kind: "spatialFast" } }
        // framed: the frame draws the background (FrameCard below)
        color: dock.framed ? "transparent"
            : Qt.rgba(dock.root.paper.r, dock.root.paper.g, dock.root.paper.b, dock.root.glassMode ? 0.22 : 0.34)
        border.width: dock.framed ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        visible: dock.reveal > 0.01
        // unframed: slides in from the edge
        transform: Translate { x: dock.framed ? 0 : -(1 - dock.reveal) * (dock.baseWidth + 12) }

        HoverHandler {
            id: shelfHover
            onHoveredChanged: {
                dock.dockHovered = hovered
                if (!hovered) hideDelay.restart()
            }
        }

        // a soft light along the shelf (glass), unframed only
        Rectangle {
            visible: !dock.framed
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.12) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        Column {
            id: column
            x: dock.pad
            y: dock.pad
            spacing: dock.gap
            opacity: Math.min(1, dock.reveal * 1.6)
            transform: Translate { x: -(1 - dock.reveal) * 14 }

            // the apps button: the launcher's grid of every app
            DockIcon {
                slot: 0
                glyph: "apps"
                label: "Apps"
                onPicked: Quickshell.execDetached(["qs", "-c", "rise", "ipc", "call", "launcher", "toggle"])
            }
            Item {
                width: dock.iconSize
                height: 1
                visible: dock.apps.length > 0
                Rectangle {
                    anchors.centerIn: parent
                    width: dock.iconSize * 0.6
                    height: 1
                    color: Qt.rgba(dock.root.ink.r, dock.root.ink.g, dock.root.ink.b, 0.16)
                }
            }
            Repeater {
                model: dock.apps
                delegate: DockIcon {
                    required property var modelData
                    required property int index
                    readonly property var wins: dock.windowsOf(modelData)
                    slot: index + 1
                    app: modelData
                    iconName: modelData.entry ? modelData.entry.icon : (modelData.appId || "")
                    label: modelData.entry ? modelData.entry.name : (modelData.appId || "")
                    windows: wins.length
                    focused: wins.some(function (t) { return t.activated })
                    faded: modelData.pinned && wins.length === 0
                    bouncing: dock.bouncing[modelData.id] !== undefined
                    onPicked: dock.activate(modelData)
                    onMiddle: dock.launch(modelData)
                    onMenu: function (item) { menu.openFor(modelData, item) }
                }
            }
        }
    }

    // "always": tiled windows keep clear of the shelf (stacked on the frame's
    // own reserved band, as FrameExclusions does it)
    PanelWindow {
        screen: dock.screen
        visible: dock.visible && dock.mode === "always"
        anchors { left: true; top: true; bottom: true }
        implicitWidth: 1
        color: "transparent"
        mask: Region {}
        exclusiveZone: Math.round(dock.baseWidth + dock.maxIcon - dock.iconSize)
        WlrLayershell.namespace: "dots-dock-space"
    }

    // the frame grows the shelf out of its left band
    FrameCard {
        root: dock.root
        card: shelf
        reveal: dock.framed ? dock.reveal : 0
        edge: "left"
        screenName: dock.screen ? dock.screen.name : ""
    }

    // one icon: grows rightwards, away from the frame, with the pointer
    component DockIcon: Item {
        id: di
        property int slot: 0
        property var app: null
        property string iconName: ""
        property string glyph: ""
        property string label: ""
        property int windows: 0
        property bool focused: false
        property bool faded: false
        property bool bouncing: false
        signal picked()
        signal middle()
        signal menu(var item)
        readonly property real size: dock.iconSize + dock.growAt(dock.slotCentre(slot))
        // the launch bounce: out from the frame and back (macOS)
        property real hop: 0
        SequentialAnimation on hop {
            running: di.bouncing
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 16; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { to: 0; duration: 260; easing.type: Easing.InQuad }
            PauseAnimation { duration: 120 }
        }
        width: dock.iconSize
        height: di.size

        // hover wash behind the icon
        Rectangle {
            x: -4; y: (parent.height - height) / 2
            width: di.size + 8; height: di.size + 8
            radius: 12
            color: iconMa.containsMouse ? Qt.rgba(dock.root.ink.r, dock.root.ink.g, dock.root.ink.b, 0.07) : "transparent"
            Behavior on color { CAnim { ms: 120 } }
        }

        Image {
            visible: di.glyph === ""
            x: Math.min(di.hop, dock.pad - 2 + dock.swell - (di.size - dock.iconSize))
            anchors.verticalCenter: parent.verticalCenter
            width: di.size; height: di.size
            source: di.glyph === "" ? Quickshell.iconPath(di.iconName, "application-x-executable") : ""
            sourceSize: Qt.size(128, 128)
            smooth: true; mipmap: true
            opacity: di.faded ? 0.5 : 1
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        IconText {
            visible: di.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: di.size
            horizontalAlignment: Text.AlignHCenter
            text: di.glyph
            font.pixelSize: di.size * 0.58
            color: iconMa.containsMouse ? dock.root.seal : dock.root.ink
        }
        // running: a mark on the frame side, a longer one in the accent while
        // it has focus (several windows: a little longer still)
        Rectangle {
            x: -dock.pad + 2
            anchors.verticalCenter: parent.verticalCenter
            visible: di.windows > 0
            width: 3
            height: di.focused ? 18 : di.windows > 1 ? 10 : 5
            radius: 1.5
            color: di.focused ? dock.root.seal : Qt.rgba(dock.root.ink.r, dock.root.ink.g, dock.root.ink.b, 0.7)
            Behavior on height { Anim { kind: "spatialFast" } }
        }
        // the name, beside the icon while hovered
        Rectangle {
            visible: iconMa.containsMouse && di.label !== "" && !menu.visible
            x: di.size + 14
            anchors.verticalCenter: parent.verticalCenter
            width: tip.implicitWidth + 16; height: tip.implicitHeight + 8
            radius: 8
            color: Qt.rgba(dock.root.paper.r, dock.root.paper.g, dock.root.paper.b, 0.9)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            UiText {
                id: tip
                anchors.centerIn: parent
                text: di.label
                textFormat: Text.PlainText
                color: dock.root.ink
                font.family: dock.root.mono; font.pixelSize: 11
            }
        }
        MouseArea {
            id: iconMa
            x: 0; y: (parent.height - height) / 2
            width: di.size; height: di.size
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function (e) {
                if (e.button === Qt.MiddleButton) di.middle()
                else if (e.button === Qt.RightButton) { if (di.app) di.menu(di) }
                else di.picked()
            }
        }
    }

    // ── right-click menu, beside the icon ──
    Rectangle {
        id: menu
        property var app: null
        property real anchorY: 0
        visible: dock.menuOpen && app !== null && dock.shown
        x: shelf.x + shelf.width + 10
        y: Math.max(8, Math.min(dock.height - height - 8, anchorY - height / 2))
        width: 190
        height: menuCol.implicitHeight + 12
        radius: 12
        color: Qt.rgba(dock.root.paper.r, dock.root.paper.g, dock.root.paper.b, 0.95)
        border.width: 1
        border.color: Qt.rgba(dock.root.ink.r, dock.root.ink.g, dock.root.ink.b, 0.12)

        function openFor(app, item) {
            menu.app = app
            menu.anchorY = item.mapToItem(null, 0, item.height / 2).y
            dock.menuOpen = true
        }
        function close() { dock.menuOpen = false; hideDelay.restart() }

        readonly property var actions: !app ? [] : [
            { label: app.pinned ? "Remove from dock" : "Keep in dock", run: function () { app.pinned ? dock.unpin(app.id) : dock.pin(app.id) } },
            { label: "New window", run: function () { dock.launch(app) }, show: !!app.entry },
            { label: "Quit", run: function () { dock.quit(app) }, show: dock.windowsOf(app).length > 0 }
        ].filter(function (a) { return a.show !== false })

        Column {
            id: menuCol
            x: 6; y: 6
            width: parent.width - 12
            Repeater {
                model: menu.actions
                delegate: Rectangle {
                    required property var modelData
                    width: menuCol.width; height: 30; radius: 8
                    color: actMa.containsMouse ? dock.root.fillHover : "transparent"
                    UiText {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label
                        color: parent.modelData.label === "Quit" ? dock.root.barAlert : dock.root.ink
                        font.family: dock.root.mono; font.pixelSize: 12
                    }
                    MouseArea {
                        id: actMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { parent.modelData.run(); menu.close() }
                    }
                }
            }
        }
        // leaving the menu (and the shelf) closes it
        HoverHandler { onHoveredChanged: if (!hovered && !shelfHover.hovered) menuCloser.restart() }
        Timer { id: menuCloser; interval: 900; onTriggered: if (!shelfHover.hovered) menu.close() }
    }
}
