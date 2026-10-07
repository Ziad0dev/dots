import QtQuick
import "../modules"
import "dash"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Dashboard (SUPER+I, hover the lower-left frame corner, `ipc call dashboard toggle`).
// Laid out after Caelestia's: a wide card with Dashboard · Media · Performance ·
// Weather tabs, Material 3 shapes and type, colour roles derived from the active
// palette so it follows every theme. With the frame on it grows out of the
// bottom-left corner (FrameCard "bottom"). The tabs live in panels/dash/.
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
    readonly property int bottomBand: root.barPosition === "bottom" ? barBottom : (framed ? root.frameThickness : 0)

    // ── Material 3 colour roles (dash/M3Palette), re-exported for the tabs ──
    M3Palette { id: m3; root: dash.root }
    property alias primary: m3.primary
    property alias secondary: m3.secondary
    property alias tertiary: m3.tertiary
    property alias error: m3.error
    property alias onPrimary: m3.onPrimary
    property alias onSurface: m3.onSurface
    property alias onSurfaceVariant: m3.onSurfaceVariant
    property alias outline: m3.outline
    property alias outlineVariant: m3.outlineVariant
    property alias surfaceContainer: m3.surfaceContainer
    property alias surfaceContainerHigh: m3.surfaceContainerHigh
    property alias surfaceContainerHighest: m3.surfaceContainerHighest
    property alias primaryContainer: m3.primaryContainer
    property alias secondaryContainer: m3.secondaryContainer
    property alias tertiaryContainer: m3.tertiaryContainer
    property alias onPrimaryContainer: m3.onPrimaryContainer
    property alias onSecondaryContainer: m3.onSecondaryContainer
    property alias onTertiaryContainer: m3.onTertiaryContainer
    property alias blood: m3.blood
    property alias bloodText: m3.bloodText
    property alias bone: m3.bone
    property alias ash: m3.ash

    // ── clock / session ──
    property date now: new Date()
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: dash.visible
        onTriggered: dash.now = new Date()
    }
    readonly property string user: Quickshell.env("USER") || ""
    property string host: ""
    property real uptimeS: 0
    readonly property string uptimeText: {
        var m = Math.floor(uptimeS / 60), h = Math.floor(m / 60), d = Math.floor(h / 24)
        return d > 0 ? d + "d " + (h % 24) + "h" : h > 0 ? h + "h " + (m % 60) + "m" : m + "m"
    }
    property var quote: ({ text: "", author: "" })
    Process {
        id: sessionProc
        command: ["bash", "-c", "cat /proc/sys/kernel/hostname; cut -d' ' -f1 /proc/uptime; shuf -n1 \"$1\" 2>/dev/null || echo",
                  "_", Qt.resolvedUrl("../quotes.txt").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = String(this.text || "").trim().split("\n")
                dash.host = l[0] || ""
                dash.uptimeS = parseFloat(l[1] || "0") || 0
                var q = (l[2] || "").split("|")
                dash.quote = { text: (q[0] || "").trim(), author: (q[1] || "").trim() }
            }
        }
    }

    // ── weather (wttr.in, fetched while open, at most every 10 min) ──
    property var wx: null
    property double wxFetched: 0
    readonly property bool wxLoading: wxProc.running
    Process {
        id: wxProc
        command: ["curl", "-fs", "--max-time", "5", "https://wttr.in?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(String(this.text || ""))
                    var c = d.current_condition[0], days = d.weather || [], today = days[0]
                    var area = d.nearest_area && d.nearest_area[0]
                    var astro = today && today.astronomy && today.astronomy[0]
                    dash.wx = {
                        code: parseInt(c.weatherCode),
                        tempC: c.temp_C, tempF: c.temp_F,
                        feelsC: c.FeelsLikeC, feelsF: c.FeelsLikeF,
                        desc: c.weatherDesc && c.weatherDesc[0] ? c.weatherDesc[0].value : "",
                        humidity: c.humidity, wind: c.windspeedKmph, windDir: c.winddir16Point || "",
                        pressure: c.pressure, uv: c.uvIndex, visibility: c.visibility, precip: c.precipMM,
                        minC: today ? today.mintempC : "", maxC: today ? today.maxtempC : "",
                        minF: today ? today.mintempF : "", maxF: today ? today.maxtempF : "",
                        sunrise: astro ? astro.sunrise : "", sunset: astro ? astro.sunset : "",
                        place: area && area.areaName && area.areaName[0] ? area.areaName[0].value : "",
                        forecast: days.map(function (w) {
                            var noon = w.hourly && (w.hourly[4] || w.hourly[0])
                            var rain = 0
                            for (var i = 0; w.hourly && i < w.hourly.length; i++)
                                rain = Math.max(rain, parseInt(w.hourly[i].chanceofrain) || 0)
                            return { date: w.date, minC: w.mintempC, maxC: w.maxtempC, minF: w.mintempF, maxF: w.maxtempF,
                                     code: noon ? parseInt(noon.weatherCode) : 113, rain: rain }
                        })
                    }
                    dash.wxFetched = Date.now()
                } catch (e) { }
            }
        }
    }
    // wttr.in condition code → Material Symbols name (day forms for forecasts)
    function wxIcon(code, day) {
        var h = now.getHours(), night = !day && (h < 6 || h >= 19)
        if (code === 113) return night ? "clear_night" : "clear_day"
        if (code === 116) return night ? "partly_cloudy_night" : "partly_cloudy_day"
        if ([119, 122].indexOf(code) >= 0) return "cloud"
        if ([143, 248, 260].indexOf(code) >= 0) return "foggy"
        if ([200, 386, 389, 392, 395].indexOf(code) >= 0) return "thunderstorm"
        if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350,
             362, 365, 368, 371, 374, 377].indexOf(code) >= 0) return "weather_snowy"
        return "rainy"
    }
    function deg(c, f) { return (root.weatherImperial ? f : c) + "°" }

    onVisibleChanged: if (visible) {
        sessionProc.running = false; sessionProc.running = true
        if (Date.now() - wxFetched > 600000) { wxProc.running = false; wxProc.running = true }
    }

    // ── now playing ──
    MprisSelect { id: sel }
    readonly property var player: sel.player
    readonly property bool playing: sel.playing
    property real pos: 0
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: dash.visible && dash.player !== null
        onTriggered: dash.pos = dash.player ? (dash.player.position || 0) : 0
    }
    function clock(sec) {
        if (!(sec > 0)) return "0:00"
        var m = Math.floor(sec / 60), x = Math.floor(sec % 60)
        return m + ":" + (x < 10 ? "0" : "") + x
    }

    // ── shortcuts ──
    // detached: the dashboard unloads after closing, which would kill a child
    function run(cmd) {
        root.dashboardVisible = false
        Quickshell.execDetached(["bash", "-c", cmd])
    }
    function action(a) {
        if (a === "lock") run("loginctl lock-session")
        else if (a === "shot") run("sleep 0.4; dots-shot region")
        else if (a === "themes") { root.dashboardVisible = false; root.drawerVisible = true }
        else if (a === "power") { root.dashboardVisible = false; root.sessionVisible = true }
        else { root.dashboardVisible = false; root.controlVisible = true }
    }

    // ── tabs ──
    property string tab: "dashboard"
    readonly property var tabs: [
        { id: "dashboard", label: "Almanac", sign: "☉" },
        { id: "media", label: "Hymns", sign: "♀" },
        { id: "performance", label: "Engine", sign: "☿" },
        { id: "weather", label: "Omens", sign: "☽" }
    ]
    readonly property int tabIndex: Math.max(0, tabs.findIndex(function (t) { return t.id === dash.tab }))
    function stepTab(d) { tab = tabs[(tabIndex + d + tabs.length) % tabs.length].id }

    // ── network rates from /proc/net/dev (only while the performance tab shows) ──
    function push(arr, v) { var a = arr.slice(); a.push(v); if (a.length > root.histLen) a.shift(); return a }
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

    // hover-opened: close once the pointer has left the card and the frame bands
    // it grew out of (the left band below it and the bottom band under it)
    Item {
        x: 0; y: card.y
        width: card.x; height: parent.height - y
        HoverHandler { id: leftStripHover }
    }
    Item {
        x: 0; y: card.y + card.height
        width: card.x + card.width; height: parent.height - y
        HoverHandler { id: bottomStripHover }
    }
    Timer {
        interval: 350
        running: root.dashboardHoverOpened && root.dashboardVisible && !cardHover.hovered
            && !leftStripHover.hovered && !bottomStripHover.hovered
        onTriggered: root.dashboardVisible = false
    }

    FrameCard { root: dash.root; card: card; reveal: dash.reveal; edge: "bottom" }
    Rectangle {
        id: card
        // the tabs take the panel as `dash`; `dash: dash` there would bind the
        // tab's own property to itself, so they get it through this
        readonly property var panel: dash
        readonly property int pad: 16
        // one size for every tab (the largest), so switching tabs never moves the
        // tab bar out from under the pointer; smaller tabs stretch to fill it
        readonly property real contentW: Math.max(ovTab.implicitWidth, medTab.implicitWidth, perfTab.implicitWidth, wxTab.implicitWidth)
        readonly property real contentH: Math.max(ovTab.implicitHeight, medTab.implicitHeight, perfTab.implicitHeight, wxTab.implicitHeight)
        width: contentW + 2 * pad
        height: tabBar.height + 12 + contentH + 2 * pad
        Behavior on width { Anim { kind: "size"; ms: 420 } }
        Behavior on height { Anim { kind: "size"; ms: 420 } }
        x: dash.framed ? root.frameThickness : dash.gap
        y: parent.height - dash.bottomBand - (dash.framed ? 0 : dash.gap) - height
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW
        clip: true
        PillShadow { theme: root ; visible: root.styleShadow && !root.frameOn }

        opacity: dash.reveal
        transform: Translate { y: (1 - dash.reveal) * 56 }
        focus: root.dashboardVisible
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.dashboardVisible = false; event.accepted = true }
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) { dash.tab = dash.tabs[event.key - Qt.Key_1].id; event.accepted = true }
            else if (event.key === Qt.Key_Tab) { dash.stepTab(1); event.accepted = true }
            else if (event.key === Qt.Key_Backtab) { dash.stepTab(-1); event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }
        HoverHandler { id: cardHover }

        // ── tab bar: icon over label, a sliding indicator, a hairline ──
        Item {
            id: tabBar
            x: card.pad; y: card.pad - 6
            width: card.width - 2 * card.pad
            height: 5 + tabRow.height + 5 + 3 + 1
            readonly property real tabW: width / dash.tabs.length

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function (w) { dash.stepTab(w.angleDelta.y < 0 ? 1 : -1) }
            }
            Row {
                id: tabRow
                y: 5
                Repeater {
                    id: tabRepeater
                    model: dash.tabs
                    delegate: Item {
                        id: tabItem
                        required property var modelData
                        required property int index
                        readonly property bool current: dash.tab === modelData.id
                        readonly property real contentW: tabSign.implicitWidth + 8 + tabLabel.implicitWidth
                        width: tabBar.tabW
                        height: tabLabel.implicitHeight
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width; height: parent.height + 10
                            radius: 2
                            color: tabItem.current ? dash.blood : dash.onSurface
                            opacity: tabMa.pressed ? 0.14 : tabMa.containsMouse ? 0.08 : 0
                            Behavior on opacity { Anim { ms: 120 } }
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Glyph {
                                id: tabSign
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabItem.modelData.sign
                                color: tabItem.current ? dash.blood : dash.onSurfaceVariant
                                Behavior on color { CAnim {} }
                                font.pointSize: 14
                            }
                            GText {
                                id: tabLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabItem.modelData.label
                                color: tabItem.current ? dash.bone : dash.onSurfaceVariant
                                Behavior on color { CAnim {} }
                                font.pointSize: 16
                            }
                        }
                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dash.tab = tabItem.modelData.id
                        }
                    }
                }
            }
            Item {
                id: indicator
                readonly property Item cur: tabRepeater.itemAt(dash.tabIndex)
                width: cur ? cur.contentW : tabBar.tabW
                x: dash.tabIndex * tabBar.tabW + (tabBar.tabW - width) / 2
                y: tabRow.y + tabRow.height + 5
                height: 3
                Behavior on x { Anim { kind: "spatial" } }
                Behavior on width { Anim { kind: "spatial" } }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 1
                    color: dash.blood
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 6; height: 6
                    rotation: 45
                    color: dash.blood
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: dash.outlineVariant
            }
        }

        // ── the current tab ──
        // all four live while the dashboard is open (it unloads on close); a hidden
        // tab stops its own timers, cava and lyrics, which all follow `visible`
        Item {
            id: view
            x: card.pad
            y: tabBar.y + tabBar.height + 12
            width: card.contentW
            height: card.contentH
            Overview { id: ovTab; dash: card.panel; anchors.fill: parent; shown: dash.tab === "dashboard" }
            MediaTab { id: medTab; dash: card.panel; anchors.fill: parent; shown: dash.tab === "media" }
            PerformanceTab { id: perfTab; dash: card.panel; anchors.fill: parent; shown: dash.tab === "performance" }
            WeatherTab { id: wxTab; dash: card.panel; anchors.fill: parent; shown: dash.tab === "weather" }
        }
    }
}
