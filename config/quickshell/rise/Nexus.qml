pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.ext.services as Services
import "modules"

// Settings app after Caelestia's Nexus (modules/nexus): one window with a page
// per area (style, network, devices, audio, notifications, bar, about), built
// on the services the bar already uses. SUPER + CTRL + I, or
// `qs -c rise ipc call nexus toggle`. The bar's own detailed settings stay in
// the Settings panel; the Bar page links to it.
Scope {
    id: nexus
    required property var root
    property bool open: false
    property string page: "style"

    IpcHandler {
        target: "nexus"
        function toggle(): void { nexus.open = !nexus.open }
        function open(page: string): void {
            if (page !== "") nexus.page = page
            nexus.open = true
        }
        function close(): void { nexus.open = false }
    }

    readonly property var pages: [
        { id: "style",    icon: "palette",        label: "Wallpaper & style", desc: "Theme, wallpaper, bar look" },
        { id: "network",  icon: "lan",            label: "Network",           desc: "Connections, Tailscale" },
        { id: "devices",  icon: "devices_other",  label: "Connected devices", desc: "Bluetooth, pairing" },
        { id: "audio",    icon: "volume_up",      label: "Audio",             desc: "Devices, app volumes" },
        { id: "notifs",   icon: "notifications",  label: "Notifications",     desc: "Do not disturb, history" },
        { id: "bar",      icon: "dock_to_bottom", label: "Bar",               desc: "Bar and panel settings" },
        { id: "about",    icon: "info",           label: "About",             desc: "This system" }
    ]

    LazyLoader {
        active: nexus.open

        FloatingWindow {
            id: win
            readonly property var t: nexus.root
            title: "Settings"
            implicitWidth: 1000
            implicitHeight: 700
            minimumSize: Qt.size(760, 520)
            color: t.paper
            onClosed: nexus.open = false

            function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

            // ── small parts ──
            component NxSwitch: Rectangle {
                id: sw
                property bool checked: false
                signal toggled()
                width: 40; height: 22; radius: 11
                color: checked ? win.t.seal : win.tint(win.t.ink, 0.14)
                Behavior on color { CAnim { ms: 140 } }
                Rectangle {
                    width: 16; height: 16; radius: 8
                    y: 3; x: sw.checked ? sw.width - width - 3 : 3
                    color: sw.checked ? win.t.paper : win.t.ink
                    Behavior on x { Anim { kind: "spatialFast" } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
            }

            component NxSection: UiText {
                topPadding: 14
                bottomPadding: 2
                textFormat: Text.PlainText
                color: win.t.seal
                font.family: win.t.mono
                font.pixelSize: 10
                font.letterSpacing: 3
            }

            component NxRow: Rectangle {
                id: row
                property string icon: ""
                property string title: ""
                property string sub: ""
                property bool hot: false
                property bool clickable: false
                default property alias trailing: tail.data
                signal clicked()
                width: parent ? parent.width : 0
                height: 52
                radius: win.t.tileRadius
                color: hot ? win.t.fillActive : rowMa.containsMouse && clickable ? win.t.fillHover : win.t.fillIdle
                Behavior on color { CAnim { ms: 120 } }
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.clickable
                    cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: row.clicked()
                }
                IconText {
                    id: rowIcon
                    visible: row.icon !== ""
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    text: row.icon
                    font.pixelSize: 20
                    color: row.hot ? win.t.seal : win.t.ink
                }
                Column {
                    x: row.icon !== "" ? 46 : 14
                    width: parent.width - x - tail.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    UiText {
                        width: parent.width
                        text: row.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: win.t.ink
                        font.family: win.t.mono; font.pixelSize: 13
                    }
                    UiText {
                        width: parent.width
                        visible: row.sub !== ""
                        text: row.sub
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: win.t.sumi
                        font.family: win.t.mono; font.pixelSize: 11
                    }
                }
                Row {
                    id: tail
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                }
            }

            component NxButton: Rectangle {
                id: btn
                property string text: ""
                property bool primary: false
                signal clicked()
                width: label.implicitWidth + 24; height: 28; radius: 14
                color: primary ? win.t.seal : btnMa.containsMouse ? win.t.fillHover : win.tint(win.t.ink, 0.08)
                UiText {
                    id: label
                    anchors.centerIn: parent
                    text: btn.text
                    color: btn.primary ? win.t.paper : win.t.ink
                    font.family: win.t.mono; font.pixelSize: 11
                }
                MouseArea { id: btnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
            }

            component NxSlider: Item {
                id: sl
                property real value: 0          // 0..1
                signal moved(real v)
                width: 160; height: 20
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 2
                    color: win.tint(win.t.ink, 0.14)
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, sl.value)); height: parent.height; radius: 2; color: win.t.seal }
                }
                Rectangle {
                    x: (sl.width - width) * Math.max(0, Math.min(1, sl.value)); anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7; color: win.t.ink
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function at(x) { sl.moved(Math.max(0, Math.min(1, x / sl.width))) }
                    onPressed: function (e) { at(e.x) }
                    onPositionChanged: function (e) { if (pressed) at(e.x) }
                }
            }

            // ── layout: nav on the left, the page on the right ──
            Rectangle {
                id: nav
                width: 250
                height: parent.height
                color: win.tint(win.t.ink, 0.035)
                Column {
                    x: 12; y: 18
                    width: parent.width - 24
                    spacing: 4
                    UiText {
                        leftPadding: 8; bottomPadding: 12
                        text: "Settings"
                        color: win.t.ink
                        font.family: win.t.mono; font.pixelSize: 20; font.weight: Font.Light
                    }
                    Repeater {
                        model: nexus.pages
                        delegate: Rectangle {
                            id: navItem
                            required property var modelData
                            readonly property bool current: nexus.page === modelData.id
                            width: parent.width; height: 48
                            radius: win.t.tileRadius
                            color: current ? win.t.fillActive : navMa.containsMouse ? win.t.fillHover : "transparent"
                            Behavior on color { CAnim { ms: 120 } }
                            IconText {
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                text: navItem.modelData.icon
                                font.pixelSize: 20
                                fill: navItem.current ? 1 : 0
                                color: navItem.current ? win.t.seal : win.t.ink
                            }
                            Column {
                                x: 44; anchors.verticalCenter: parent.verticalCenter
                                UiText { text: navItem.modelData.label; color: win.t.ink; font.family: win.t.mono; font.pixelSize: 12 }
                                UiText { text: navItem.modelData.desc; color: win.t.sumi; font.family: win.t.mono; font.pixelSize: 10 }
                            }
                            MouseArea { id: navMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nexus.page = navItem.modelData.id }
                        }
                    }
                }
            }

            Flickable {
                id: body
                x: nav.width
                width: parent.width - nav.width
                height: parent.height
                contentHeight: pageLoader.height + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Loader {
                    id: pageLoader
                    x: 28; y: 24
                    width: body.width - 56
                    sourceComponent: ({ style: pStyle, network: pNetwork, devices: pDevices, audio: pAudio,
                                        notifs: pNotifs, bar: pBar, about: pAbout })[nexus.page] || pStyle
                    onSourceComponentChanged: body.contentY = 0
                }
            }

            // ── pages ──
            Component {
                id: pStyle
                Column {
                    id: pageCol
                    spacing: 8
                    property var themes: []
                    property var walls: []
                    property string currentTheme: ""
                    NxSection { text: "THEME" }
                    Flow {
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: pageCol.themes
                            delegate: Rectangle {
                                id: tcard
                                required property var modelData
                                readonly property bool current: modelData.name === pageCol.currentTheme
                                width: 150; height: 104
                                radius: win.t.tileRadius
                                color: win.t.fillIdle
                                border.width: current ? 2 : 0
                                border.color: win.t.seal
                                clip: true
                                Image {
                                    width: parent.width; height: 78
                                    source: "file://" + tcard.modelData.preview
                                    sourceSize: Qt.size(300, 156)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                UiText {
                                    x: 8; y: 82; width: parent.width - 16
                                    text: tcard.modelData.name
                                    elide: Text.ElideRight
                                    color: tcard.current ? win.t.seal : win.t.ink
                                    font.family: win.t.mono; font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["themectl", "set", tcard.modelData.name])
                                }
                            }
                        }
                    }
                    NxSection { text: "WALLPAPER" }
                    Flow {
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: pageCol.walls
                            delegate: Rectangle {
                                id: wcard
                                required property string modelData
                                readonly property bool current: modelData === Services.WallpaperEngine.current
                                width: 150; height: 84
                                radius: win.t.tileRadius
                                color: win.t.fillIdle
                                border.width: current ? 2 : 0
                                border.color: win.t.seal
                                clip: true
                                Image {
                                    anchors.fill: parent; anchors.margins: wcard.current ? 2 : 0
                                    source: "file://" + wcard.modelData
                                    sourceSize: Qt.size(300, 168)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Services.WallpaperEngine.set(wcard.modelData)
                                }
                            }
                        }
                    }
                    NxRow {
                        icon: "photo_library"; title: "All wallpapers"; sub: "The wallpaper picker, with every folder"
                        clickable: true
                        onClicked: { nexus.open = false; win.t.openImagePicker("wallpaper") }
                        IconText { text: "chevron_right"; font.pixelSize: 18; color: win.t.sumi }
                    }

                    Process {
                        running: true
                        command: ["bash", "-c",
                            "shopt -s nullglob nocaseglob nocasematch; for d in \"$1\"/*/; do n=$(basename \"$d\"); " +
                            "[ \"${n#_}\" = \"$n\" ] || continue; p=; for c in \"$2/$n\".* \"$d\"wallpaper.* \"$d\"preview.*; do " +
                            "case \"$c\" in *.jpg|*.jpeg|*.png|*.webp) p=$c; break;; esac; done; " +
                            "[ -n \"$p\" ] && printf '%s\\t%s\\n' \"$n\" \"$p\"; done",
                            "_", win.t.dotsShellRoot + "/../../themes", Quickshell.env("HOME") + "/.local/share/dots/wallpapers"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                const out = []
                                String(this.text || "").split("\n").forEach(function (l) {
                                    const f = l.split("\t")
                                    if (f.length === 2) out.push({ name: f[0], preview: f[1] })
                                })
                                pageCol.themes = out
                            }
                        }
                    }
                    Process {
                        running: true
                        command: ["find", "-L", Services.WallpaperEngine.dir, "-maxdepth", "3", "-type", "f",
                            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")",
                            "-printf", "%T@\t%p\n"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                // newest first, a screenful: the picker has them all
                                pageCol.walls = String(this.text || "").split("\n")
                                    .map(function (l) { const i = l.indexOf("\t"); return i > 0 ? [Number(l.slice(0, i)), l.slice(i + 1)] : null })
                                    .filter(function (e) { return e !== null })
                                    .sort(function (a, b) { return b[0] - a[0] })
                                    .slice(0, 36).map(function (e) { return e[1] })
                            }
                        }
                    }
                    FileView {
                        path: win.t.barToolsStateDir + "/theme/current"
                        watchChanges: true
                        printErrors: false
                        onFileChanged: reload()
                        onLoaded: pageCol.currentTheme = String(text()).trim()
                    }
                }
            }

            Component {
                id: pNetwork
                Column {
                    spacing: 8
                    NxSection { text: "CONNECTIONS" }
                    Repeater {
                        model: Networking.devices ? Networking.devices.values : []
                        delegate: NxRow {
                            required property var modelData
                            icon: modelData.type === DeviceType.Wifi ? "wifi" : "lan"
                            title: String(modelData.name || "device")
                            sub: modelData.connected ? "Connected" : "Not connected"
                            hot: modelData.connected
                        }
                    }
                    UiText {
                        visible: !Networking.devices || Networking.devices.values.length === 0
                        text: "No network devices reported"
                        color: win.t.sumi; font.family: win.t.mono; font.pixelSize: 12
                    }
                    NxSection { text: "TAILSCALE" }
                    NxRow {
                        icon: "hub"
                        title: "Tailscale"
                        sub: !win.t.tsAvailable ? "Not running" : win.t.tsUp ? "Connected" : "Disconnected"
                        hot: win.t.tsUp
                        NxSwitch {
                            visible: win.t.tsAvailable
                            checked: win.t.tsUp
                            onToggled: win.t.setTailscale(!win.t.tsUp)
                        }
                    }
                    NxRow {
                        icon: "tune"; title: "More network settings"; sub: "Wi-Fi networks, saved connections, VPN"
                        clickable: true
                        onClicked: { nexus.open = false; win.t.networkVisible = true }
                        IconText { text: "chevron_right"; font.pixelSize: 18; color: win.t.sumi }
                    }
                }
            }

            Component {
                id: pDevices
                Column {
                    id: devCol
                    spacing: 8
                    readonly property var adapter: Services.Bluetooth.defaultAdapter
                    NxSection { text: "BLUETOOTH" }
                    NxRow {
                        icon: "bluetooth"
                        title: devCol.adapter ? "Bluetooth" : "No Bluetooth adapter"
                        sub: devCol.adapter ? (devCol.adapter.enabled ? (Services.Bluetooth.scanning ? "On · looking for devices" : "On") : "Off") : ""
                        hot: !!devCol.adapter && devCol.adapter.enabled
                        NxButton {
                            visible: !!devCol.adapter && devCol.adapter.enabled
                            text: Services.Bluetooth.scanning ? "Stop" : "Find devices"
                            onClicked: Services.Bluetooth.scanning ? Services.Bluetooth.stopScan() : Services.Bluetooth.scan()
                        }
                        NxSwitch {
                            visible: !!devCol.adapter
                            checked: !!devCol.adapter && devCol.adapter.enabled
                            onToggled: devCol.adapter.enabled = !devCol.adapter.enabled
                        }
                    }
                    NxSection { text: "DEVICES"; visible: Services.Bluetooth.devices.length > 0 }
                    Repeater {
                        model: Services.Bluetooth.devices
                        delegate: NxRow {
                            id: devRow
                            required property var modelData
                            icon: Services.Bluetooth.glyphFor(modelData)
                            title: String(modelData.name || modelData.deviceName || modelData.address)
                            sub: modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                                : modelData.pairing ? "Pairing…" : modelData.paired ? "Paired" : "Available"
                            hot: modelData.connected
                            NxButton {
                                text: devRow.modelData.connected ? "Disconnect" : devRow.modelData.paired ? "Connect" : "Pair"
                                primary: !devRow.modelData.connected
                                onClicked: {
                                    const d = devRow.modelData
                                    if (d.connected) d.disconnect()
                                    else if (d.paired) Services.Bluetooth.connectDevice(d)
                                    else Services.Bluetooth.pair(d)
                                }
                            }
                            NxButton {
                                visible: devRow.modelData.paired
                                text: "Forget"
                                onClicked: devRow.modelData.forget()
                            }
                        }
                    }
                }
            }

            Component {
                id: pAudio
                Column {
                    id: audioCol
                    spacing: 8
                    readonly property var nodes: Pipewire.nodes.values.filter(function (n) { return n && n.audio })
                    readonly property var outputs: nodes.filter(function (n) { return n.isSink && !n.isStream })
                    readonly property var inputs: nodes.filter(function (n) { return !n.isSink && !n.isStream })
                    readonly property var apps: nodes.filter(function (n) { return n.isStream && n.isSink })
                    PwObjectTracker { objects: audioCol.nodes }
                    function nodeName(n) {
                        return String((n.properties && (n.properties["application.name"] || n.properties["media.name"])) || n.description || n.nickname || n.name || "Audio")
                    }

                    component Device: NxRow {
                        id: dev
                        required property var modelData
                        property bool isDefault: false
                        signal pick()
                        icon: dev.isDefault ? "radio_button_checked" : "radio_button_unchecked"
                        title: String(modelData.description || modelData.nickname || modelData.name)
                        hot: isDefault
                        clickable: true
                        onClicked: dev.pick()
                        IconText {
                            text: dev.modelData.audio.muted ? "volume_off" : "volume_up"
                            font.pixelSize: 18
                            color: dev.modelData.audio.muted ? win.t.barAlert : win.t.sumi
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dev.modelData.audio.muted = !dev.modelData.audio.muted }
                        }
                        NxSlider { value: dev.modelData.audio.volume; onMoved: function (v) { dev.modelData.audio.volume = v } }
                        UiText { width: 36; horizontalAlignment: Text.AlignRight; text: Math.round(dev.modelData.audio.volume * 100) + "%"; color: win.t.ink; font.family: win.t.mono; font.pixelSize: 11 }
                    }

                    NxSection { text: "OUTPUT" }
                    Repeater {
                        model: audioCol.outputs
                        delegate: Device {
                            isDefault: modelData === Pipewire.defaultAudioSink
                            onPick: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                    NxSection { text: "INPUT" }
                    Repeater {
                        model: audioCol.inputs
                        delegate: Device {
                            isDefault: modelData === Pipewire.defaultAudioSource
                            onPick: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }
                    NxSection { text: "APPS"; visible: audioCol.apps.length > 0 }
                    Repeater {
                        model: audioCol.apps
                        delegate: NxRow {
                            id: appRow
                            required property var modelData
                            icon: "graphic_eq"
                            title: audioCol.nodeName(modelData)
                            NxSlider { value: appRow.modelData.audio.volume; onMoved: function (v) { appRow.modelData.audio.volume = v } }
                            UiText { width: 36; horizontalAlignment: Text.AlignRight; text: Math.round(appRow.modelData.audio.volume * 100) + "%"; color: win.t.ink; font.family: win.t.mono; font.pixelSize: 11 }
                        }
                    }
                }
            }

            Component {
                id: pNotifs
                Column {
                    spacing: 8
                    NxSection { text: "NOTIFICATIONS" }
                    NxRow {
                        icon: "do_not_disturb_on"
                        title: "Do not disturb"
                        sub: "Notifications go to the history without popping up"
                        hot: win.t.notifSilenced === true
                        NxSwitch {
                            checked: win.t.notifSilenced === true
                            onToggled: Quickshell.execDetached(["bash", "-c",
                                "if command -v dots-toggle-notification-silencing >/dev/null 2>&1; then exec dots-toggle-notification-silencing; fi; exec dots toggle notification silencing"])
                        }
                    }
                    NxRow {
                        icon: "history"
                        title: "History"
                        sub: (win.t.notifService ? win.t.notifService.count : 0) + " kept (the last 50)"
                        NxButton {
                            text: "Clear"
                            onClicked: if (win.t.notifService) win.t.notifService.clearAll()
                        }
                    }
                }
            }

            Component {
                id: pBar
                Column {
                    spacing: 8
                    component Toggle: NxRow {
                        id: tg
                        required property string key
                        NxSwitch { checked: win.t[tg.key] === true; onToggled: win.t[tg.key] = !win.t[tg.key] }
                    }
                    NxSection { text: "LOOK" }
                    Toggle { key: "barFoldDetails"; icon: "unfold_less"; title: "Readings on hover"; sub: "Numbers fold away until you hover their side of the bar" }
                    Toggle { key: "trayRecolour"; icon: "palette"; title: "Tint tray icons"; sub: "Tray icons in the bar's accent" }
                    Toggle { key: "styleFrame"; icon: "crop_free"; title: "Screen frame"; sub: "The bar as the edge of a frame round the screen" }
                    Toggle { key: "styleDeskClock"; icon: "schedule"; title: "Desk clock"; sub: "Large time and date on the wallpaper" }
                    Toggle { key: "styleAutoHide"; icon: "visibility_off"; title: "Auto-hide"; sub: "The bar shrinks to the edge until hovered" }
                    NxRow {
                        id: dockRow
                        icon: "dock_to_bottom"; title: "Dock"; sub: "Apps along the bottom; right-click one to keep it"
                        Repeater {
                            model: [["autohide", "Auto-hide"], ["floating", "Floating"], ["always", "Always"], ["off", "Off"]]
                            delegate: NxButton {
                                required property var modelData
                                text: modelData[1]
                                primary: win.t.dockMode === modelData[0]
                                onClicked: win.t.dockMode = modelData[0]
                            }
                        }
                    }
                    NxSection { text: "MORE" }
                    NxRow {
                        icon: "settings"; title: "All bar settings"; sub: "Position, widgets, splits, style, motion"
                        clickable: true
                        onClicked: { nexus.open = false; win.t.settingsVisible = true }
                        IconText { text: "chevron_right"; font.pixelSize: 18; color: win.t.sumi }
                    }
                    NxRow {
                        icon: "view_quilt"; title: "Workspace layout"; sub: "This workspace: " + win.t.wsLayoutLabel(win.t.wsLayoutCurrent) + " · new ones: " + win.t.wsLayoutLabel(win.t.wsLayoutDefault)
                        clickable: true
                        onClicked: { nexus.open = false; win.t.layoutVisible = true }
                        IconText { text: "chevron_right"; font.pixelSize: 18; color: win.t.sumi }
                    }
                }
            }

            Component {
                id: pAbout
                Column {
                    id: aboutCol
                    spacing: 8
                    property var info: ({})
                    NxSection { text: "THIS SYSTEM" }
                    Repeater {
                        model: [
                            { icon: "computer", k: "Host", v: aboutCol.info.host },
                            { icon: "deployed_code", k: "System", v: aboutCol.info.os },
                            { icon: "memory", k: "Kernel", v: aboutCol.info.kernel },
                            { icon: "schedule", k: "Uptime", v: aboutCol.info.uptime },
                            { icon: "dashboard", k: "Shell", v: "Rise on Quickshell" },
                            { icon: "palette", k: "Theme", v: aboutCol.info.theme }
                        ]
                        delegate: NxRow {
                            id: infoRow
                            required property var modelData
                            icon: modelData.icon
                            title: modelData.k
                            UiText { text: String(infoRow.modelData.v || "…"); color: win.t.sumi; font.family: win.t.mono; font.pixelSize: 12 }
                        }
                    }
                    Process {
                        running: true
                        command: ["bash", "-c",
                            "printf 'host\\t%s\\n' \"$(cat /proc/sys/kernel/hostname)\"; " +
                            "printf 'os\\t%s\\n' \"$(. /etc/os-release && printf '%s' \"$PRETTY_NAME\")\"; " +
                            "printf 'kernel\\t%s\\n' \"$(uname -r)\"; " +
                            "printf 'uptime\\t%s\\n' \"$(uptime -p | sed 's/^up //')\"; " +
                            "printf 'theme\\t%s\\n' \"$(cat \"${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme/current\" 2>/dev/null)\""]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                const o = {}
                                String(this.text || "").split("\n").forEach(function (l) {
                                    const i = l.indexOf("\t")
                                    if (i > 0) o[l.slice(0, i)] = l.slice(i + 1)
                                })
                                aboutCol.info = o
                            }
                        }
                    }
                }
            }
        }
    }
}
