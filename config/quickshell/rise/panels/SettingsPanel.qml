import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"
import "dash"

// Settings (SUPER+comma, `ipc call settings toggle`), after Caelestia's Nexus:
// a navigation rail and pages of Material 3 rows. Every row edits a key of
// Theme._settingsSchema directly (assigning it saves settings.json); keys this
// file doesn't describe still show up under General → Other, so a new setting
// is never unreachable. Connections links to the panels that already exist for
// network, Bluetooth, audio and so on. Grows out of the bar.
PanelWindow {
    id: st
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-settings"
    WlrLayershell.keyboardFocus: root.settingsVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    M3Palette { id: m3; root: st.root }

    // ── rows ──
    function b(key, label, desc) { return { kind: "bool", key: key, label: label, desc: desc || "" } }
    function e(key, label, desc, options) { return { kind: "enum", key: key, label: label, desc: desc || "", options: options } }
    function o(values, labels) { return values.map(function (v, i) { return { v: v, label: labels ? labels[i] : String(v) } }) }
    function link(flag, icon, label, desc) { return { kind: "link", flag: flag, icon: icon, label: label, desc: desc || "" } }

    readonly property var barAnimNames: ["Off", "Stream", "Surge", "Bolt", "Bolt 2", "Stream 2", "Surge 2", "Reactor",
                                         "Quotes", "Weave", "Pluck", "Embers", "Mercury", "Harmonic", "Scope"]
    readonly property var pages: [
        { id: "bar", label: "Bar", icon: "toolbar", sections: [
            { title: "Layout", rows: [
                e("barPosition", "Position", "Which screen edge the bar sits on", o(["top", "bottom"], ["Top", "Bottom"])),
                e("workspaceMode", "Workspaces", "How many workspace buttons show", o(["10", "5", "active"], ["Persist 10", "Persist 5", "Active only"])),
                e("workspaceStyle", "Workspace style", "", o(["default", "numbers", "magic", "comet"], ["Default", "Numbers", "Magic", "Comet"])),
                e("barColor", "Accent", "The palette colour the bar and panels use",
                  o(root.barColorOptions, root.barColorOptions.map(function (id) { return root.barColorLabel(id) }))),
                e("barAnim", "Bar animation", "Runs continuously on the bar, so it costs some GPU",
                  o(barAnimNames.map(function (_, i) { return i }), barAnimNames))
            ] },
            { title: "Launcher button", rows: [
                e("launcherLogoMode", "Shows", "", o(["text", "icon"], ["Wordmark", "Icon"])),
                e("launcherLogoText", "Wordmark", "", o(root.launcherLogoTextOptions)),
                e("launcherLogoIcon", "Icon", "", o(root.launcherLogoIconOptions))
            ] },
            { title: "Splits", rows: [
                b("splitArch", "After the launcher", "Break the bar into separate pills here"),
                b("splitMon", "Around the monitors"),
                b("splitMprisL", "Before now playing"),
                b("splitNet", "Around the network")
            ] }
        ] },
        { id: "widgets", label: "Widgets", icon: "widgets", sections: [
            { title: "On the bar", rows: [
                b("modStatus", "Status"), b("modQuick", "Quick tools"), b("modMpris", "Now playing"),
                b("modVolume", "Volume"), b("modBrightness", "Brightness"), b("modNetwork", "Network"),
                b("modBluetooth", "Bluetooth"), b("modPower", "Power profile"), b("modCpu", "CPU"),
                b("modCpuTemperature", "CPU temperature"), b("modGpu", "GPU"), b("modMemory", "Memory"),
                b("modStorage", "Storage"), b("modWeather", "Weather"), b("modAi", "AI usage"),
                b("modGithub", "GitHub")
            ] },
            { title: "Compact form", rows: [
                b("compactMpris", "Now playing"), b("compactVolume", "Volume"), b("compactBrightness", "Brightness"),
                b("compactNetwork", "Network"), b("compactBluetooth", "Bluetooth"), b("compactBattery", "Battery"),
                b("compactPower", "Power profile"), b("compactCpu", "CPU"), b("compactMemory", "Memory")
            ] },
            { title: "Launcher badges", rows: [
                b("archBadgePackages", "Package updates"), b("archBadgeThemes", "Theme updates"), b("archBadgeShell", "Shell updates")
            ] }
        ] },
        { id: "style", label: "Style", icon: "palette", sections: [
            { title: "Frame", rows: [
                b("styleFrame", "Screen frame", "The bar as the thick edge of a frame around the screen; panels melt out of it"),
                b("styleFrameEdge", "Edge line", "The accent rim around the frame"),
                b("styleAutoHide", "Auto-hide the bar", "The bar shrinks to the frame edge until you hover it")
            ] },
            { title: "Surfaces", rows: [
                b("styleFrost", "Frost", "Translucent bar and panels over a blurred wallpaper"),
                b("styleShadow", "Shadow", "Drop shadows (an extra blur pass on the frame)"),
                b("styleBorder", "Border"),
                b("styleDepth", "Depth"),
                b("styleRadiusSmall", "Small corners"),
                b("styleIconLabels", "Icon labels"),
                b("styleDeskClock", "Desktop clock")
            ] },
            { title: "Motion", rows: [
                b("motionHover", "Hover", "Widgets lift under the pointer"),
                b("motionSweep", "Sweep", "A sweep across the bar on changes"),
                b("motionDigits", "Rolling digits", "Numbers roll when they change")
            ] },
            { title: "Pickers", rows: [
                e("pickerStyle", "Wallpaper and media pickers", "", o(["hearthstone", "carousel", "tanzaku"], ["Hearthstone", "Carousel", "Tanzaku"]))
            ] }
        ] },
        { id: "general", label: "General", icon: "tune", sections: [
            { title: "Units", rows: [
                b("clock12h", "12-hour clock"),
                b("weatherImperial", "Fahrenheit")
            ] },
            { title: "Tools", rows: [
                e("aiTool", "AI usage source", "", o(["codex", "opencode"], ["Codex", "OpenCode"]))
            ] },
            { title: "Other", rows: st.otherRows }
        ] },
        { id: "connections", label: "Connections", icon: "hub", sections: [
            { title: "Panels", rows: [
                link("networkVisible", "wifi", "Network", "Wi-Fi, Ethernet and VPN"),
                link("bluetoothVisible", "bluetooth", "Bluetooth", "Devices and pairing"),
                link("volVisible", "volume_up", "Audio", "Outputs, inputs and app volumes"),
                link("powerProfileVisible", "bolt", "Power profile", ""),
                link("drawerVisible", "format_paint", "Themes", "Palettes and wallpapers"),
                link("keybindsVisible", "keyboard", "Keybinds", "Every shortcut"),
                link("sessionVisible", "power_settings_new", "Session", "Lock, log out, restart, shut down")
            ] }
        ] },
        { id: "about", label: "About", icon: "info", sections: [] }
    ]

    // schema keys no page above describes (except the colour map, edited per widget)
    readonly property var otherRows: {
        var known = {}
        var described = ["barPosition", "workspaceMode", "workspaceStyle", "barColor", "barAnim", "launcherLogoMode",
            "launcherLogoText", "launcherLogoIcon", "splitArch", "splitMon", "splitMprisL", "splitNet",
            "modStatus", "modQuick", "modMpris", "modVolume", "modBrightness", "modNetwork", "modBluetooth", "modPower",
            "modCpu", "modCpuTemperature", "modGpu", "modMemory", "modStorage", "modWeather", "modAi", "modGithub",
            "compactMpris", "compactVolume", "compactBrightness", "compactNetwork", "compactBluetooth", "compactBattery",
            "compactPower", "compactCpu", "compactMemory", "archBadgePackages", "archBadgeThemes", "archBadgeShell",
            "styleFrame", "styleFrameEdge", "styleAutoHide", "styleFrost", "styleShadow", "styleBorder", "styleDepth",
            "styleRadiusSmall", "styleIconLabels", "styleDeskClock", "motionHover", "motionSweep", "motionDigits",
            "pickerStyle", "clock12h", "weatherImperial", "aiTool", "widgetColorStyles"]
        for (var i = 0; i < described.length; i++) known[described[i]] = true
        var out = [], schema = root._settingsSchema
        for (var k in schema) {
            if (known[k]) continue
            var rule = schema[k]
            if (rule === "bool") out.push(b(k, k))
            else if (Array.isArray(rule)) out.push(e(k, k, "", o(rule)))
        }
        return out
    }

    property int pageIndex: 0
    readonly property var page: pages[pageIndex]

    // ── about ──
    property var about: []
    Process {
        id: aboutProc
        command: ["bash", "-c",
            "hyprctl version | head -1 | cut -d' ' -f1-2; quickshell --version 2>&1 | head -1 | cut -d' ' -f1-2; " +
            "echo \"NixOS $(nixos-version 2>/dev/null)\"; echo \"Linux $(uname -r)\"; " +
            "sed -n 's/.*Kernel Module for [^ ]* *\\([0-9.]*\\).*/NVIDIA \\1/p' /proc/driver/nvidia/version 2>/dev/null | head -1"]
        stdout: StdioCollector { onStreamFinished: st.about = String(this.text || "").trim().split("\n").filter(function (l) { return l }) }
    }

    // loaded on open (VariantRoot): start closed so the reveal animates
    property bool loaded: false
    Component.onCompleted: { loaded = true; aboutProc.running = true }
    property real reveal: loaded && root.settingsVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.settingsVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001

    MouseArea {
        anchors.fill: parent
        onClicked: root.settingsVisible = false
    }

    FrameCard { root: st.root; card: card; reveal: st.reveal; edge: "bar" }
    Rectangle {
        id: card
        width: 960
        height: Math.min(680, st.height - 140)
        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom" ? parent.height - height - 35 : 35
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW
        clip: true
        PillShadow { theme: root; visible: root.styleShadow && !root.frameOn }

        opacity: st.reveal
        transform: Translate { y: (root.barPosition === "bottom" ? 1 : -1) * (1 - st.reveal) * 40 }
        focus: root.settingsVisible
        Keys.onPressed: function (ev) {
            if (ev.key === Qt.Key_Escape) { root.settingsVisible = false; ev.accepted = true }
            else if (ev.key === Qt.Key_Down || (ev.key === Qt.Key_Tab && !(ev.modifiers & Qt.ShiftModifier))) { st.pageIndex = (st.pageIndex + 1) % st.pages.length; ev.accepted = true }
            else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) { st.pageIndex = (st.pageIndex + st.pages.length - 1) % st.pages.length; ev.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── navigation rail ──
        Column {
            id: rail
            x: 16; y: 20
            width: 196
            spacing: 4
            DText {
                leftPadding: 16
                bottomPadding: 14
                text: "Settings"
                color: m3.onSurface
                font.pointSize: 22; font.weight: Font.Medium
            }
            Repeater {
                model: st.pages
                delegate: Rectangle {
                    id: navItem
                    required property var modelData
                    required property int index
                    readonly property bool current: st.pageIndex === index
                    width: rail.width; height: 52
                    radius: height / 2
                    color: current ? m3.secondaryContainer : "transparent"
                    Behavior on color { CAnim {} }
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: m3.onSurface
                        opacity: navMa.pressed ? 0.12 : navMa.containsMouse ? 0.06 : 0
                    }
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: navItem.modelData.icon
                            fill: navItem.current ? 1 : 0
                            color: navItem.current ? m3.onSecondaryContainer : m3.onSurfaceVariant
                            font.pointSize: 17
                        }
                        DText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: navItem.modelData.label
                            color: navItem.current ? m3.onSecondaryContainer : m3.onSurfaceVariant
                            font.pointSize: 12; font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: navMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: st.pageIndex = navItem.index
                    }
                }
            }
        }

        // ── page ──
        Flickable {
            id: pageView
            x: rail.x + rail.width + 16
            y: 16
            width: card.width - x - 16
            height: card.height - 32
            contentHeight: pageCol.implicitHeight + 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Connections { target: st; function onPageIndexChanged() { pageView.contentY = 0 } }

            Column {
                id: pageCol
                width: pageView.width
                spacing: 16

                DText {
                    leftPadding: 8
                    topPadding: 8
                    text: st.page.label
                    color: m3.onSurface
                    font.pointSize: 28; font.weight: Font.Medium
                }

                Repeater {
                    model: st.page.sections
                    delegate: Column {
                        id: section
                        required property var modelData
                        width: pageCol.width
                        spacing: 6
                        visible: modelData.rows.length > 0
                        DText {
                            leftPadding: 12
                            text: section.modelData.title
                            color: m3.primary
                            font.pointSize: 11; font.weight: Font.Medium
                        }
                        Rectangle {
                            width: parent.width
                            height: rowsCol.implicitHeight
                            radius: 24
                            color: m3.surfaceContainer
                            clip: true
                            Column {
                                id: rowsCol
                                width: parent.width
                                Repeater {
                                    model: section.modelData.rows
                                    delegate: SettingRow {}
                                }
                            }
                        }
                    }
                }

                // ── about ──
                Column {
                    visible: st.page.id === "about"
                    width: pageCol.width
                    spacing: 12
                    Rectangle {
                        width: parent.width
                        height: aboutCol.implicitHeight + 32
                        radius: 24
                        color: m3.surfaceContainer
                        Column {
                            id: aboutCol
                            x: 20; y: 16
                            spacing: 8
                            Row {
                                spacing: 14
                                DashShape {
                                    width: 56; height: 56
                                    kind: "gem"
                                    color: m3.primaryContainer
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uF313"
                                        color: m3.onPrimaryContainer
                                        font.family: st.root.mono
                                        font.pixelSize: 28
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    DText { text: "rise"; color: m3.onSurface; font.pointSize: 18; font.weight: Font.Medium }
                                    DText { text: "Quickshell bar for Hyprland, in Ziad0dev/dots"; color: m3.onSurfaceVariant }
                                }
                            }
                            Repeater {
                                model: st.about
                                delegate: DText {
                                    required property var modelData
                                    text: modelData
                                    color: m3.onSurface
                                    font.pointSize: 11
                                }
                            }
                            DText {
                                topPadding: 6
                                text: "Settings file: " + st.root.settingsPath
                                color: m3.onSurfaceVariant
                                font.pointSize: 10
                            }
                        }
                    }
                    DButton {
                        dash: m3
                        icon: "edit_document"
                        label: "Open settings.json"
                        onClicked: { st.root.settingsVisible = false; Quickshell.execDetached(["xdg-open", st.root.settingsPath]) }
                    }
                }
            }
        }
    }

    // one row: a label (+ description) and its control
    component SettingRow: Item {
        id: row
        required property var modelData
        required property int index
        readonly property var value: modelData.key ? st.root[modelData.key] : undefined
        width: rowsCol.width
        height: Math.max(64, textCol.implicitHeight + 24) + (wide ? chipsWide.height + 12 : 0)
        // many options wrap onto their own line under the label
        readonly property bool wide: modelData.kind === "enum" && modelData.options.length > 4

        Rectangle {
            visible: row.index > 0
            x: 20; width: parent.width - 40; height: 1
            color: m3.outlineVariant
        }
        Rectangle {
            anchors.fill: parent
            color: m3.onSurface
            opacity: row.modelData.kind === "link" && linkMa.containsMouse ? 0.05 : 0
        }

        Row {
            id: lead
            x: 20
            y: row.wide ? 12 : (Math.max(64, textCol.implicitHeight + 24) - height) / 2
            spacing: 14
            IconText {
                visible: row.modelData.kind === "link"
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.icon || ""
                color: m3.secondary
                font.pointSize: 18
            }
            Column {
                id: textCol
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - 40 - (row.wide ? 0 : control.width + 16) - (row.modelData.kind === "link" ? 40 : 0)
                spacing: 2
                DText {
                    width: parent.width
                    text: row.modelData.label
                    color: m3.onSurface
                    font.pointSize: 12
                }
                DText {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData.desc
                    color: m3.onSurfaceVariant
                    font.pointSize: 10
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }
        }

        // control on the right: switch, a few segments, or a chevron for links
        Item {
            id: control
            anchors.right: parent.right; anchors.rightMargin: 20
            y: lead.y + (lead.height - height) / 2
            width: row.modelData.kind === "bool" ? sw.width
                 : row.modelData.kind === "link" ? 24
                 : row.wide ? 0 : chips.width
            height: row.modelData.kind === "bool" ? sw.height : row.modelData.kind === "link" ? 24 : row.wide ? 0 : chips.height
            DSwitch {
                id: sw
                visible: row.modelData.kind === "bool"
                dash: m3
                checked: row.value === true
                onToggled: st.root[row.modelData.key] = !row.value
            }
            IconText {
                visible: row.modelData.kind === "link"
                text: "chevron_right"
                color: m3.onSurfaceVariant
                font.pointSize: 16
            }
        }
        // a few options: a row beside the label; many: a wrapping block under it
        Row {
            id: chips
            visible: row.modelData.kind === "enum" && !row.wide
            x: control.x
            y: control.y
            spacing: 6
            Repeater {
                model: chips.visible ? row.modelData.options : []
                delegate: Chip { setting: row.modelData; current: row.value }
            }
        }
        Flow {
            id: chipsWide
            visible: row.wide
            x: 20
            y: lead.y + lead.height + 12
            width: row.width - 40
            spacing: 6
            Repeater {
                model: row.wide ? row.modelData.options : []
                delegate: Chip { setting: row.modelData; current: row.value }
            }
        }

        MouseArea {
            id: linkMa
            anchors.fill: parent
            visible: row.modelData.kind === "link"
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { st.root.activateFocusedPopupScreen(); st.root[row.modelData.flag] = true }
        }
    }

    // one option of an enum setting
    component Chip: DButton {
        required property var modelData
        required property var setting
        property var current
        dash: m3
        height: 34
        label: modelData.label
        checked: current === modelData.v
        onClicked: st.root[setting.key] = modelData.v
    }
}
