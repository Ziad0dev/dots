import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../modules"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris

// Dashboard (SUPER+I, hover the left frame edge, `ipc call dashboard toggle`).
// Everything is drawn from the active palette (accent + color01…06), so it
// takes on each theme's mood. Top to bottom: avatar + greeting, hero clock,
// weather, now playing on its blurred cover, ring gauges, calendar, a quote
// that takes up the remaining height, and the shortcuts pinned to the bottom.
// With the frame on it grows out of the left frame edge (FrameCard "left").
PanelWindow {
    id: dash
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-dashboard"

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property bool framed: root.frameOn
    readonly property int topBand: root.barPosition === "bottom" ? (framed ? root.frameThickness : 0) : barBottom
    readonly property int bottomBand: root.barPosition === "bottom" ? barBottom : (framed ? root.frameThickness : 0)

    // ── clock / session ──
    property date now: new Date()
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: dash.visible
        onTriggered: dash.now = new Date()
    }
    readonly property string user: Quickshell.env("USER") || ""
    readonly property string greeting: {
        var h = now.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    property string host: ""
    property real uptimeS: 0
    readonly property string uptimeText: {
        var m = Math.floor(uptimeS / 60), h = Math.floor(m / 60), d = Math.floor(h / 24)
        return d > 0 ? d + "d " + (h % 24) + "h" : h > 0 ? h + "h " + (m % 60) + "m" : m + "m"
    }
    property var quote: ({ text: "", author: "" })
    property bool hasFace: false              // ~/.face, if you set one
    Process {
        id: sessionProc
        command: ["bash", "-c", "cat /proc/sys/kernel/hostname; cut -d' ' -f1 /proc/uptime; shuf -n1 \"$1\" 2>/dev/null || echo; [ -r \"$HOME/.face\" ] && echo face",
                  "_", Qt.resolvedUrl("../quotes.txt").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = String(this.text || "").trim().split("\n")
                dash.host = l[0] || ""
                dash.uptimeS = parseFloat(l[1] || "0") || 0
                var q = (l[2] || "").split("|")
                dash.quote = { text: (q[0] || "").trim(), author: (q[1] || "").trim() }
                dash.hasFace = (l[3] || "") === "face"
            }
        }
    }

    // ── weather (wttr.in, fetched while open, at most every 10 min) ──
    property var wx: null
    property double wxFetched: 0
    Process {
        id: wxProc
        command: ["curl", "-fs", "--max-time", "5", "https://wttr.in?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(String(this.text || ""))
                    var c = d.current_condition[0], today = d.weather && d.weather[0]
                    var area = d.nearest_area && d.nearest_area[0]
                    dash.wx = {
                        code: parseInt(c.weatherCode),
                        tempC: c.temp_C, tempF: c.temp_F,
                        feelsC: c.FeelsLikeC, feelsF: c.FeelsLikeF,
                        desc: c.weatherDesc && c.weatherDesc[0] ? c.weatherDesc[0].value : "",
                        humidity: c.humidity, wind: c.windspeedKmph,
                        minC: today ? today.mintempC : "", maxC: today ? today.maxtempC : "",
                        minF: today ? today.mintempF : "", maxF: today ? today.maxtempF : "",
                        place: area && area.areaName && area.areaName[0] ? area.areaName[0].value : ""
                    }
                    dash.wxFetched = Date.now()
                } catch (e) { }
            }
        }
    }
    function wxGlyph(code) {
        if (code === 113) return ""                                    // sunny
        if (code === 116) return ""                                    // partly cloudy
        if ([119, 122].indexOf(code) >= 0) return ""                   // cloudy
        if ([143, 248, 260].indexOf(code) >= 0) return ""              // fog
        if ([200, 386, 389, 392, 395].indexOf(code) >= 0) return ""    // thunder
        if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350,
             362, 365, 368, 371, 374, 377].indexOf(code) >= 0) return "" // snow / sleet
        return ""                                                       // rain
    }
    function deg(c, f) { return (root.weatherImperial ? f : c) + "°" }

    onVisibleChanged: if (visible) {
        wallProc.running = false; wallProc.running = true
        sessionProc.running = false; sessionProc.running = true
        if (Date.now() - wxFetched > 600000) { wxProc.running = false; wxProc.running = true }
    }

    // ── now playing ──
    MprisSelect { id: sel }
    readonly property var player: sel.player
    property real pos: 0
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: dash.visible && dash.player !== null
        onTriggered: dash.pos = dash.player ? (dash.player.position || 0) : 0
    }

    // ── shortcuts ──
    // detached: the dashboard unloads after closing, which would kill a child
    function run(cmd) {
        root.dashboardVisible = false
        Quickshell.execDetached(["bash", "-c", cmd])
    }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // card fill over the wallpaper: the theme background, mostly opaque
    readonly property color glass: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.6)

    // ── tabs ──
    property string tab: "overview"            // overview | performance | media
    readonly property var tabs: ["overview", "performance", "media"]

    // ── wallpaper: resolved on open, so a changed wallpaper isn't a cached image ──
    property string wallpaper: ""
    Process {
        id: wallProc
        command: ["readlink", "-f", root.currentBackgroundPath]
        stdout: StdioCollector { onStreamFinished: dash.wallpaper = String(this.text || "").trim() }
    }

    // histories come from telemetry (root.cpuHist …); network is sampled here
    function push(arr, v) { var a = arr.slice(); a.push(v); if (a.length > root.histLen) a.shift(); return a }

    // ── network rates from /proc/net/dev (only while the performance tab shows) ──
    property real rxRate: 0
    property real txRate: 0
    property var rxHist: []
    property var txHist: []
    property var _net: null
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: dash.visible && dash.tab === "performance"
        onTriggered: { netProc.running = false; netProc.running = true }
    }
    Process {
        id: netProc
        command: ["awk", "NR > 2 && $1 !~ /^(lo|docker|veth|br-|virbr)/ { rx += $2; tx += $10 } END { print rx, tx }", "/proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                var f = String(this.text || "").trim().split(/\s+/), now = Date.now()
                var rx = parseFloat(f[0]) || 0, tx = parseFloat(f[1]) || 0
                if (dash._net) {
                    var dt = Math.max(0.5, (now - dash._net.t) / 1000)
                    dash.rxRate = Math.max(0, (rx - dash._net.rx) / dt)
                    dash.txRate = Math.max(0, (tx - dash._net.tx) / dt)
                    dash.rxHist = dash.push(dash.rxHist, dash.rxRate)
                    dash.txHist = dash.push(dash.txHist, dash.txRate)
                }
                dash._net = { t: now, rx: rx, tx: tx }
            }
        }
    }
    function rate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? (b / 1024).toFixed(0) + " KB/s" : Math.round(b) + " B/s"
    }

    // loaded on open (VariantRoot): start closed so the reveal animates
    property bool loaded: false
    Component.onCompleted: loaded = true
    property real reveal: loaded && root.dashboardVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.dashboardVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.dashboardVisible && !root.dashboardHoverOpened
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.dashboardVisible = false
    }

    // hover-opened: close once the pointer has left the card and the left band
    Item {
        x: 0
        y: card.y
        width: card.x
        height: card.height
        HoverHandler { id: stripHover }
    }
    Timer {
        interval: 350
        running: root.dashboardHoverOpened && root.dashboardVisible && !cardHover.hovered && !stripHover.hovered
        onTriggered: root.dashboardVisible = false
    }

    FrameCard { root: dash.root; card: card; reveal: dash.reveal; edge: "left" }
    Rectangle {
        id: card
        width: 440
        x: dash.framed ? root.frameThickness : dash.gap
        y: dash.topBand + (dash.framed ? 0 : dash.gap)
        height: parent.height - dash.topBand - dash.bottomBand - (dash.framed ? 0 : 2 * dash.gap)
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW
        PillShadow { theme: root ; visible: root.styleShadow && !root.frameOn }

        opacity: dash.reveal
        transform: Translate { x: -(1 - dash.reveal) * 56 }
        focus: root.dashboardVisible
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.dashboardVisible = false; event.accepted = true }
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) { dash.tab = dash.tabs[event.key - Qt.Key_1]; event.accepted = true }
            else if (event.key === Qt.Key_Tab) { dash.tab = dash.tabs[(dash.tabs.indexOf(dash.tab) + 1) % 3]; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }
        HoverHandler { id: cardHover }

        // ── the wallpaper behind everything, dimmed toward the bottom ──
        Item {
            id: wallLayer
            anchors.fill: parent
            visible: wallImg.status === Image.Ready
            layer.enabled: visible
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: wallMask
            }
            Image {
                id: wallImg
                anchors.fill: parent
                source: dash.wallpaper !== "" ? "file://" + dash.wallpaper : ""
                sourceSize.height: 1600
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: dash.tint(root.paper, 0.30) }
                    GradientStop { position: 0.45; color: dash.tint(root.paper, 0.45) }
                    GradientStop { position: 1.0; color: dash.tint(root.paper, 0.80) }
                }
            }
        }
        Rectangle {
            id: wallMask
            anchors.fill: parent
            radius: card.radius
            visible: false
            layer.enabled: true
        }

        // ── palette glow behind everything ──
        Canvas {
            id: glow
            anchors.fill: parent
            visible: !wallLayer.visible
            property color a: root.seal
            property color b: root.color05
            onAChanged: requestPaint()
            onBChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                function blob(x, y, r, c, alpha) {
                    var g = ctx.createRadialGradient(x, y, 0, x, y, r)
                    g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, alpha))
                    g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                blob(width * 0.15, 90, 300, a, 0.20)
                blob(width * 0.95, height * 0.62, 360, b, 0.14)
            }
        }

        // ── tab bar ──
        Row {
            id: tabBar
            anchors.top: parent.top; anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: [{ id: "overview", label: "Overview", glyph: "\uE871" },
                        { id: "performance", label: "Performance", glyph: "\uE9E4" },
                        { id: "media", label: "Media", glyph: "\uE405" }]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: dash.tab === modelData.id
                    width: tabRow.implicitWidth + 22
                    height: 30
                    radius: 15
                    color: on ? dash.tint(root.seal, 0.28) : tabMa.containsMouse ? dash.glass : dash.tint(root.paper, 0.35)
                    border.color: on ? root.seal : dash.tint(root.ink, 0.12)
                    border.width: 1
                    Behavior on color { CAnim { ms: 160 } }
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.modelData.glyph
                            fill: parent.parent.on ? 1 : 0
                            color: parent.parent.on ? root.seal : root.ink
                            font.pixelSize: 15
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.modelData.label
                            color: root.ink
                            font.family: root.mono; font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dash.tab = parent.modelData.id
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            anchors.topMargin: 64
            spacing: 16
            visible: dash.tab === "overview"

            // ── avatar + greeting ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Item {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 58
                    Canvas {
                        anchors.fill: parent
                        property color a: root.seal
                        property color b: root.color05
                        onAChanged: requestPaint()
                        onBChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var g = ctx.createConicalGradient(width / 2, height / 2, 0)
                            g.addColorStop(0, a); g.addColorStop(0.5, b); g.addColorStop(1, a)
                            ctx.strokeStyle = g
                            ctx.lineWidth = 2.5
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, width / 2 - 2, 0, 2 * Math.PI)
                            ctx.stroke()
                        }
                    }
                    Rectangle {
                        id: avatarDisc
                        anchors.centerIn: parent
                        width: 48; height: 48; radius: 24
                        color: dash.tint(root.seal, 0.18)
                        clip: true
                        Image {
                            id: face
                            anchors.fill: parent
                            source: dash.hasFace ? "file://" + Quickshell.env("HOME") + "/.face" : ""
                            sourceSize.width: 96
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: face
                            visible: face.status === Image.Ready
                            maskEnabled: true
                            maskSource: avatarMask
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            text: dash.user.charAt(0).toUpperCase()
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 22
                            font.weight: Font.Medium
                        }
                    }
                    Rectangle {
                        id: avatarMask
                        width: 48; height: 48; radius: 24
                        visible: false
                        layer.enabled: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    UiText {
                        text: dash.greeting + ","
                        color: root.sumi; font.family: root.mono; font.pixelSize: 11
                    }
                    UiText {
                        text: dash.user
                        color: root.ink; font.family: root.mono; font.pixelSize: 16; font.weight: Font.Medium
                    }
                    UiText {
                        text: (dash.host ? dash.host : "") + (dash.uptimeS > 0 ? "  ·  up " + dash.uptimeText : "")
                        color: root.sumi; font.family: root.mono; font.pixelSize: 10
                    }
                }
            }

            // ── hero clock ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Row {
                    spacing: 6
                    Text {
                        id: clockText
                        text: Qt.formatTime(dash.now, root.clock12h ? "h:mm" : "HH:mm")
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 76
                        font.weight: Font.Light
                    }
                    Text {
                        anchors.baseline: clockText.baseline
                        text: Qt.formatTime(dash.now, "ss")
                        color: root.seal
                        font.family: root.mono
                        font.pixelSize: 22
                    }
                }
                UiText {
                    text: Qt.formatDate(dash.now, "dddd · d MMMM yyyy").toUpperCase()
                    color: root.seal
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }
            }

            // ── weather ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                visible: dash.wx !== null
                radius: root.tileRadius + 10
                border.color: dash.tint(root.ink, 0.08)
                border.width: 1
                color: dash.glass
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: dash.tint(root.color04, 0.34) }
                        GradientStop { position: 1; color: dash.tint(root.color05, 0.12) }
                    }
                }
                IconText {
                    id: wxIcon
                    anchors.left: parent.left; anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: dash.wx ? dash.wxGlyph(dash.wx.code) : ""
                    color: root.ink
                    fill: 1
                    font.pixelSize: 46
                }
                Column {
                    anchors.left: wxIcon.right; anchors.leftMargin: 16
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Row {
                        spacing: 10
                        Text {
                            text: dash.wx ? dash.deg(dash.wx.tempC, dash.wx.tempF) : ""
                            color: root.ink; font.family: root.mono; font.pixelSize: 26; font.weight: Font.Light
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: dash.wx ? dash.wx.desc : ""
                            color: root.ink; font.family: root.mono; font.pixelSize: 12
                        }
                    }
                    UiText {
                        text: !dash.wx ? "" : "↓ " + dash.deg(dash.wx.minC, dash.wx.minF) + "  ↑ " + dash.deg(dash.wx.maxC, dash.wx.maxF)
                            + "   feels " + dash.deg(dash.wx.feelsC, dash.wx.feelsF)
                            + "   " + dash.wx.humidity + "%"
                        color: dash.tint(root.ink, 0.85); font.family: root.mono; font.pixelSize: 10
                    }
                    UiText {
                        text: dash.wx ? dash.wx.place : ""
                        visible: text !== ""
                        color: root.sumi; font.family: root.mono; font.pixelSize: 10
                    }
                }
            }

            // ── now playing, on its own blurred cover ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 128
                visible: dash.player !== null
                radius: root.tileRadius + 10
                color: dash.glass
                border.color: dash.tint(root.ink, 0.08)
                border.width: 1
                clip: true

                Image {
                    id: coverSrc
                    anchors.fill: parent
                    source: dash.player ? (dash.player.trackArtUrl || "") : ""
                    sourceSize.width: 256
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: coverSrc
                    visible: coverSrc.status === Image.Ready
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 48
                    saturation: 0.15
                    brightness: -0.35
                    opacity: 0.85
                }

                Rectangle {
                    id: cover
                    anchors.left: parent.left; anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96; height: 96
                    radius: root.tileRadius + 4
                    color: dash.tint(root.ink, 0.06)
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: coverSrc.source
                        sourceSize.width: 192
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    IconText {
                        anchors.centerIn: parent
                        visible: coverSrc.status !== Image.Ready
                        text: ""
                        color: root.sumi
                        font.pixelSize: 32
                    }
                }
                Column {
                    anchors.left: cover.right; anchors.leftMargin: 14
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    UiText {
                        text: dash.player ? (dash.player.trackTitle || "Unknown") : ""
                        color: root.ink; font.family: root.mono; font.pixelSize: 13; font.weight: Font.Medium
                        width: parent.width; elide: Text.ElideRight
                    }
                    UiText {
                        text: dash.player ? (dash.player.trackArtist || "") : ""
                        color: dash.tint(root.ink, 0.8); font.family: root.mono; font.pixelSize: 10
                        width: parent.width; elide: Text.ElideRight
                    }
                    Rectangle {
                        width: parent.width
                        height: 3; radius: 2
                        color: dash.tint(root.ink, 0.15)
                        visible: dash.player && dash.player.length > 0
                        Rectangle {
                            height: parent.height; radius: 2
                            color: root.seal
                            width: parent.width * (dash.player && dash.player.length > 0
                                ? Math.min(1, dash.pos / dash.player.length) : 0)
                            Behavior on width { Anim { kind: "size"; ms: 900 } }
                        }
                    }
                    Row {
                        spacing: 18
                        topPadding: 2
                        Repeater {
                            model: [
                                { glyph: "", act: "previous" },
                                { glyph: sel.playing ? "" : "", act: "toggle" },
                                { glyph: "", act: "next" }
                            ]
                            delegate: IconText {
                                required property var modelData
                                text: modelData.glyph
                                fill: 1
                                color: ctlMa.containsMouse ? root.seal : root.ink
                                font.pixelSize: modelData.act === "toggle" ? 30 : 22
                                anchors.verticalCenter: parent.verticalCenter
                                scale: ctlMa.pressed ? 0.88 : 1
                                Behavior on scale { Anim { kind: "spatialFast" } }
                                MouseArea {
                                    id: ctlMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var p = dash.player
                                        if (!p) return
                                        if (parent.modelData.act === "toggle") p.togglePlaying()
                                        else if (parent.modelData.act === "next") p.next()
                                        else p.previous()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── ring gauges ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: [
                        { label: "CPU", value: root.systemCpuPercent, text: root.systemCpuPercent + "%", color: root.color04 },
                        { label: "RAM", value: root.systemMemPercent, text: root.systemMemUsedGiB.toFixed(1) + "G", color: root.color05 },
                        root.gpuAvailable
                            ? { label: "GPU", value: root.gpuPercent, text: root.gpuPercent + "%", color: root.color06 }
                            : { label: "DISK", value: root.storagePercent, text: root.storagePercent + "%", color: root.color06 },
                        { label: "TEMP", value: Math.min(100, root.cpuTemperatureC), text: root.cpuTemperatureC + "°", color: root.color01 }
                    ]
                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        Canvas {
                            id: ring
                            width: 78; height: 78
                            anchors.horizontalCenter: parent.horizontalCenter
                            property real shown: parent.modelData.value
                            Behavior on shown { Anim { kind: "size"; ms: 600 } }
                            property color c: parent.modelData.color
                            property color track: dash.tint(root.ink, 0.10)
                            onShownChanged: requestPaint()
                            onCChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var r = width / 2 - 5, start = 0.75 * Math.PI, sweep = 1.5 * Math.PI
                                ctx.lineCap = "round"
                                ctx.lineWidth = 6
                                ctx.strokeStyle = track
                                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, start, start + sweep); ctx.stroke()
                                var f = Math.max(0, Math.min(1, shown / 100))
                                if (f > 0) {
                                    ctx.strokeStyle = c
                                    ctx.beginPath(); ctx.arc(width / 2, height / 2, r, start, start + sweep * f); ctx.stroke()
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.modelData.text
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 13
                            }
                        }
                        UiText {
                            anchors.top: ring.bottom; anchors.topMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.modelData.label
                            color: root.sumi; font.family: root.mono; font.pixelSize: 9; font.letterSpacing: 2
                        }
                    }
                }
            }

            // ── calendar ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: calCol.implicitHeight + 26
                radius: root.tileRadius + 10
                color: dash.glass
                border.color: dash.tint(root.ink, 0.08)
                border.width: 1
                Column {
                    id: calCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 16
                    spacing: 6
                    readonly property int year: dash.now.getFullYear()
                    readonly property int month: dash.now.getMonth()
                    readonly property int today: dash.now.getDate()
                    // Monday-first grid: leading blanks, then the month's days
                    readonly property var cells: {
                        var first = (new Date(year, month, 1).getDay() + 6) % 7
                        var days = new Date(year, month + 1, 0).getDate()
                        var out = []
                        for (var i = 0; i < first; i++) out.push(0)
                        for (var d = 1; d <= days; d++) out.push(d)
                        return out
                    }
                    UiText {
                        text: Qt.formatDate(dash.now, "MMMM").toUpperCase()
                        color: root.seal; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 2
                    }
                    Grid {
                        id: calGrid
                        columns: 7
                        width: parent.width
                        readonly property real cellW: width / 7
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            delegate: UiText {
                                required property var modelData
                                width: calGrid.cellW; height: 18
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: root.sumi; font.family: root.mono; font.pixelSize: 9
                            }
                        }
                        Repeater {
                            model: calCol.cells
                            delegate: Item {
                                required property var modelData
                                required property int index
                                readonly property bool weekend: index % 7 >= 5
                                width: calGrid.cellW; height: 24
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 24; height: 24; radius: 12
                                    visible: parent.modelData === calCol.today
                                    color: root.seal
                                }
                                UiText {
                                    anchors.centerIn: parent
                                    text: parent.modelData > 0 ? parent.modelData : ""
                                    color: parent.modelData === calCol.today ? root.paper
                                         : parent.weekend ? dash.tint(root.color05, 0.9) : root.ink
                                    font.family: root.mono; font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }

            // ── quote: takes whatever height is left ──
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    spacing: 8
                    visible: dash.quote.text !== "" && parent.height > 90
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "“"
                        color: dash.tint(root.seal, 0.6)
                        font.family: "serif"
                        font.pixelSize: 44
                        height: 26
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: dash.quote.text
                        color: dash.tint(root.ink, 0.85)
                        font.family: "serif"
                        font.italic: true
                        font.pixelSize: 15
                        lineHeight: 1.25
                    }
                    UiText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: dash.quote.author ? "— " + dash.quote.author : ""
                        color: root.sumi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                    }
                }
            }

            // ── shortcuts, pinned to the bottom ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [
                        { glyph: "", label: "Lock",     act: "lock",     color: root.color01 },
                        { glyph: "", label: "Shot",     act: "shot",     color: root.color03 },
                        { glyph: "", label: "Themes",   act: "themes",   color: root.color05 },
                        { glyph: "", label: "Settings", act: "settings", color: root.color04 },
                        { glyph: "", label: "Power",    act: "power",    color: root.color01 }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 62
                        radius: root.tileRadius + 8
                        color: actMa.containsMouse ? dash.tint(modelData.color, 0.22) : dash.tint(root.ink, 0.04)
                        border.color: actMa.containsMouse ? modelData.color : dash.tint(root.ink, 0.08)
                        border.width: 1
                        Behavior on color { CAnim { ms: 160 } }
                        scale: actMa.pressed ? 0.95 : 1
                        Behavior on scale { Anim { kind: "spatialFast" } }
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.glyph
                                fill: actMa.containsMouse ? 1 : 0
                                color: actMa.containsMouse ? parent.parent.modelData.color : root.ink
                                font.pixelSize: 20
                            }
                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.label
                                color: root.sumi; font.family: root.mono; font.pixelSize: 9; font.letterSpacing: 1
                            }
                        }
                        MouseArea {
                            id: actMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var a = parent.modelData.act
                                if (a === "lock") dash.run("loginctl lock-session")
                                else if (a === "shot") dash.run("sleep 0.4; dots-shot region")
                                else if (a === "themes") { root.dashboardVisible = false; root.drawerVisible = true }
                                else if (a === "power") { root.dashboardVisible = false; root.sessionVisible = true }
                                else { root.dashboardVisible = false; root.controlVisible = true }
                            }
                        }
                    }
                }
            }
        }

        // ── performance tab ──
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            anchors.topMargin: 64
            spacing: 12
            visible: dash.tab === "performance"

            Repeater {
                model: [
                    { label: "CPU", glyph: "", values: root.cpuHist, now: root.systemCpuPercent + "%",
                      sub: "load " + root.systemLoad1.toFixed(2) + " · " + root.systemLoad5.toFixed(2) + " · " + root.systemLoad15.toFixed(2),
                      color: root.color04, max: 100, shown: true },
                    { label: "RAM", glyph: "", values: root.memHist, now: root.systemMemPercent + "%",
                      sub: root.systemMemUsedGiB.toFixed(1) + " / " + root.systemMemTotalGiB.toFixed(1) + " GiB",
                      color: root.color05, max: 100, shown: true },
                    { label: "GPU", glyph: "", values: root.gpuHist, now: root.gpuPercent + "%",
                      sub: (root.gpuName || "") + (root.gpuMemoryTotalMiB > 0 ? "  ·  " + (root.gpuMemoryUsedMiB / 1024).toFixed(1) + " / " + (root.gpuMemoryTotalMiB / 1024).toFixed(0) + " GiB" : "")
                           + (root.gpuPowerW > 0 ? "  ·  " + Math.round(root.gpuPowerW) + " W" : ""),
                      color: root.color06, max: 100, shown: root.gpuAvailable },
                    { label: "TEMP", glyph: "", values: root.tempHist, now: root.cpuTemperatureC + "°",
                      sub: "CPU" + (root.gpuTemperatureC > 0 ? "  ·  GPU " + root.gpuTemperatureC + "°" : ""),
                      color: root.color01, max: 100, shown: root.cpuTemperatureAvailable }
                ]
                delegate: Rectangle {
                    required property var modelData
                    visible: modelData.shown
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 90
                    radius: root.tileRadius + 10
                    color: dash.glass
                    border.color: dash.tint(root.ink, 0.08)
                    border.width: 1
                    clip: true
                    Graph {
                        anchors.fill: parent
                        anchors.topMargin: 40
                        values: parent.modelData.values
                        maxValue: parent.modelData.max
                        lineColor: parent.modelData.color
                    }
                    Row {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 12
                        spacing: 8
                        IconText {
                            text: parent.parent.modelData.glyph
                            color: parent.parent.modelData.color
                            fill: 1
                            font.pixelSize: 18
                        }
                        Column {
                            spacing: 1
                            UiText { text: parent.parent.parent.modelData.label; color: root.ink; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 2 }
                            UiText { text: parent.parent.parent.modelData.sub; color: root.sumi; font.family: root.mono; font.pixelSize: 9 }
                        }
                    }
                    Text {
                        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                        text: parent.modelData.now
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 22
                        font.weight: Font.Light
                    }
                }
            }

            // network: download and upload on one scale
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 90
                radius: root.tileRadius + 10
                color: dash.glass
                border.color: dash.tint(root.ink, 0.08)
                border.width: 1
                clip: true
                readonly property real peak: Math.max(1024, Math.max.apply(null, dash.rxHist.concat(dash.txHist).concat([0])))
                Graph {
                    anchors.fill: parent
                    anchors.topMargin: 40
                    values: dash.rxHist
                    maxValue: parent.peak
                    lineColor: root.color02
                }
                Graph {
                    anchors.fill: parent
                    anchors.topMargin: 40
                    values: dash.txHist
                    maxValue: parent.peak
                    lineColor: root.color03
                    fillAlpha: 0.10
                }
                Row {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 12
                    spacing: 14
                    Row {
                        spacing: 4
                        IconText { text: ""; color: root.color02; fill: 1; font.pixelSize: 16 }
                        UiText { anchors.verticalCenter: parent.verticalCenter; text: dash.rate(dash.rxRate); color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                    }
                    Row {
                        spacing: 4
                        IconText { text: ""; color: root.color03; fill: 1; font.pixelSize: 16 }
                        UiText { anchors.verticalCenter: parent.verticalCenter; text: dash.rate(dash.txRate); color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                    }
                }
                UiText {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14
                    text: "NET"
                    color: root.sumi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 2
                }
            }

            UiText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: (root.kernelRelease ? "linux " + root.kernelRelease : "") + (dash.uptimeS > 0 ? "   ·   up " + dash.uptimeText : "")
                color: root.sumi; font.family: root.mono; font.pixelSize: 10
            }
        }

        // ── media tab ──
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            anchors.topMargin: 64
            spacing: 12
            visible: dash.tab === "media"

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: dash.player === null
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    IconText { anchors.horizontalCenter: parent.horizontalCenter; text: ""; color: root.sumi; font.pixelSize: 48 }
                    UiText { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing playing"; color: root.sumi; font.family: root.mono; font.pixelSize: 12 }
                }
            }

            // big cover, rounded, with a soft shadow
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(300, parent.width)
                Layout.preferredHeight: Layout.preferredWidth
                visible: dash.player !== null
                Rectangle {
                    id: bigCover
                    anchors.fill: parent
                    radius: root.tileRadius + 14
                    color: dash.glass
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowBlur: 0.9
                        shadowColor: Qt.rgba(0, 0, 0, 0.6)
                        shadowVerticalOffset: 6
                        maskEnabled: true
                        maskSource: bigCoverMask
                    }
                    Image {
                        anchors.fill: parent
                        source: dash.player ? (dash.player.trackArtUrl || "") : ""
                        sourceSize.width: 600
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Rectangle {
                    id: bigCoverMask
                    anchors.fill: parent
                    radius: bigCover.radius
                    visible: false
                    layer.enabled: true
                }
            }

            Column {
                Layout.fillWidth: true
                visible: dash.player !== null
                spacing: 3
                UiText {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: dash.player ? (dash.player.trackTitle || "Unknown") : ""
                    color: root.ink; font.family: root.mono; font.pixelSize: 15; font.weight: Font.Medium
                }
                UiText {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: dash.player ? [dash.player.trackArtist, dash.player.trackAlbum].filter(function (x) { return x }).join("  ·  ") : ""
                    color: root.sumi; font.family: root.mono; font.pixelSize: 11
                }
            }

            // seekable progress
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                visible: dash.player !== null && dash.player.length > 0
                Rectangle {
                    id: seekTrack
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    height: 4; radius: 2
                    color: dash.tint(root.ink, 0.18)
                    Rectangle {
                        height: parent.height; radius: 2
                        color: root.seal
                        width: parent.width * (dash.player && dash.player.length > 0 ? Math.min(1, dash.pos / dash.player.length) : 0)
                        Behavior on width { Anim { kind: "size"; ms: 900 } }
                    }
                }
                MouseArea {
                    anchors.fill: seekTrack
                    anchors.margins: -8
                    enabled: dash.player !== null && dash.player.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function (m) {
                        var t = Math.max(0, Math.min(1, (m.x - 8) / seekTrack.width)) * dash.player.length
                        dash.player.position = t
                        dash.pos = t
                    }
                }
                UiText {
                    anchors.left: parent.left; anchors.bottom: parent.bottom
                    text: dash.clock(dash.pos)
                    color: root.sumi; font.family: root.mono; font.pixelSize: 9
                }
                UiText {
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    text: dash.player ? dash.clock(dash.player.length) : ""
                    color: root.sumi; font.family: root.mono; font.pixelSize: 9
                }
            }

            // controls: shuffle · previous · play/pause · next · repeat
            Row {
                Layout.alignment: Qt.AlignHCenter
                visible: dash.player !== null
                spacing: 26
                Repeater {
                    model: [
                        { act: "shuffle", glyph: "", size: 20, shown: dash.player && dash.player.shuffleSupported,
                          on: dash.player && dash.player.shuffle },
                        { act: "previous", glyph: "", size: 28, shown: true, on: false },
                        { act: "toggle", glyph: sel.playing ? "" : "", size: 40, shown: true, on: false },
                        { act: "next", glyph: "", size: 28, shown: true, on: false },
                        { act: "loop", glyph: dash.player && dash.player.loopState === MprisLoopState.Track ? "" : "", size: 20,
                          shown: dash.player && dash.player.loopSupported,
                          on: dash.player && dash.player.loopState !== MprisLoopState.None }
                    ]
                    delegate: IconText {
                        required property var modelData
                        visible: !!modelData.shown
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.glyph
                        fill: 1
                        color: modelData.on || mediaMa.containsMouse ? root.seal : root.ink
                        font.pixelSize: modelData.size
                        scale: mediaMa.pressed ? 0.88 : 1
                        Behavior on scale { Anim { kind: "spatialFast" } }
                        MouseArea {
                            id: mediaMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var p = dash.player, a = parent.modelData.act
                                if (!p) return
                                if (a === "toggle") p.togglePlaying()
                                else if (a === "next") p.next()
                                else if (a === "previous") p.previous()
                                else if (a === "shuffle") p.shuffle = !p.shuffle
                                else if (a === "loop") p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                                                 : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                                                 : MprisLoopState.None
                            }
                        }
                    }
                }
            }

            // synced lyrics take the rest (fetched only while this tab shows)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 0
                visible: dash.player !== null
                clip: true
                SyncedLyrics {
                    anchors.centerIn: parent
                    width: parent.width
                    root: dash.root
                    visibleLines: Math.max(3, Math.floor(parent.height / lineH) | 1)
                    active: dash.visible && dash.tab === "media" && dash.player !== null
                    title: dash.player ? (dash.player.trackTitle || "") : ""
                    artist: dash.player ? (dash.player.trackArtist || "") : ""
                    album: dash.player ? (dash.player.trackAlbum || "") : ""
                    length: dash.player ? (dash.player.length || 0) : 0
                    position: dash.pos
                }
            }
        }
    }

    function clock(sec) {
        if (!(sec > 0)) return "0:00"
        var m = Math.floor(sec / 60), x = Math.floor(sec % 60)
        return m + ":" + (x < 10 ? "0" : "") + x
    }

    // area graph of `values`, newest on the right; maxValue 0 = auto-scale
    component Graph: Canvas {
        property var values: []
        property real maxValue: 100
        property color lineColor: "white"
        property real fillAlpha: 0.22
        onValuesChanged: requestPaint()
        onMaxValueChanged: requestPaint()
        onLineColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var v = values || [], n = v.length
            if (n < 2) return
            var max = maxValue > 0 ? maxValue : Math.max.apply(null, v.concat([1]))
            var step = width / 59                      // 60 samples across, newest flush right
            var x0 = width - (n - 1) * step
            function y(val) { return height - 4 - (height - 10) * Math.max(0, Math.min(1, val / max)) }
            ctx.beginPath()
            ctx.moveTo(x0, height)
            for (var i = 0; i < n; i++) ctx.lineTo(x0 + i * step, y(v[i]))
            ctx.lineTo(x0 + (n - 1) * step, height)
            ctx.closePath()
            var g = ctx.createLinearGradient(0, 0, 0, height)
            g.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, fillAlpha))
            g.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0))
            ctx.fillStyle = g
            ctx.fill()
            ctx.beginPath()
            for (var j = 0; j < n; j++) {
                if (j === 0) ctx.moveTo(x0, y(v[0])); else ctx.lineTo(x0 + j * step, y(v[j]))
            }
            ctx.strokeStyle = lineColor
            ctx.lineWidth = 2
            ctx.lineJoin = "round"
            ctx.stroke()
        }
    }
}
