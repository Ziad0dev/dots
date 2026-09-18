import QtQuick
import Quickshell
import Quickshell.Io
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root
    property string gid: "G11"

    property string mode:   "none"  // "wifi" | "ethernet" | "none"
    property string ssid:   ""
    property int    signal: 0
    property string iface:  ""

    // ── speed tracking ──
    property real prevRx:  -1
    property real prevTx:  -1
    property real prevMs:   0
    property real dlRate:   0
    property real ulRate:   0
    property var  dlHistory: []
    property var  ulHistory: []
    readonly property int maxSamples: 30

    function formatSpeed(bps) {
        var mb = bps / 1048576
        var s = mb < 10 ? mb.toFixed(2) : mb.toFixed(1)
        return s.padStart(5) + "M"  // always 6 chars: " 0.00M" … "100.0M"
    }

    function updateSpeeds(rx, tx, now) {
        if (prevRx >= 0 && prevMs > 0) {
            var dt = (now - prevMs) / 1000
            if (dt > 0) {
                dlRate = Math.max(0, (rx - prevRx) / dt)
                ulRate = Math.max(0, (tx - prevTx) / dt)
                var dh = dlHistory.slice(); dh.push(dlRate); if (dh.length > maxSamples) dh.shift(); dlHistory = dh
                var uh = ulHistory.slice(); uh.push(ulRate); if (uh.length > maxSamples) uh.shift(); ulHistory = uh
            }
        }
        prevRx = rx; prevTx = tx; prevMs = now
    }

    readonly property var wifiIcons: [
        "signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar",
        "network_wifi_3_bar", "signal_wifi_4_bar"
    ]
    readonly property string wifiIconName: signal > 0
        ? wifiIcons[Math.min(4, Math.floor(signal / 22))]
        : "signal_wifi_off"

    readonly property string tooltipText: {
        if (mode === "wifi")     return ssid + " · " + signal + "%"
        if (mode === "ethernet") return "↓ " + formatSpeed(dlRate) + "/s  ↑ " + formatSpeed(ulRate) + "/s"
        return "Offline"
    }

    // hideable via modNetwork — but only on ethernet/none; on WiFi always shown
    implicitWidth: (root.modNetwork || mode === "wifi") ? (row.implicitWidth + 18) : 0
    // mirror the connection type so the ControlPanel can gate the Network toggle
    Binding { target: rootMod.root; property: "networkMode"; value: rootMod.mode }
    implicitHeight: 28

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.implicitWidth) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.widgetFillColor(rootMod.gid)
        border.color: root.widgetBorderColor(rootMod.gid)
        border.width: root.widgetBorderWidth(rootMod.gid)
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // ── label ──
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compactNetwork
            text: "NET"
            color: mode === "none"
                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.7)
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 0.5
        }

        // ── ethernet: dual sparkline ──
        Canvas {
            id: netGraph
            visible: rootMod.mode === "ethernet" && !root.compactNetwork
            width: 36; height: 14
            anchors.verticalCenter: parent.verticalCenter

            property color tint: root.seal
            onTintChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var dl = rootMod.dlHistory
                var ul = rootMod.ulHistory
                if (dl.length < 2 && ul.length < 2) return

                // shared scale so both lines are visually comparable
                var maxV = 1
                for (var n = 0; n < dl.length; n++) if (dl[n] > maxV) maxV = dl[n]
                for (var n = 0; n < ul.length; n++) if (ul[n] > maxV) maxV = ul[n]
                maxV *= 1.15

                function drawLine(history, color, fillAlpha, strokeW) {
                    if (history.length < 2) return
                    var pts = []
                    for (var i = 0; i < history.length; i++) {
                        pts.push({
                            x: (i / (rootMod.maxSamples - 1)) * width,
                            y: height - (history[i] / maxV) * height
                        })
                    }
                    // fill
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, height)
                    ctx.lineTo(pts[0].x, pts[0].y)
                    for (var j = 1; j < pts.length; j++) {
                        var cx = (pts[j-1].x + pts[j].x) / 2
                        ctx.bezierCurveTo(cx, pts[j-1].y, cx, pts[j].y, pts[j].x, pts[j].y)
                    }
                    ctx.lineTo(pts[pts.length-1].x, height)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, fillAlpha)
                    ctx.fill()
                    // stroke
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (var k = 1; k < pts.length; k++) {
                        var mx = (pts[k-1].x + pts[k].x) / 2
                        ctx.bezierCurveTo(mx, pts[k-1].y, mx, pts[k].y, pts[k].x, pts[k].y)
                    }
                    ctx.strokeStyle = color
                    ctx.lineWidth = strokeW
                    ctx.lineCap = "round"; ctx.lineJoin = "round"
                    ctx.stroke()
                }

                drawLine(dl, root.seal,   0.12, 1.5)   // download — seal
                drawLine(ul, root.indigo, 0.10, 1.0)   // upload   — indigo
            }

            Connections {
                target: rootMod
                function onDlHistoryChanged() { netGraph.requestPaint() }
                function onUlHistoryChanged() { netGraph.requestPaint() }
            }
            Component.onCompleted: requestPaint()
        }

        // ── ethernet: down/up speed, stacked to save width ──
        Column {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.mode === "ethernet" && !root.compactNetwork
            spacing: 0
            UiText {
                width: 54; height: 11
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: "↓" + rootMod.formatSpeed(rootMod.dlRate)
                color: root.seal
                font.family: root.mono
                font.pixelSize: 10
            }
            UiText {
                width: 54; height: 11
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: "↑" + rootMod.formatSpeed(rootMod.ulRate)
                color: root.indigo
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        // ── wifi: icon ──
        IconText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.mode === "wifi"
            text: IconMap.icon(rootMod.wifiIconName)
            color: root.compactNetwork ? root.seal : root.ink
            font.pixelSize: root.compactNetwork ? 15 : 14
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        IconText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.compactNetwork && rootMod.mode !== "wifi"
            text: IconMap.icon(rootMod.mode === "ethernet" ? "lan" : "signal_wifi_off")
            color: rootMod.mode === "ethernet"
                ? root.seal
                : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.65)
            font.pixelSize: rootMod.mode === "ethernet" ? 14 : 15
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        // ── wifi: ssid ──
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.mode === "wifi" && !root.compactNetwork
            text: rootMod.ssid
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 1
        }
    }

    property string ifaceCur: ""

    function netRefresh() { routeFile.reload() }

    function fetchSsid() {
        if (rootMod.ifaceCur === "") { rootMod.ssid = ""; return }
        ssidProc.running = false
        ssidProc.command = ["bash", "-c",
            "iw dev '" + rootMod.ifaceCur + "' link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p' | head -1"]
        ssidProc.running = true
    }

    Process {
        id: ssidProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: rootMod.ssid = String(this.text || "").trim()
        }
    }

    FileView {
        id: routeFile
        path: "/proc/net/route"
        onLoaded: {
            var best = "", bestMetric = -1
            var lines = String(routeFile.text() || "").split("\n")
            for (var i = 1; i < lines.length; i++) {
                var f = lines[i].trim().split(/\s+/)
                if (f.length < 8 || f[1] !== "00000000") continue
                var m = parseInt(f[6]); if (isNaN(m)) m = 0
                if (bestMetric < 0 || m < bestMetric) { bestMetric = m; best = f[0] }
            }
            if (best === "") {
                rootMod.ifaceCur = ""
                rootMod.mode = "none"
                rootMod.ssid = ""
                rootMod.prevRx = -1; rootMod.prevTx = -1
                return
            }
            if (best !== rootMod.ifaceCur) {
                rootMod.ifaceCur = best
                rootMod.prevRx = -1; rootMod.prevTx = -1
                rootMod.ssid = ""
                rootMod.fetchSsid()
            }
            rootMod.iface = best
            wirelessFile.reload()
            devFile.reload()
        }
        onLoadFailed: {
            rootMod.ifaceCur = ""
            rootMod.mode = "none"
            rootMod.prevRx = -1; rootMod.prevTx = -1
        }
    }

    FileView {
        id: wirelessFile
        path: "/proc/net/wireless"
        onLoaded: {
            var isWifi = false, qual = 0
            var lines = String(wirelessFile.text() || "").split("\n")
            for (var i = 2; i < lines.length; i++) {
                var line = lines[i].trim()
                var c = line.indexOf(":")
                if (c < 0) continue
                if (line.substring(0, c).trim() !== rootMod.ifaceCur) continue
                isWifi = true
                var f = line.substring(c + 1).trim().split(/\s+/)
                var lvl = parseFloat(String(f[2] || "").replace(".", ""))
                if (!isNaN(lvl)) {
                    qual = Math.round((lvl + 110) * 100 / 70)
                    if (qual < 0) qual = 0
                    if (qual > 100) qual = 100
                }
                break
            }
            rootMod.mode = isWifi ? "wifi" : "ethernet"
            if (isWifi) rootMod.signal = qual
        }
        onLoadFailed: if (rootMod.ifaceCur !== "") rootMod.mode = "ethernet"
    }

    FileView {
        id: devFile
        path: "/proc/net/dev"
        onLoaded: {
            if (rootMod.ifaceCur === "") return
            var lines = String(devFile.text() || "").split("\n")
            for (var i = 2; i < lines.length; i++) {
                var line = lines[i].trim()
                var c = line.indexOf(":")
                if (c < 0) continue
                if (line.substring(0, c).trim() !== rootMod.ifaceCur) continue
                var f = line.substring(c + 1).trim().split(/\s+/)
                rootMod.updateSpeeds(parseFloat(f[0]) || 0, parseFloat(f[8]) || 0, Date.now())
                break
            }
        }
    }

    // Dynamic poll cadence. Fast (2 s) whenever something needs fresh data: the pill is shown
    // (root.modNetwork), the panel is open (root.networkVisible — also covers a running speed
    // test, which keeps the panel open), or we're on Wi-Fi (signal % moves; the Wi-Fi branch is
    // also the only one that spawns `iw`). Slow (15 s) ONLY when the module is hidden AND the
    // panel is closed AND we're on Ethernet or offline — so the saving (fewer idle bash/ip/awk
    // spawns) is limited to a hidden Ethernet module or the offline state; Wi-Fi always polls
    // fast. When hidden on Ethernet/offline, poll only once per minute to catch a later Wi-Fi
    // connection without keeping the old high-rate hidden poller alive. Changing a Timer's
    // interval does not force a tick, so refresh once immediately on becoming relevant.
    readonly property bool fastPoll: root.modNetwork || root.networkVisible || mode === "wifi"
    onFastPollChanged: if (fastPoll) rootMod.netRefresh()

    Timer {
        interval: rootMod.fastPoll ? 2000 : 60000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: rootMod.netRefresh()
    }

    Timer {
        interval: 30000
        running: rootMod.mode === "wifi"
        repeat: true
        onTriggered: rootMod.fetchSsid()
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process { id: clickRunner; command: ["bash", "-c", root.launchWifiCmd] }

    Process { id: netTui; command: ["bash", "-c", "ghostty --class=com.dots.float.sm -e impala"] }


    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: (e) => {
            if (e.button === Qt.RightButton) { netTui.running = false; netTui.running = true; return }
            tip.hide()
            if (e.button === Qt.RightButton) { clickRunner.running = false; clickRunner.running = true }
            else root.networkVisible = !root.networkVisible
        }
    }
}
