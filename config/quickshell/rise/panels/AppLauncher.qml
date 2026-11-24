import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../modules"
import "../modules/Calc.js" as Calc

PanelWindow {
    id: win
    required property var root

    visible: root.appLauncherVisible
    screen: root.activePopupScreen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-launcher"
    WlrLayershell.keyboardFocus: root.appLauncherVisible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }

    property int sel: 0
    property string query: ""

    readonly property color island: Qt.rgba(
        root.paper.r + (root.ink.r - root.paper.r) * 0.07,
        root.paper.g + (root.ink.g - root.paper.g) * 0.07,
        root.paper.b + (root.ink.b - root.paper.b) * 0.07, root.glassMode ? 0.55 : 1.0)

    readonly property var apps: {
        var all = []
        var vals = DesktopEntries.applications.values
        for (var i = 0; i < vals.length; i++)
            if (vals[i].name && !vals[i].noDisplay) all.push(vals[i])
        all.sort(function (a, b) { return a.name.localeCompare(b.name) })

        var q = query.trim().toLowerCase()
        if (q === "") return all

        var scored = []
        for (var j = 0; j < all.length; j++) {
            var d = all[j]
            var name = (d.name || "").toLowerCase()
            var gen = (d.genericName || "").toLowerCase()
            var com = (d.comment || "").toLowerCase()
            var kw = (d.keywords || []).join(" ").toLowerCase()
            var cat = (d.categories || []).join(" ").toLowerCase()
            var s = -1
            if (name.indexOf(q) === 0) s = 0
            else if (name.indexOf(q) >= 0) s = 1
            else if (gen.indexOf(q) >= 0) s = 2
            else if (kw.indexOf(q) >= 0) s = 3
            else if (com.indexOf(q) >= 0 || cat.indexOf(q) >= 0) s = 4
            if (s >= 0) scored.push({ e: d, s: s })
        }
        scored.sort(function (a, b) {
            if (a.s !== b.s) return a.s - b.s
            return a.e.name.localeCompare(b.e.name)
        })
        var out = []
        for (var k = 0; k < scored.length; k++) out.push(scored[k].e)
        return out
    }

    // ── calculator: maths in the query shows "= result" first; Enter copies it ──
    readonly property string calcResult: {
        var v = Calc.evaluate(query)
        return v === null ? "" : Calc.format(v)
    }

    // ── actions: ">" lists shell actions, filtered by what follows ──
    readonly property bool actionMode: query.trim().charAt(0) === ">"
    function openPopup(prop) { close(); root.activateFocusedPopupScreen(); root[prop] = true }
    function sh(args) { close(); Quickshell.execDetached(args) }
    readonly property var actions: [
        { name: "Settings", comment: "every bar setting (SUPER+,)", glyph: "\uE8B8", run: function () { win.openPopup("settingsVisible") } },
        { name: "Lock", comment: "lock the screen", glyph: "\uE897", run: function () { win.sh(["loginctl", "lock-session"]) } },
        { name: "Suspend", comment: "sleep now", glyph: "\uEF44", run: function () { win.sh(["systemctl", "suspend"]) } },
        { name: "Log out", comment: "leave Hyprland", glyph: "\uE9BA", run: function () { win.openPopup("sessionVisible") } },
        { name: "Restart", comment: "via the session menu (confirms)", glyph: "\uF053", run: function () { win.openPopup("sessionVisible") } },
        { name: "Shut down", comment: "via the session menu (confirms)", glyph: "\uE8AC", run: function () { win.openPopup("sessionVisible") } },
        { name: "Dashboard", comment: "clock, weather, media, resources", glyph: "\uE871", run: function () { win.openPopup("dashboardVisible") } },
        { name: "Notifications", comment: "notification centre", glyph: "\uE7F4", run: function () { win.openPopup("notifVisible") } },
        { name: "Utilities", comment: "quick toggles and captures", glyph: "\uE1BD", run: function () { win.openPopup("utilitiesVisible") } },
        { name: "Themes", comment: "theme / wallpaper drawer", glyph: "\uE40A", run: function () { win.openPopup("drawerVisible") } },
        { name: "Wallpapers", comment: "wallpaper picker", glyph: "\uE1BC", run: function () { win.close(); root.ipcOpenPicker("wallpaper") } },
        { name: "Clipboard", comment: "clipboard history", glyph: "\uE14F", run: function () { win.openPopup("clipboardVisible") } },
        { name: "Overview", comment: "all workspaces", glyph: "\uE9B0", run: function () { win.openPopup("overviewVisible") } },
        { name: "Settings", comment: "bar control panel", glyph: "\uE8B8", run: function () { win.openPopup("controlVisible") } },
        { name: "Screenshot", comment: "select a region", glyph: "\uF7D2", run: function () { win.sh(["bash", "-c", "sleep 0.3; dots-shot region"]) } },
        { name: "Night light", comment: "toggle", glyph: "\uF03D", run: function () { win.sh(["dots-nightlight", "toggle"]) } },
        { name: "Silence", comment: "toggle do-not-disturb", glyph: "\uE7F6", run: function () {
            win.sh(["bash", "-c", "command -v dots-toggle-notification-silencing >/dev/null && exec dots-toggle-notification-silencing; exec dots toggle notification silencing"]) } }
    ]

    // ── the menu (dots-menu, SUPER + ALT + Space), after Omarchy's: sections
    // open with Enter, Backspace on an empty search goes back, and typing
    // searches every entry of every section. Entries run what their own keys
    // run. Commands are argument lists, never shell text with values in it.
    property bool menuMode: false
    property var menuStack: []          // the sections opened, outermost first
    function term(args) {               // things that ask for a password or want watching
        win.sh(["ghostty", "--class=com.dots.float.md", "-e", "bash", "-c",
            "\"$@\"; echo; read -rp 'Done. Enter closes this window.'", "_"].concat(args))
    }
    function later(args) {              // after the panel has gone (captures)
        win.sh(["bash", "-c", "sleep 0.3; exec \"$@\"", "_"].concat(args))
    }
    function ipc(args) { win.sh(["qs", "-c", "rise", "ipc", "call"].concat(args)) }
    // the checkout (dots.repoPath, from the bar's unit): DOTS_DIR is the
    // read-only store copy when liveConfig is off
    readonly property string dotsDir: Quickshell.env("DOTS_REPO") || (Quickshell.env("HOME") + "/dots")
    readonly property var menuTree: [
        { name: "Apps", comment: "search and launch", glyph: "apps", run: function () { win.menuMode = false; win.menuStack = []; input.text = "" } },
        { name: "Learn", comment: "keybindings, docs", glyph: "school", children: [
            { name: "Keybindings", comment: "every key (SUPER + /)", glyph: "keyboard", run: function () { win.ipc(["keybinds", "toggle"]) } },
            { name: "Dots docs", comment: "this setup's guide", glyph: "menu_book", run: function () { win.sh(["xdg-open", win.dotsDir + "/docs/README.md"]) } },
            { name: "Hyprland wiki", comment: "wiki.hypr.land", glyph: "public", run: function () { win.sh(["xdg-open", "https://wiki.hypr.land"]) } },
            { name: "NixOS options", comment: "search.nixos.org", glyph: "public", run: function () { win.sh(["xdg-open", "https://search.nixos.org/options"]) } },
            { name: "Home Manager options", comment: "home-manager-options.extranix.com", glyph: "public", run: function () { win.sh(["xdg-open", "https://home-manager-options.extranix.com"]) } }
        ] },
        { name: "Capture", comment: "screenshots, recording, colours", glyph: "photo_camera", children: [
            { name: "Screenshot area", comment: "Print", glyph: "crop", run: function () { win.later(["dots-shot", "region"]) } },
            { name: "Screenshot screen", comment: "SUPER + Print", glyph: "desktop_windows", run: function () { win.later(["dots-shot", "screen"]) } },
            { name: "Screenshot window", comment: "SUPER + SHIFT + S", glyph: "web_asset", run: function () { win.later(["dots-shot", "window"]) } },
            { name: "Record screen", comment: "start", glyph: "radio_button_checked", run: function () { win.later(["dots-capture-screenrecording"]) } },
            { name: "Record area", comment: "pick a region", glyph: "screenshot_region", run: function () { win.later(["dots-capture-screenrecording", "--region"]) } },
            { name: "Stop recording", comment: "save it", glyph: "stop_circle", run: function () { win.sh(["dots-capture-screenrecording", "--stop"]) } },
            { name: "Colour picker", comment: "hex to the clipboard (SUPER + SHIFT + C)", glyph: "colorize", run: function () { win.later(["hyprpicker", "-a", "-n", "-f", "hex"]) } },
            { name: "Identify song", comment: "what's playing (SUPER + ALT + M)", glyph: "music_note", run: function () { win.sh(["dots-songrec"]) } },
            { name: "Google Lens", comment: "search a region (SUPER + ALT + G)", glyph: "image_search", run: function () { win.later(["dots-lens"]) } }
        ] },
        { name: "Share", comment: "LocalSend, clipboard, emoji", glyph: "share", children: [
            { name: "LocalSend", comment: "files and text to devices on the LAN", glyph: "send_to_mobile", run: function () { win.sh(["localsend_app"]) } },
            { name: "Clipboard history", comment: "SUPER + SHIFT + V", glyph: "content_paste", run: function () { win.openPopup("clipboardVisible") } },
            { name: "Emoji", comment: "SUPER + .", glyph: "mood", run: function () { win.later(["bemoji", "-n", "-t"]) } }
        ] },
        { name: "Toggle", comment: "game mode, night light, silence…", glyph: "toggle_on", children: [
            { name: "Game mode", comment: root.gameMode ? "on (SUPER + CTRL + G)" : "off (SUPER + CTRL + G)", glyph: "sports_esports", run: function () { win.sh(["dots-look", "game", "toggle"]) } },
            { name: "Night light", comment: "SUPER + N", glyph: "nightlight", run: function () { win.sh(["dots-nightlight", "toggle"]) } },
            { name: "Do not disturb", comment: root.notifSilenced ? "on" : "off", glyph: "do_not_disturb_on", run: function () { win.sh(["dots-toggle-notification-silencing"]) } },
            { name: "Stay awake", comment: "no idle lock", glyph: "coffee", run: function () { win.sh(["dots-toggle-idle"]) } },
            { name: "Glass", comment: root.glassMode ? "on (SUPER + ALT + V)" : "off (SUPER + ALT + V)", glyph: "blur_on", run: function () { win.sh(["dots-look", "glass", "toggle"]) } },
            { name: "Blur", comment: "SUPER + ALT + B", glyph: "blur_circular", run: function () { win.sh(["dots-look", "blur", "toggle"]) } },
            { name: "Screensaver now", comment: "any key or the pointer ends it", glyph: "bedtime", run: function () { win.later(["dots-screensaver", "start"]) } }
        ] },
        { name: "Style", comment: "theme, wallpaper, layout", glyph: "palette", children: [
            { name: "Theme", comment: "picker", glyph: "palette", run: function () { win.close(); root.ipcOpenPicker("theme") } },
            { name: "Next theme", comment: "SUPER + SHIFT + T", glyph: "skip_next", run: function () { win.sh(["themectl", "next"]) } },
            { name: "Wallpaper", comment: "picker (SUPER + E)", glyph: "wallpaper", run: function () { win.close(); root.ipcOpenPicker("wallpaper") } },
            { name: "Next wallpaper", comment: "SUPER + CTRL + E", glyph: "skip_next", run: function () { win.sh(["themectl", "bg", "next"]) } },
            { name: "Theme drawer", comment: "SUPER + W", glyph: "style", run: function () { win.openPopup("drawerVisible") } },
            { name: "Layout: tiling", comment: "this workspace", glyph: "dashboard", run: function () { win.sh(["dots-layout", "set", "tiling"]) } },
            { name: "Layout: scrolling", comment: "this workspace", glyph: "view_week", run: function () { win.sh(["dots-layout", "set", "scrolling"]) } },
            { name: "Layout: floating", comment: "this workspace", glyph: "filter_none", run: function () { win.sh(["dots-layout", "set", "floating"]) } }
        ] },
        { name: "Setup", comment: "settings, audio", glyph: "tune", children: [
            { name: "Settings", comment: "every bar setting (SUPER + ,)", glyph: "settings", run: function () { win.openPopup("settingsVisible") } },
            { name: "Settings app", comment: "SUPER + CTRL + I", glyph: "settings_applications", run: function () { win.ipc(["nexus", "toggle"]) } },
            { name: "Audio mixer", comment: "wiremix", glyph: "volume_up", run: function () { win.sh(["ghostty", "--class=com.dots.float.md", "-e", "wiremix"]) } }
        ] },
        { name: "Web apps", comment: "a website as an app", glyph: "language", children: [
            { name: "Install web app…", comment: "name, address, icon", glyph: "add_circle", run: function () { win.sh(["ghostty", "--class=com.dots.float.sm", "-e", "dots-webapp", "add"]) } },
            { name: "Remove web app…", comment: "pick one", glyph: "remove_circle", run: function () { win.sh(["ghostty", "--class=com.dots.float.sm", "-e", "dots-webapp", "pick-remove"]) } }
        ] },
        { name: "Update", comment: "rebuild, flatpaks", glyph: "system_update", children: [
            { name: "Rebuild system", comment: "nh os switch", glyph: "build", run: function () { win.term(["nh", "os", "switch", win.dotsDir]) } },
            { name: "Update inputs and rebuild", comment: "nh os switch --update", glyph: "update", run: function () { win.term(["nh", "os", "switch", "--update", win.dotsDir]) } },
            { name: "Update Flatpak apps", comment: "flatpak update", glyph: "apps", run: function () { win.term(["flatpak", "update"]) } },
            { name: "Restart the bar", comment: "systemctl --user restart quickshell", glyph: "restart_alt", run: function () { win.sh(["systemctl", "--user", "restart", "quickshell"]) } }
        ] },
        { name: "System", comment: "lock, screensaver, power", glyph: "power_settings_new", children: [
            { name: "Lock", comment: "SUPER + L", glyph: "lock", run: function () { win.sh(["loginctl", "lock-session"]) } },
            { name: "Screensaver", comment: "any key or the pointer ends it", glyph: "bedtime", run: function () { win.later(["dots-screensaver", "start"]) } },
            { name: "Power…", comment: "log out, restart, shut down", glyph: "power_settings_new", run: function () { win.openPopup("sessionVisible") } }
        ] }
    ]
    readonly property var menuNode: menuStack.length ? menuStack[menuStack.length - 1].children : menuTree
    readonly property string menuTitle: "Menu" + menuStack.map(function (n) { return "  ›  " + n.name }).join("")
    function menuEntry(n, path) {
        return { kind: n.children ? "menu" : "menuitem", name: n.name,
                 comment: path ? path + "  ·  " + n.comment : n.comment, glyph: n.glyph, node: n }
    }
    function menuBack() {
        if (menuStack.length === 0) return false
        menuStack = menuStack.slice(0, -1)
        return true
    }

    // one list for the view: { kind: app | calc | action | menu | menuitem, name, comment, icon | glyph }
    readonly property var entries: {
        if (menuMode) {
            var mq = query.trim().toLowerCase()
            if (mq === "") return menuNode.map(function (n) { return win.menuEntry(n, "") })
            // a search reaches every entry, each with its section
            var found = []
            var walk = function (nodes, path) {
                for (var i = 0; i < nodes.length; i++) {
                    var n = nodes[i]
                    if (n.name.toLowerCase().indexOf(mq) >= 0 || n.comment.toLowerCase().indexOf(mq) >= 0)
                        found.push(win.menuEntry(n, path))
                    if (n.children) walk(n.children, path ? path + " › " + n.name : n.name)
                }
            }
            walk(menuNode, "")
            return found
        }
        if (actionMode) {
            var q = query.trim().slice(1).trim().toLowerCase()
            return actions.filter(function (a) {
                return q === "" || a.name.toLowerCase().indexOf(q) >= 0 || a.comment.indexOf(q) >= 0
            }).map(function (a) { return { kind: "action", name: a.name, comment: a.comment, glyph: a.glyph, action: a } })
        }
        var out = apps.map(function (d) {
            return { kind: "app", name: d.name || "", comment: d.comment || d.genericName || "", icon: d.icon || "", entry: d }
        })
        if (calcResult !== "")
            out.unshift({ kind: "calc", name: "= " + calcResult, comment: query.trim() + "   ·   Enter copies", glyph: "\uEA5F" })
        return out
    }

    onEntriesChanged: sel = 0

    function close() {
        root.appLauncherVisible = false
        query = ""
        sel = 0
        menuMode = false
        menuStack = []
    }

    function launch() {
        if (sel < 0 || sel >= entries.length) return
        var e = entries[sel]
        if (e.kind === "calc") { Quickshell.execDetached(["wl-copy", calcResult]); close(); return }
        if (e.kind === "action") { e.action.run(); return }
        if (e.kind === "menu") { menuStack = menuStack.concat([e.node]); input.text = ""; sel = 0; return }
        if (e.kind === "menuitem") { e.node.run(); return }

        // Each app gets its own app-*.scope; a plain execute() leaves it in
        // quickshell.service's cgroup, where e.g. ~100 processes of a single app were
        // billed to the bar (a 6.7 GB "peak") and outlived bar restarts there.
        // Flatpaks keep the DesktopEntry's own execute(): systemd-run --scope
        // breaks them (Tauon, etc.) on NixOS, and `flatpak run` moves itself
        // into its own app-flatpak-*.scope anyway. Terminal entries too.
        var cmd = e.entry.command
        if (e.entry.runInTerminal || !cmd || cmd.length === 0
                || /(^|\/)flatpak$/.test(cmd[0])) {
            e.entry.execute()
        } else {
            var unit = "app-dots-" + String(e.entry.id).replace(/[^A-Za-z0-9:_.-]/g, "_")
                + "-" + Date.now().toString(36)
            var dir = e.entry.workingDirectory
            Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect",
                "--slice=app.slice", "--unit=" + unit, "--"]
                .concat(dir ? ["env", "-C", dir] : []).concat(cmd))
        }
        close()
    }

    function move(d) {
        var n = entries.length
        if (n === 0) return
        sel = (sel + d + n) % n
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(720, win.width - 80)
        height: Math.min(560, win.height - 120)
        radius: 12
        color: root.cardFill
        border.width: 1
        border.color: root.sep

        MouseArea { anchors.fill: parent }

        Rectangle {
            id: field
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            height: 42
            radius: 6
            color: win.island
            border.width: 1
            border.color: root.sep

            Text {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                text: "\u2315"
                font.family: root.mono
                font.pixelSize: 16
                color: root.sumiHi
            }

            TextInput {
                id: input
                anchors {
                    left: parent.left; leftMargin: 40
                    right: parent.right; rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                color: root.ink
                font.family: root.mono
                font.pixelSize: 14
                selectByMouse: true
                selectionColor: root.seal
                clip: true
                onTextChanged: win.query = text

                Text {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: win.menuMode
                        ? win.menuTitle + (win.menuStack.length ? "  ·  ⌫ back" : "  ·  type to search everything")
                        : "search apps  ·  type maths  ·  > for actions"
                    font: input.font
                    color: root.sumiHi
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onPressed: function (e) {
                    if (e.key === Qt.Key_Escape) { win.close(); e.accepted = true }
                    else if (e.key === Qt.Key_Backspace && input.text === "" && win.menuMode && win.menuBack()) { win.sel = 0; e.accepted = true }
                    else if (e.key === Qt.Key_Down || (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier))) { win.move(1); e.accepted = true }
                    else if (e.key === Qt.Key_Up || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))) { win.move(-1); e.accepted = true }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.launch(); e.accepted = true }
                    else if (e.key === Qt.Key_PageDown) { win.move(8); e.accepted = true }
                    else if (e.key === Qt.Key_PageUp) { win.move(-8); e.accepted = true }
                }
            }
        }

        ListView {
            id: list
            anchors {
                top: field.bottom; topMargin: 8
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 8; rightMargin: 8; bottomMargin: 10
            }
            clip: true
            model: win.entries
            currentIndex: win.sel
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                required property int index
                required property var modelData
                width: list.width
                height: 50
                radius: 6
                color: index === win.sel ? win.island : "transparent"
                Behavior on color { CAnim { ms: 120 } }

                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 3
                    height: parent.height - 18
                    radius: 2
                    color: root.seal
                    visible: index === win.sel
                }

                IconImage {
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    implicitSize: 28
                    source: modelData.kind === "app" && modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                    visible: source !== ""
                }
                IconText {
                    anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                    visible: modelData.kind !== "app"
                    text: modelData.glyph || ""
                    fill: index === win.sel ? 1 : 0
                    color: modelData.kind === "calc" || index === win.sel ? root.seal : root.ink
                    font.pixelSize: 24
                }

                Column {
                    anchors {
                        left: parent.left; leftMargin: 56
                        right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        width: parent.width
                        text: modelData.name || ""
                        color: modelData.kind === "calc" ? root.seal : root.ink
                        font.family: root.mono
                        font.pixelSize: modelData.kind === "calc" ? 16 : 13
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.comment || ""
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }

                IconText {
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    visible: modelData.kind === "menu"
                    text: "chevron_right"
                    color: index === win.sel ? root.seal : root.sumiHi
                    font.pixelSize: 18
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.sel = index
                    onClicked: { win.sel = index; win.launch() }
                }
            }
        }

        Text {
            anchors.centerIn: list
            visible: win.entries.length === 0
            text: "no matches"
            color: root.sumiHi
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    onVisibleChanged: {
        if (visible) {
            menuMode = root.appLauncherMenu
            menuStack = []
            root.appLauncherMenu = false
            input.text = ""
            input.forceActiveFocus()
            sel = 0
        }
    }
}
