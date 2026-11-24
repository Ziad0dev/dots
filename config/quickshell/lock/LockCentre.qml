import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// The lock screen's side columns, after Caelestia's lock (modules/lock): on
// the left the weather and what's playing (with controls), on the right the
// machine's load and the notifications that came in. Only on screens wide
// enough to keep them clear of the clock and password card.
//
// Notifications come from the bar's saved history and show only the app and
// the title: anyone at the desk can read a lock screen, so message bodies stay
// hidden. Everything external is plain text.
Item {
    id: centre
    required property var theme
    // where the bar keeps its notification history (NotificationService.qml)
    property string notificationsPath: Quickshell.env("HOME") + "/.cache/qs-rise-notifications.json"
    // the lock started at: notifications after this count as "while you were away"
    readonly property double lockedAt: Date.now()

    readonly property bool roomy: width >= 1500
    readonly property int colWidth: Math.min(380, Math.round(width * 0.2))
    readonly property int sideMargin: Math.round(width * 0.06)

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function ago(ms) {
        if (!(ms > 0)) return ""          // entries carried over from dunst have no time
        var s = Math.max(0, Math.round((Date.now() - ms) / 1000))
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + "m"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }

    property double nowMs: Date.now()
    Timer { interval: 30000; running: centre.visible; repeat: true; onTriggered: centre.nowMs = Date.now() }

    component Card: Rectangle {
        default property alias content: inner.data
        property string title: ""
        width: centre.colWidth
        height: inner.implicitHeight + 36 + (title ? 18 : 0)
        radius: 20
        color: centre.tint(centre.theme.bg, 0.62)
        border.color: centre.tint(centre.theme.ink, 0.12)
        border.width: 1
        Text {
            visible: parent.title !== ""
            x: 18; y: 14
            text: parent.title.toUpperCase()
            textFormat: Text.PlainText
            color: centre.theme.seal
            font.family: centre.theme.mono
            font.pixelSize: 10
            font.letterSpacing: 3
        }
        Column {
            id: inner
            x: 18
            y: parent.title !== "" ? 36 : 18
            width: parent.width - 36
            spacing: 10
        }
    }

    // ── left: weather, now playing ──
    Column {
        visible: centre.roomy
        x: centre.sideMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Card {
            id: weatherCard
            title: "Weather"
            visible: weather.ok
            Row {
                spacing: 14
                Text {
                    text: weather.temp
                    textFormat: Text.PlainText
                    color: centre.theme.ink
                    font.family: centre.theme.mono
                    font.pixelSize: 44
                    font.weight: Font.Light
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: weatherCard.width - 36 - 120
                        text: weather.desc
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: centre.theme.ink
                        font.family: centre.theme.mono
                        font.pixelSize: 13
                    }
                    Text {
                        text: weather.extra
                        textFormat: Text.PlainText
                        color: centre.theme.sumi
                        font.family: centre.theme.mono
                        font.pixelSize: 11
                    }
                }
            }
            Row {
                spacing: 8
                Repeater {
                    model: weather.days
                    delegate: Rectangle {
                        required property var modelData
                        width: (weatherCard.width - 36 - 16) / 3
                        height: 46
                        radius: 10
                        color: centre.tint(centre.theme.ink, 0.05)
                        Column {
                            anchors.centerIn: parent
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.day
                                textFormat: Text.PlainText
                                color: centre.theme.sumi
                                font.family: centre.theme.mono; font.pixelSize: 10
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.range
                                textFormat: Text.PlainText
                                color: centre.theme.ink
                                font.family: centre.theme.mono; font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }

        Card {
            id: mediaCard
            title: "Now playing"
            visible: media.player !== null
            Row {
                spacing: 14
                Rectangle {
                    width: 72; height: 72; radius: 12
                    color: centre.tint(centre.theme.ink, 0.06)
                    clip: true
                    Image {
                        anchors.fill: parent
                        // the player's own art: a local file or https, nothing else
                        source: /^(file|https):\/\//.test(media.art) ? media.art : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(144, 144)
                    }
                }
                Column {
                    width: mediaCard.width - 36 - 86
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: media.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: centre.theme.ink
                        font.family: centre.theme.mono; font.pixelSize: 14
                    }
                    Text {
                        width: parent.width
                        text: media.artist
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: centre.theme.sumi
                        font.family: centre.theme.mono; font.pixelSize: 12
                    }
                }
            }
            // progress
            Rectangle {
                width: parent.width; height: 3; radius: 2
                visible: media.length > 0
                color: centre.tint(centre.theme.ink, 0.12)
                Rectangle {
                    height: parent.height; radius: 2
                    width: parent.width * Math.min(1, media.position / Math.max(1, media.length))
                    color: centre.theme.seal
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28
                Repeater {
                    model: [
                        { glyph: "⏮", act: "prev", ok: media.player && media.player.canGoPrevious },
                        { glyph: media.playing ? "⏸" : "▶", act: "toggle", ok: media.player && media.player.canTogglePlaying },
                        { glyph: "⏭", act: "next", ok: media.player && media.player.canGoNext }
                    ]
                    delegate: Text {
                        required property var modelData
                        text: modelData.glyph
                        color: modelData.ok ? (ctl.containsMouse ? centre.theme.seal : centre.theme.ink) : centre.tint(centre.theme.ink, 0.25)
                        font.pixelSize: 20
                        MouseArea {
                            id: ctl
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            enabled: !!modelData.ok
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var p = media.player
                                if (!p) return
                                if (modelData.act === "prev") p.previous()
                                else if (modelData.act === "next") p.next()
                                else p.togglePlaying()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── right: load, notifications ──
    Column {
        visible: centre.roomy
        x: parent.width - centre.sideMargin - centre.colWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Card {
            title: "System"
            Repeater {
                model: [
                    { label: "CPU", value: res.cpu },
                    { label: "Memory", value: res.mem },
                    { label: "Disk", value: res.disk }
                ]
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 4
                    Row {
                        width: parent.width
                        Text {
                            width: parent.width / 2
                            text: modelData.label
                            color: centre.theme.sumi
                            font.family: centre.theme.mono; font.pixelSize: 11
                        }
                        Text {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignRight
                            text: modelData.value < 0 ? "··" : Math.round(modelData.value) + "%"
                            color: modelData.value >= 90 ? centre.theme.err : centre.theme.ink
                            font.family: centre.theme.mono; font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 4; radius: 2
                        color: centre.tint(centre.theme.ink, 0.1)
                        Rectangle {
                            height: parent.height; radius: 2
                            width: parent.width * Math.max(0, Math.min(1, modelData.value / 100))
                            color: modelData.value >= 90 ? centre.theme.err : centre.theme.seal
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
            Text {
                text: res.uptime
                textFormat: Text.PlainText
                color: centre.theme.sumi
                font.family: centre.theme.mono; font.pixelSize: 11
            }
        }

        Card {
            id: notifCard
            title: notes.away > 0 ? notes.away + " while you were away" : "Notifications"
            Text {
                visible: notes.items.length === 0
                text: "Nothing new"
                color: centre.theme.sumi
                font.family: centre.theme.mono; font.pixelSize: 12
            }
            Repeater {
                model: notes.items
                delegate: Row {
                    required property var modelData
                    width: notifCard.width - 36
                    spacing: 10
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.time >= centre.lockedAt ? centre.theme.seal : centre.tint(centre.theme.ink, 0.2)
                    }
                    Column {
                        width: parent.width - 16 - 40
                        Text {
                            width: parent.width
                            text: modelData.appName
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: centre.theme.sumi
                            font.family: centre.theme.mono; font.pixelSize: 10
                        }
                        Text {
                            width: parent.width
                            text: modelData.summary
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: centre.theme.ink
                            font.family: centre.theme.mono; font.pixelSize: 12
                        }
                    }
                    Text {
                        width: 40
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: { void(centre.nowMs); return centre.ago(modelData.time) }
                        color: centre.theme.sumi
                        font.family: centre.theme.mono; font.pixelSize: 10
                    }
                }
            }
        }
    }

    // ── data ──
    QtObject {
        id: weather
        property bool ok: false
        property string temp: ""
        property string desc: ""
        property string extra: ""
        property var days: []
    }
    Process {
        id: weatherProc
        running: centre.roomy
        command: ["curl", "-fs", "--max-time", "5", "https://wttr.in?format=j1"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text)
                    var c = j.current_condition[0]
                    weather.temp = c.temp_C + "°"
                    weather.desc = String((c.weatherDesc && c.weatherDesc[0] && c.weatherDesc[0].value) || "")
                    weather.extra = "feels " + c.FeelsLikeC + "° · " + c.humidity + "% · " + c.windspeedKmph + " km/h"
                    var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    weather.days = (j.weather || []).slice(0, 3).map(function (d, i) {
                        var day = i === 0 ? "Today" : names[new Date(d.date + "T12:00:00").getDay()]
                        // "-5° / -1°": a dash between two negatives reads as a minus
                        return { day: day, range: d.mintempC + "° / " + d.maxtempC + "°" }
                    })
                    weather.ok = weather.temp !== "°"
                } catch (e) {
                    weather.ok = false        // offline or a bad answer: no card
                }
            }
        }
    }

    QtObject {
        id: media
        // a playing player first, else any
        readonly property var player: {
            var ps = Mpris.players.values
            for (var i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
            return ps.length > 0 ? ps[0] : null
        }
        readonly property bool playing: !!player && player.isPlaying
        readonly property string title: player ? String(player.trackTitle || "Unknown") : ""
        readonly property string artist: player ? String(player.trackArtist || "") : ""
        readonly property string art: player ? String(player.trackArtUrl || "") : ""
        readonly property real length: player && player.lengthSupported ? player.length : 0
        property real position: 0
    }
    Timer {
        interval: 1000
        running: centre.roomy && media.playing
        repeat: true
        triggeredOnStart: true
        onTriggered: if (media.player && media.player.positionSupported) media.position = media.player.position
    }

    QtObject {
        id: res
        property real cpu: -1
        property real mem: -1
        property real disk: -1
        property string uptime: ""
        property var lastCpu: null
    }
    FileView { id: statFile; path: "/proc/stat"; printErrors: false }
    FileView { id: memFile; path: "/proc/meminfo"; printErrors: false }
    FileView { id: upFile; path: "/proc/uptime"; printErrors: false }
    Process {
        id: dfProc
        command: ["df", "--output=pcent", "/"]
        stdinEnabled: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = /(\d+)%/.exec(this.text)
                if (m) res.disk = Number(m[1])
            }
        }
    }
    Timer {
        interval: 2000
        running: centre.roomy
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload(); memFile.reload(); upFile.reload()
            var cpuLine = String(statFile.text()).split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            if (cpuLine.length >= 4) {
                var idle = cpuLine[3] + (cpuLine[4] || 0)
                var total = cpuLine.reduce(function (a, b) { return a + b }, 0)
                if (res.lastCpu) {
                    var dt = total - res.lastCpu.total, di = idle - res.lastCpu.idle
                    if (dt > 0) res.cpu = 100 * (1 - di / dt)
                }
                res.lastCpu = { total: total, idle: idle }
            }
            var mt = /MemTotal:\s+(\d+)/.exec(memFile.text()), ma = /MemAvailable:\s+(\d+)/.exec(memFile.text())
            if (mt && ma) res.mem = 100 * (1 - Number(ma[1]) / Number(mt[1]))
            var up = Number(String(upFile.text()).split(" ")[0])
            if (up > 0) {
                var d = Math.floor(up / 86400), h = Math.floor(up % 86400 / 3600), mi = Math.floor(up % 3600 / 60)
                res.uptime = "up " + (d ? d + "d " : "") + h + "h " + mi + "m"
            }
            if (!dfProc.running) dfProc.running = true
        }
    }

    QtObject {
        id: notes
        property var items: []
        property int away: 0
    }
    FileView {
        path: centre.notificationsPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                var j = JSON.parse(text())
                var h = (j && Array.isArray(j.history)) ? j.history : []
                notes.away = h.filter(function (n) { return n && n.time >= centre.lockedAt }).length
                notes.items = h.slice(0, 5).map(function (n) {
                    return {
                        appName: String((n && n.appName) || "App"),
                        summary: String((n && n.summary) || ""),
                        time: Number((n && n.time) || 0)
                    }
                })
            } catch (e) {
                notes.items = []
                notes.away = 0
            }
        }
    }
}
