pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "modules"

// A macOS-style dock after Omarchy 4.5's (shell/plugins/dock): pinned apps,
// then everything running, an apps button that opens the launcher, a dot per
// window, magnification under the pointer. Click opens, focuses, or cycles an
// app's windows; middle-click opens a new window; right-click keeps or removes
// it, or quits it.
//
// Settings → Bar → Dock (`dockMode`): "autohide" (default: every workspace,
// hidden until the pointer touches the bottom edge, no space taken),
// "floating" (Omarchy's: always on floating workspaces only), "always" (a
// reserved strip), "off". Pins: desktop ids, one per line, in
// ~/.local/state/dots/dock-pins. Windows come from the Wayland toplevel list,
// which activates and closes them itself.
PanelWindow {
    id: dock
    required property var root

    readonly property string mode: root.dockMode
    readonly property int iconSize: 44
    readonly property int maxIcon: 74
    readonly property int pad: 8
    readonly property int edge: (root.frameOn ? root.frameThickness : 0) + 8
    readonly property int dockH: iconSize + 2 * pad + 8

    // ── when it shows ──
    readonly property var monitor: Hyprland.monitorFor(dock.screen)
    readonly property var workspace: monitor ? monitor.activeWorkspace : null
    readonly property bool fullscreen: !!workspace && workspace.hasFullscreen
    readonly property bool onFloating: !!workspace && root.wsLayoutOf(workspace.id) === "floating"
    property bool edgeHovered: false
    property bool dockHovered: false
    property bool menuOpen: false
    readonly property bool wanted: mode === "always" || (mode === "floating" && onFloating)
        || (mode === "autohide" && (edgeHovered || dockHovered || hideDelay.running || menuOpen))
    readonly property bool shown: mode !== "off" && !fullscreen && (wanted || dockHovered || menuOpen)
    Timer { id: hideDelay; interval: 700 }

    visible: mode !== "off" && !(mode === "floating" && !onFloating)
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: dockH + edge + maxIcon - iconSize + 40     // room to magnify and for the menu
    exclusionMode: mode === "always" ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: mode === "always" ? dockH + edge : 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dots-dock"
    // input: the dock (and its menu) while shown; a 2px strip along the bottom
    // edge while hidden, which is what calls it up
    mask: Region {
        item: dock.shown ? hitArea : edgeStrip
    }

    Item {
        id: edgeStrip
        anchors.bottom: parent.bottom
        width: parent.width; height: 2
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

    // ── the dock ──
    Item {
        id: hitArea
        x: Math.round((dock.width - width) / 2)
        width: shelf.width
        height: dock.height - y
        y: dock.height - dock.edge - dock.dockH - (dock.maxIcon - dock.iconSize) - (menu.visible ? menu.height + 8 : 0)
        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                dock.dockHovered = hovered
                if (!hovered) hideDelay.restart()
            }
        }
    }

    Rectangle {
        id: shelf
        property real slide: dock.shown ? 0 : dock.dockH + dock.edge + 6
        x: Math.round((dock.width - width) / 2)
        y: dock.height - dock.edge - dock.dockH + slide
        Behavior on slide { Anim { kind: "spatialFast" } }
        opacity: dock.shown ? 1 : 0
        Behavior on opacity { Anim { kind: "effects"; ms: 160 } }
        width: row.width + 2 * dock.pad + 8
        height: dock.dockH
        // glass: a see-through tint over Hyprland's blur (the dots-* layer
        // rule), a hairline border and a soft light along the top edge
        radius: 22
        color: Qt.rgba(dock.root.paper.r, dock.root.paper.g, dock.root.paper.b, dock.root.glassMode ? 0.22 : 0.34)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        // the pointer's x in the window, for magnification (-1: not hovering).
        // Icons measure from where their slot would be unmagnified: measuring
        // from their own (magnified) place fed back into their size.
        readonly property real mx: dockHover.hovered ? dockHover.point.scenePosition.x : -1
        readonly property int gap: 6
        readonly property real baseWidth: dock.iconSize + gap + 1 + gap
            + dock.apps.length * dock.iconSize + Math.max(0, dock.apps.length - 1) * gap
        function slotCentre(slot) {
            const left = dock.width / 2 - baseWidth / 2
            if (slot === 0) return left + dock.iconSize / 2
            return left + dock.iconSize + gap + 1 + gap + (slot - 1) * (dock.iconSize + gap) + dock.iconSize / 2
        }

        Row {
            id: row
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: dock.pad + 4
            spacing: shelf.gap

            // the apps button: the launcher's grid of every app
            DockIcon {
                slot: 0
                iconName: ""
                glyph: "apps"
                label: "Apps"
                onPicked: Quickshell.execDetached(["qs", "-c", "rise", "ipc", "call", "launcher", "toggle"])
            }
            Rectangle {
                width: 1; height: dock.iconSize * 0.7
                anchors.bottom: parent.bottom; anchors.bottomMargin: dock.iconSize * 0.15
                color: Qt.rgba(dock.root.ink.r, dock.root.ink.g, dock.root.ink.b, 0.15)
            }
            Repeater {
                model: dock.apps
                delegate: DockIcon {
                    required property var modelData
                    required property int index
                    slot: index + 1
                    readonly property var wins: dock.windowsOf(modelData)
                    app: modelData
                    iconName: modelData.entry ? modelData.entry.icon : (modelData.appId || "")
                    label: modelData.entry ? modelData.entry.name : (modelData.appId || "")
                    windows: wins.length
                    focused: wins.some(function (t) { return t.activated })
                    bouncing: dock.bouncing[modelData.id] !== undefined
                    faded: modelData.pinned && wins.length === 0
                    onPicked: dock.activate(modelData)
                    onMiddle: dock.launch(modelData)
                    onMenu: function (item) { menu.openFor(modelData, item) }
                }
            }
        }
    }

    // one icon, magnified by the pointer's distance
    component DockIcon: Item {
        id: di
        property var app: null
        property string iconName: ""
        property string glyph: ""
        property string label: ""
        property int windows: 0
        property bool focused: false
        property bool faded: false
        property bool bouncing: false
        // the launch bounce: up and back, again and again (macOS)
        property real hop: 0
        SequentialAnimation on hop {
            running: di.bouncing
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: -18; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { to: 0; duration: 260; easing.type: Easing.InQuad }
            PauseAnimation { duration: 120 }
        }
        signal picked()
        signal middle()
        signal menu(var item)
        property int slot: 0
        readonly property real dist: shelf.mx < 0 ? 1e9 : Math.abs(shelf.mx - shelf.slotCentre(slot))
        readonly property real grow: Math.max(0, 1 - dist / 140)
        readonly property real size: dock.iconSize + (dock.maxIcon - dock.iconSize) * grow * grow
        width: size
        height: size + 8
        Behavior on width { enabled: shelf.mx >= 0; Anim { kind: "spatialFast" } }

        Image {
            id: img
            visible: di.glyph === ""
            width: di.size - 4; height: width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: dots.top; anchors.bottomMargin: 2 - di.hop
            source: di.glyph === "" ? Quickshell.iconPath(di.iconName, "application-x-executable") : ""
            sourceSize: Qt.size(128, 128)
            smooth: true; mipmap: true
            opacity: di.faded ? 0.55 : 1
        }
        IconText {
            visible: di.glyph !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: dots.top; anchors.bottomMargin: 2
            text: di.glyph
            font.pixelSize: di.size * 0.62
            color: dock.root.ink
        }
        // running: one dot, as on macOS; the accent while it has focus
        Item {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 4; height: 4
            Rectangle {
                anchors.fill: parent
                radius: 2
                visible: di.windows > 0
                color: di.focused ? dock.root.seal : Qt.rgba(dock.root.ink.r, dock.root.ink.g, dock.root.ink.b, 0.75)
            }
        }
        // the name, over the icon while hovered
        Rectangle {
            visible: iconMa.containsMouse && di.label !== "" && !menu.visible
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height - 8
            width: tip.implicitWidth + 14; height: tip.implicitHeight + 6
            radius: 8
            color: Qt.rgba(dock.root.paper.r, dock.root.paper.g, dock.root.paper.b, 0.78)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
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
            anchors.fill: parent
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

    // ── right-click menu ──
    Rectangle {
        id: menu
        property var app: null
        property real anchorX: 0
        visible: dock.menuOpen && app !== null
        x: Math.max(8, Math.min(dock.width - width - 8, anchorX - width / 2))
        y: shelf.y - height - (dock.maxIcon - dock.iconSize) - 10
        width: 190
        height: menuCol.implicitHeight + 12
        radius: 12
        color: Qt.rgba(dock.root.paper.r, dock.root.paper.g, dock.root.paper.b, 0.95)
        border.width: 1
        border.color: Qt.rgba(dock.root.ink.r, dock.root.ink.g, dock.root.ink.b, 0.12)

        function openFor(app, item) {
            menu.app = app
            menu.anchorX = item.mapToItem(null, item.width / 2, 0).x
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
        // a click anywhere else on the dock closes it
        HoverHandler { onHoveredChanged: if (!hovered && !dockHover.hovered) menuCloser.restart() }
        Timer { id: menuCloser; interval: 900; onTriggered: if (!dockHover.hovered) menu.close() }
    }
}
