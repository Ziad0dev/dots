pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.ext.colors
import qs.ext.services as Services
// Quickshell builds a `qs.` module only for the directories imported by the
// files it scans (this folder's, and on through their imports). The features
// below are loaded by URL, so every ext directory is imported here (aliased,
// unused) for its files to see their siblings; this file lives at the root
// of rise for the same reason.
import qs.ext.Core as ExtCore
import qs.ext.colors as ExtColors
import qs.ext.components as ExtComponents
import qs.ext.modules.avatar as ExtModulesAvatar
import qs.ext.modules.cava as ExtModulesCava
import qs.ext.modules.desktoptheme as ExtModulesDesktoptheme
import qs.ext.modules.desktopwidgets as ExtModulesDesktopwidgets
import qs.ext.modules.expose as ExtModulesExpose
import qs.ext.modules.keybinds as ExtModulesKeybinds
import qs.ext.modules.lock as ExtModulesLock
import qs.ext.modules.lock.themes.abyss as ExtModulesLockThemesAbyss
import qs.ext.modules.lock.themes.arcade as ExtModulesLockThemesArcade
import qs.ext.modules.lock.themes.artdeco as ExtModulesLockThemesArtdeco
import qs.ext.modules.lock.themes.cosmos as ExtModulesLockThemesCosmos
import qs.ext.modules.lock.themes.cyberpunk as ExtModulesLockThemesCyberpunk
import qs.ext.modules.lock.themes.devaloka as ExtModulesLockThemesDevaloka
import qs.ext.modules.lock.themes.gothic as ExtModulesLockThemesGothic
import qs.ext.modules.lock.themes.newspaper as ExtModulesLockThemesNewspaper
import qs.ext.modules.lock.themes.observatory as ExtModulesLockThemesObservatory
import qs.ext.modules.lock.themes.siege as ExtModulesLockThemesSiege
import qs.ext.modules.lock.themes.terminal as ExtModulesLockThemesTerminal
import qs.ext.modules.lock.themes.wabisabi as ExtModulesLockThemesWabisabi
import qs.ext.modules.lock.themes.wasteland as ExtModulesLockThemesWasteland
import qs.ext.modules.lock.themes.xianxia as ExtModulesLockThemesXianxia
import qs.ext.modules.lock.themes.zen as ExtModulesLockThemesZen
import qs.ext.modules.lockthemes as ExtModulesLockthemes
import qs.ext.modules.network as ExtModulesNetwork
import qs.ext.modules.notepad as ExtModulesNotepad
import qs.ext.modules.notes as ExtModulesNotes
import qs.ext.modules.oracle as ExtModulesOracle
import qs.ext.modules.pet as ExtModulesPet
import qs.ext.modules.switcher as ExtModulesSwitcher
import qs.ext.modules.timer as ExtModulesTimer
import qs.ext.modules.wallpaper as ExtModulesWallpaper
import qs.ext.modules.workspacedisc as ExtModulesWorkspacedisc
import qs.ext.modules.workspacedisc.skins as ExtModulesWorkspacediscSkins
import qs.ext.services as ExtServices
import qs.ext.settings as ExtSettings
import qs.ext.utils as ExtUtils

// Everything rise took from dhrruvsharma/shell (GPL-3.0-or-later; see
// ext/README.md), hosted next to rise's own panels by VariantRoot:
//
//   desktop   the wallpaper drawn by rise with the desktop theme's layer over
//             it, desktop widgets (clocks, music, system, cava), the
//             workspace disc
//   overlays  the window switcher (ALT+TAB), the workspace exposé, the bar
//             pet's hub and speech bubble, the fullscreen visualizer
//   panels    the swatch-deck wallpaper picker, the keybinds editor, the
//             notes drawer, the notepad, the Wi-Fi fan / Bluetooth orbit
//             maps, and the desktop/lock/widget themes panel, in one
//             masked overlay on the popup screen
//
// Every feature sits behind its own loader, so a broken one costs only
// itself (and never the bar). IPC: see the handlers at the bottom.
Scope {
    id: ext

    // rise's Theme (VariantRoot)
    required property var theme

    function prepare() {
        // Single-screen panels go where rise's popups go (the focused monitor),
        // and rise's own popups make way.
        ext.theme.activateFocusedPopupScreen();
        ext.theme.closePopups();
    }

    Component.onCompleted: {
        // This instance owns the compositor side of desktop themes (the lock
        // screen instance only reads the choice).
        Services.DesktopTheme.manage = true;
        Services.ZenTheme.manage = true;
        // ext panels dock into rise's frame (FrameDock)
        Services.Rise.theme = ext.theme;
    }

    // rise re-read its palette (themectl): re-read colors.sh too, in case the
    // file watch missed the rename.
    Connections {
        target: ext.theme
        function onPaperChanged() { Colors.reload(); }
        function onInkChanged() { Colors.reload(); }
        function onColor01Changed() { Colors.reload(); }
        function onPaletteBorderChanged() { Colors.reload(); }
    }

    // ── Desktop ──────────────────────────────────────────────────────────
    // The wallpaper and the desktop theme's layer (no windows while a
    // wallpaper command is set in the picker's settings).
    LazyLoader { active: true; source: Qt.resolvedUrl("ext/modules/wallpaper/WallpaperLayer.qml") }
    LazyLoader { active: true; source: Qt.resolvedUrl("ext/modules/desktopwidgets/DesktopWidgetsLayer.qml") }
    LazyLoader { active: Services.WorkspaceDiscService.enabled; source: Qt.resolvedUrl("ext/modules/workspacedisc/WorkspaceDiscWindow.qml") }
    LazyLoader { id: cavaWidget; active: true; source: Qt.resolvedUrl("ext/modules/cava/CavaWidget.qml") }

    // The widgets' data sources poll only while their widget can be seen.
    readonly property bool widgetsCovered: Services.Hyprland.covered(Services.DesktopWidgets.screen)
    // Desktop widgets go where rise's bar is ("all": the first screen).
    Binding {
        target: Services.DesktopWidgets
        property: "screenName"
        value: ext.theme.barMonitor !== "all" ? ext.theme.barMonitor : ""
    }
    Binding {
        target: Services.Media
        property: "active"
        value: Services.DesktopWidgets.enabled("music") && !ext.widgetsCovered
    }
    Binding {
        target: Services.System
        property: "active"
        value: Services.DesktopWidgets.enabled("sysmon") && !ext.widgetsCovered
    }

    // ── Overlays with windows of their own ───────────────────────────────
    LazyLoader { active: true; source: Qt.resolvedUrl("ext/modules/switcher/WindowSwitcher.qml") }
    LazyLoader { active: true; source: Qt.resolvedUrl("ext/modules/expose/Expose.qml") }
    LazyLoader { active: true; source: Qt.resolvedUrl("ext/modules/pet/PetHub.qml") }
    LazyLoader { active: true; source: Qt.resolvedUrl("ext/modules/pet/PetBubble.qml") }

    // The fullscreen visualizer: bars along the bottom and the top.
    property bool visualizerOn: false
    LazyLoader {
        active: ext.visualizerOn
        source: Qt.resolvedUrl("ext/modules/cava/Visualizer.qml")
    }
    LazyLoader {
        active: ext.visualizerOn
        source: Qt.resolvedUrl("ext/modules/cava/VisualizerTop.qml")
    }

    // ── Panels ───────────────────────────────────────────────────────────
    // One overlay on the popup screen for the panels that upstream kept in
    // its shared panel surface. While none is up it shrinks to a pixel in
    // the corner instead of unmapping (a fresh map would steal focus).
    PanelWindow {
        id: overlay

        screen: ext.theme.activePopupScreen
        readonly property real screenW: screen ? screen.width : 1920
        readonly property real screenH: screen ? screen.height : 1080

        function shown(loader) {
            return loader.status === Loader.Ready && loader.item && loader.item.visible;
        }

        readonly property bool needed: shown(picker) || shown(keybinds) || shown(notes)
            || shown(notepad) || shown(network) || shown(themes) || shown(timer)
            || shown(avatar) || shown(oracle)
        // Panels that take typing (search, passwords, notes, the bind editor).
        readonly property bool wantsKeys: needed

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dots-ext-panels"
        WlrLayershell.keyboardFocus: wantsKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        implicitWidth: needed ? screenW : 1
        implicitHeight: needed ? screenH : 1
        anchors {
            top: true
            left: true
            bottom: needed
            right: needed
        }
        color: "transparent"

        mask: Region {
            Region { item: overlay.shown(picker) ? picker : null }
            Region { item: overlay.shown(keybinds) ? keybinds : null }
            Region { item: overlay.shown(notes) ? notes.item : null }
            Region { item: overlay.shown(notepad) ? notepad : null }
            Region { item: overlay.shown(network) ? network : null }
            Region { item: overlay.shown(themes) ? themes : null }
            Region { item: overlay.shown(timer) ? timer : null }
            Region { item: overlay.shown(avatar) ? avatar.item : null }
            Region { item: overlay.shown(oracle) ? oracle : null }
        }

        // Laid out on the whole screen whatever the surface's size (it grows
        // from and shrinks to the top-left corner, so nothing moves).
        Item {
            width: overlay.screenW
            height: overlay.screenH

            // Built per opening, destroyed once closed (their pictures and
            // lists go with them).
            Loader {
                id: picker
                anchors.fill: parent
                active: false
                focus: true
                source: Qt.resolvedUrl("ext/modules/wallpaper/Wallpaper.qml")
            }
            Loader {
                id: keybinds
                anchors.fill: parent
                active: false
                focus: true
                source: Qt.resolvedUrl("ext/modules/keybinds/KeybindsPanel.qml")
            }
            Loader {
                id: network
                anchors.fill: parent
                active: false
                focus: true
                source: Qt.resolvedUrl("ext/modules/network/NetworkPanel.qml")
            }
            Loader {
                id: themes
                anchors.fill: parent
                active: false
                focus: true
                source: Qt.resolvedUrl("ext/modules/lockthemes/LockThemesPanel.qml")
            }
            // Kept once built: they hold what's being typed.
            // The drawer sizes and places itself (docked in the frame's
            // bottom band; the Loader sits at the origin).
            Loader {
                id: notes
                active: false
                focus: true
                source: Qt.resolvedUrl("ext/modules/notes/NotesDrawer.qml")
            }
            Loader {
                id: notepad
                anchors.fill: parent
                active: false
                focus: true
                source: Qt.resolvedUrl("ext/modules/notepad/NotepadPanel.qml")
            }
            // The lock screens' avatar (~/Pictures/avatars → ~/.cache/current_avatar),
            // docked in the frame's bottom band.
            Loader {
                id: avatar
                anchors.fill: parent
                active: false
                source: Qt.resolvedUrl("ext/modules/avatar/AvatarPicker.qml")
            }
            // The local-model chat; kept once built (the conversation lives in
            // the Oracle service anyway).
            Loader {
                id: oracle
                anchors.fill: parent
                active: false
                focus: true
                source: Qt.resolvedUrl("ext/modules/oracle/OraclePanel.qml")
            }
            // A countdown keeps running while it's closed.
            Loader {
                id: timer
                anchors.fill: parent
                active: false
                focus: true
                source: Qt.resolvedUrl("ext/modules/timer/TimerPanel.qml")
            }
        }
    }

    // Unload a per-opening panel a moment after it has closed (its close
    // animation done), unless it was opened again meanwhile.
    component Unloader: Timer {
        required property Loader loader
        interval: 600
        onTriggered: {
            if (loader.item && !loader.item.visible) {
                loader.active = false;
                // its lists (the picker's are thousands of entries) are garbage
                // now: collect them while nothing is animating
                Qt.callLater(gc);
            }
        }
    }
    Unloader { id: pickerUnload; loader: picker }
    Unloader { id: keybindsUnload; loader: keybinds }
    Unloader { id: networkUnload; loader: network }
    Unloader { id: themesUnload; loader: themes }
    Connections {
        target: picker.item
        ignoreUnknownSignals: true
        function onVisibleChanged() { if (!picker.item.visible) pickerUnload.restart(); }
    }
    Connections {
        target: keybinds.item
        ignoreUnknownSignals: true
        function onVisibleChanged() { if (!keybinds.item.visible) keybindsUnload.restart(); }
    }
    Connections {
        target: network.item
        ignoreUnknownSignals: true
        function onOpenedChanged() { if (!network.item.opened) networkUnload.restart(); }
    }
    Connections {
        target: themes.item
        ignoreUnknownSignals: true
        function onVisibleChanged() { if (!themes.item.visible) themesUnload.restart(); }
    }

    // Loads a panel (synchronously, so `item` is there to call into).
    function load(loader) {
        if (!loader.active)
            loader.active = true;
        return loader.item;
    }

    // bluetoothd wants an answer (a pairing code, a device asking to
    // connect): bring up the Bluetooth map, where the question is.
    Connections {
        target: Services.Bluetooth
        function onRequestArrived() {
            ext.prepare();
            const p = ext.load(network);
            if (!p)
                return;
            p.currentTab = 1;
            p.opened = true;
        }
    }

    // ── IPC (qs -c rise ipc call <target> <function>) ────────────────────
    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            const p = picker.item;
            if (p && p.visible && !p.closing) {
                p.close();
                return;
            }
            ext.prepare();
            ext.load(picker).open();
        }
        function wallhaven(): void {
            ext.prepare();
            const p = ext.load(picker);
            p.open();
            p.setMode("wallhaven");
        }
        // Set (and record, through themectl) a wallpaper.
        function set(path: string): void { Services.WallpaperEngine.set(path); }
        // Display only; true when rise draws it (see WallpaperEngine).
        // (not `show`: qs's CLI takes that for its own `ipc show`)
        function display(path: string): bool { return Services.WallpaperEngine.show(path); }
        function current(): string { return Services.WallpaperEngine.current; }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            const p = keybinds.item;
            if (p && p.visible) {
                p.close();
                return;
            }
            ext.prepare();
            ext.load(keybinds).open();
        }
        function open(): void {
            ext.prepare();
            const p = ext.load(keybinds);
            if (!p.visible)
                p.open();
        }
        function close(): void {
            if (keybinds.item && keybinds.item.visible)
                keybinds.item.close();
        }
    }

    IpcHandler {
        target: "notes"
        function toggle(): void {
            const p = notes.item;
            if (p && p.opened) {
                p.opened = false;
                return;
            }
            ext.prepare();
            ext.load(notes).opened = true;
        }
    }

    IpcHandler {
        target: "notepad"
        function toggle(): void {
            if (!notepad.item || !notepad.item.visible)
                ext.prepare();
            ext.load(notepad).toggle();
        }
    }

    IpcHandler {
        target: "avatarPicker"
        function toggle(): void {
            const p = avatar.item;
            if (p && p.opened) {
                p.close();
                return;
            }
            ext.prepare();
            ext.load(avatar).open();
        }
    }

    IpcHandler {
        target: "oracle"
        function toggle(): void {
            if (!oracle.item || !oracle.item.visible)
                ext.prepare();
            ext.load(oracle).toggle();
        }
        // scripting: wake a dots-llm backend, ask, read the last answer
        function wake(unit: string): void { Services.Oracle.wake(unit); }
        function ask(text: string): void { Services.Oracle.send(text); }
        function last(): string {
            const m = Services.Oracle.messages;
            if (!m.length)
                return "";
            const l = m[m.length - 1];
            return l.role + ": " + (l.content || (l.thinking ? "(pondering, " + l.thinking.length + " chars)" : ""));
        }
        function state(): string {
            Services.Oracle.refresh();
            return (Services.Oracle.backend || "none") + (Services.Oracle.ready ? " ready " + Services.Oracle.model : Services.Oracle.waking ? " waking" : "");
        }
        function sleep(): void { Services.Oracle.sleep(); }
    }

    IpcHandler {
        target: "timer"
        function toggle(): void {
            if (!timer.item || !timer.item.visible)
                ext.prepare();
            ext.load(timer).toggle();
        }
    }

    IpcHandler {
        target: "networkMap"
        // tab: "wifi", "bluetooth" or "" (toggle on the last one)
        function changeVisible(tab: string): void {
            const open = network.item && network.item.opened;
            if (open) {
                network.item.opened = false;
                return;
            }
            ext.prepare();
            const p = ext.load(network);
            if (tab === "wifi")
                p.currentTab = 0;
            else if (tab === "bluetooth")
                p.currentTab = 1;
            p.opened = true;
        }
    }

    function themesPanel() {
        ext.prepare();
        return ext.load(themes);
    }

    IpcHandler {
        target: "themes"
        function toggle(): void {
            if (themes.item && themes.item.visible)
                themes.item.close();
            else
                ext.themesPanel().open();
        }
        function desktop(): void {
            if (themes.item && themes.item.visible && themes.item.tab === "desktop")
                themes.item.close();
            else
                ext.themesPanel().openTab("desktop");
        }
        function lockscreen(): void { ext.themesPanel().openTab("lock"); }
        function widgets(): void { ext.themesPanel().openTab("widgets"); }
    }

    IpcHandler {
        target: "desktopTheme"
        function toggle(): void { Services.DesktopTheme.toggle(); }
        function enable(): void {
            if (!Services.DesktopTheme.enabled)
                Services.DesktopTheme.toggle();
        }
        function set(theme: string): void { Services.DesktopTheme.setTheme(theme); }
        function disable(): void { Services.DesktopTheme.setTheme(""); }
        function screenEffect(mode: string): void { Services.DesktopTheme.setScreenEffect(mode); }
        function current(): string { return Services.DesktopTheme.theme; }
    }

    IpcHandler {
        target: "widgets"
        function toggle(): void {
            if (themes.item && themes.item.visible && themes.item.tab === "widgets")
                themes.item.close();
            else
                ext.themesPanel().openTab("widgets");
        }
        function enable(id: string): void { Services.DesktopWidgets.setEnabled(id, true); }
        function disable(id: string): void { Services.DesktopWidgets.setEnabled(id, false); }
        function reset(): void { Services.DesktopWidgets.resetPositions(); }
    }

    IpcHandler {
        target: "lockscreen"
        function toggle(): void {
            if (themes.item && themes.item.visible && themes.item.tab === "lock")
                themes.item.close();
            else
                ext.themesPanel().openTab("lock");
        }
        function lock(): void { Quickshell.execDetached(["loginctl", "lock-session"]); }
        // Which lock hypridle starts (ext/scripts/lock): "themed" (these lock
        // screens) or "classic" (quickshell -c lock).
        function engine(which: string): void {
            if (which === "themed" || which === "classic")
                Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" > \"${XDG_STATE_HOME:-$HOME/.local/state}/dots/shell/ext/lock-engine\"", "sh", which]);
        }
        function currentEngine(): string { return lockEngine.text().trim() || "classic"; }
        function preview(theme: string): void { ext.load(themes).preview(theme); }
    }

    FileView {
        id: lockEngine
        path: Quickshell.env("HOME") + "/.local/state/dots/shell/ext/lock-engine"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    IpcHandler {
        target: "cavaWidget"
        function toggle(): void { cavaWidget.item.toggle(); }
        function edit(): void { cavaWidget.item.edit(); }
        function reset(): void { Services.CavaWidget.reset(); }
    }

    IpcHandler {
        target: "workspaceDisc"
        function toggle(): void { Services.WorkspaceDiscService.toggle(); }
    }

    IpcHandler {
        target: "visualizer"
        function toggle(): void { ext.visualizerOn = !ext.visualizerOn; }
    }

    IpcHandler {
        target: "pet"
        function toggle(): void { Services.Pet.toggleHub(); }
        function open(): void {
            if (!Services.Pet.hubOpen)
                Services.Pet.toggleHub();
        }
        function close(): void { Services.Pet.hubOpen = false; }
        function say(text: string): void { Services.Pet.say(text); }
        function pat(): void { Services.Pet.pat(); }
        function feed(): void { Services.Pet.feed(); }
        function play(): void { Services.Pet.play(); }
        function nap(): void { Services.Pet.nap(); }
        function wake(): void { Services.Pet.act("wake"); }
        // (not `show`: qs's CLI takes that for its own `ipc show`)
        function appear(): void { Services.Pet.setShown(true); }
        function hide(): void { Services.Pet.setShown(false); }
    }
}
