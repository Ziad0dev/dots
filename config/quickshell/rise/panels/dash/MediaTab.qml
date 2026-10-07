import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../modules"

// Media tab: the cover in a cookie shape ringed by a live visualiser, the track
// with a wavy seek bar and full controls, and synced lyrics. Soft shapes drift
// behind it all while something plays.
Item {
    id: mt
    required property var dash
    readonly property var root: dash.root
    readonly property var player: dash.player
    readonly property bool playing: dash.playing
    property bool shown: true
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    implicitWidth: 1000
    implicitHeight: 320

    // one clock for everything that moves here, at 30 steps a second: the open
    // dashboard is a fullscreen layer, so this caps how often it redraws
    property real phase: 0
    Timer {
        id: tick
        interval: 33; repeat: true
        running: mt.playing && mt.visible
        onTriggered: {
            mt.phase = (mt.phase - 0.12) % (2 * Math.PI)
            drift.step(interval / 1000)
        }
    }

    // ── drifting background shapes ──
    Item {
        id: drift
        anchors.fill: parent
        clip: true
        readonly property var kinds: ["circle", "cookie", "sunny", "burst", "gem", "clam", "diamond", "pentagon", "pill"]
        readonly property var tints: [mt.dash.primaryContainer, mt.dash.secondaryContainer, mt.dash.tertiaryContainer, mt.dash.outlineVariant]
        function rand(a, b) { return a + Math.random() * (b - a) }
        function step(dt) {
            for (var i = 0; i < shapes.count; i++) {
                var s = shapes.itemAt(i)
                if (!s) continue
                s.x += s.vx * dt; s.y += s.vy * dt; s.rotation += s.vr * dt
                if (s.x + s.width < 0) s.x = width; else if (s.x > width) s.x = -s.width
                if (s.y + s.height < 0) s.y = height; else if (s.y > height) s.y = -s.height
            }
        }
        Repeater {
            id: shapes
            model: 14
            delegate: DashShape {
                required property int index
                property real vx: drift.rand(4, 18) * (Math.random() < 0.5 ? -1 : 1)
                property real vy: drift.rand(4, 18) * (Math.random() < 0.5 ? -1 : 1)
                property real vr: drift.rand(-12, 12)
                readonly property int tintIdx: Math.floor(Math.random() * 4)
                width: 36 + index / 14 * 88; height: width
                kind: drift.kinds[Math.floor(Math.random() * drift.kinds.length)]
                color: drift.tints[tintIdx]
                opacity: [0.4, 0.4, 0.1, 0.3][tintIdx]
                rotation: Math.random() * 360
                Component.onCompleted: { x = drift.rand(0, mt.implicitWidth - width); y = drift.rand(0, mt.implicitHeight - height) }
            }
        }
    }

    // ── nothing playing ──
    Column {
        anchors.centerIn: parent
        visible: !mt.player
        spacing: 8
        DashShape {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 104; height: 104
            kind: "clam"
            color: mt.dash.primaryContainer
            IconText {
                anchors.centerIn: parent
                text: "queue_music"
                color: mt.dash.onPrimaryContainer
                font.pointSize: 44
            }
        }
        DText {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 6
            text: "Nothing playing"
            color: mt.dash.onSurface
            font.pointSize: 28; font.weight: Font.Medium
        }
        DText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Start some music or a video and it shows up here"
            color: mt.dash.onSurfaceVariant
            font.pointSize: 14
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 28
        visible: !!mt.player

        // ── cover + visualiser ──
        Item {
            id: coverSection
            width: 300; height: parent.height

            // cava, only while this tab shows and something plays
            property var bars: []
            readonly property int barCount: 48
            Process {
                running: mt.visible && mt.playing
                command: ["bash", "-c",
                    "command -v cava >/dev/null 2>&1 || exit 0; " +
                    "exec cava -p <(printf '%s\\n' " +
                    "'[general]' 'bars = 48' 'framerate = 30' 'autosens = 1' 'sleep_timer = 0' " +
                    "'[input]' 'method = pipewire' 'source = auto' " +
                    "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
                    "'data_format = ascii' 'ascii_max_range = 100' " +
                    "'[smoothing]' 'monstercat = 1' 'noise_reduction = 60')"]
                stdout: SplitParser {
                    onRead: function (line) {
                        var p = line.split(";"), out = []
                        for (var i = 0; i < coverSection.barCount; i++) {
                            var v = parseInt(p[i])
                            out.push(isNaN(v) ? 0 : Math.min(1, v / 100))
                        }
                        coverSection.bars = out
                    }
                }
                onRunningChanged: if (!running) coverSection.bars = []
            }

            Canvas {
                id: vis
                anchors.fill: parent
                property var bars: coverSection.bars
                property color c: mt.dash.primary
                onBarsChanged: requestPaint()
                onCChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var n = coverSection.barCount, b = bars || []
                    if (b.length === 0) return
                    var cx = width / 2, cy = height / 2
                    var reach = (Math.min(width, height) - cover.width) / 2 - 12
                    ctx.strokeStyle = c
                    ctx.lineCap = "round"
                    // bar width: the cover's circumference shared out, less a gap
                    ctx.lineWidth = Math.max(2, 2 * Math.PI * (cover.width / 2) / n - 3)
                    for (var i = 0; i < n; i++) {
                        var a = i / n * 2 * Math.PI - Math.PI / 2
                        var edge = cover.width / 2 * (1 - 0.07 * (1 - Math.cos(9 * (a + Math.PI / 2))) / 2) + 12
                        var len = Math.max(0.01, b[i]) * reach
                        ctx.beginPath()
                        ctx.moveTo(cx + edge * Math.cos(a), cy + edge * Math.sin(a))
                        ctx.lineTo(cx + (edge + len) * Math.cos(a), cy + (edge + len) * Math.sin(a))
                        ctx.stroke()
                    }
                }
            }

            Item {
                id: cover
                anchors.centerIn: parent
                width: 200; height: 200
                DashShape {
                    id: coverShape
                    anchors.fill: parent
                    kind: "cookie"; sides: 9; spin: -90
                    color: mt.dash.surfaceContainerHigh
                }
                DashShape {
                    id: coverMask
                    anchors.fill: parent
                    kind: "cookie"; sides: 9; spin: -90
                    visible: false
                    layer.enabled: true
                }
                IconText {
                    anchors.centerIn: parent
                    visible: coverImg.status !== Image.Ready
                    text: "art_track"
                    color: mt.dash.onSurfaceVariant
                    font.pointSize: 44
                }
                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: mt.player ? (mt.player.trackArtUrl || "") : ""
                    sourceSize.width: 400
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: coverImg
                    visible: coverImg.status === Image.Ready
                    maskEnabled: true
                    maskSource: coverMask
                }
            }
        }

        // ── details ──
        Column {
            id: details
            width: parent.width - coverSection.width - lyricsSection.width - 2 * parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            DText {
                width: parent.width
                text: mt.player ? (mt.player.trackTitle || "Unknown title") : ""
                color: mt.dash.onSurface
                font.pointSize: 22; font.weight: Font.Medium
            }
            DText {
                width: parent.width
                text: mt.player ? (mt.player.trackArtist || "Unknown artist") : ""
                color: mt.dash.onSurfaceVariant
                font.pointSize: 16; font.weight: Font.Medium
            }
            DText {
                width: parent.width
                text: mt.player ? (mt.player.trackAlbum || "Unknown album") : ""
                color: mt.dash.secondary
                font.pointSize: 16; font.weight: Font.Medium
            }

            // position · wavy seek bar · length
            Row {
                width: parent.width
                topPadding: 28
                spacing: 10
                readonly property real labelW: 46
                DText {
                    width: parent.labelW
                    anchors.verticalCenter: seek.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: mt.dash.clock(seek.dragging ? seek.dragFrac * (mt.player ? mt.player.length : 0) : mt.dash.pos)
                    color: mt.dash.onSurfaceVariant
                    font.pointSize: 11; font.weight: Font.Medium
                }
                WavySeek {
                    id: seek
                    width: parent.width - 2 * parent.labelW - 2 * parent.spacing
                    height: 28
                }
                DText {
                    width: parent.labelW
                    anchors.verticalCenter: seek.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: mt.player && mt.player.length > 0 ? mt.dash.clock(mt.player.length) : "--:--"
                    color: mt.dash.onSurfaceVariant
                    font.pointSize: 11; font.weight: Font.Medium
                }
            }

            Row {
                width: parent.width
                topPadding: 16
                spacing: 4
                readonly property real small: 44
                DButton {
                    dash: mt.dash; icon: "shuffle"; width: 40; height: 44
                    checked: !!mt.player && mt.player.shuffle
                    active: !!mt.player && mt.player.shuffleSupported
                    onClicked: mt.player.shuffle = !mt.player.shuffle
                }
                DButton {
                    dash: mt.dash; icon: "skip_previous"; height: 44; width: 52; iconSize: 22
                    active: !!mt.player && mt.player.canGoPrevious
                    onClicked: mt.player.previous()
                }
                DButton {
                    dash: mt.dash; height: 44; iconSize: 22
                    width: parent.width - 40 - 52 - 52 - 40 - 4 * parent.spacing
                    icon: mt.playing ? "pause" : "play_arrow"
                    checked: mt.playing
                    active: !!mt.player && mt.player.canTogglePlaying
                    onClicked: mt.player.togglePlaying()
                }
                DButton {
                    dash: mt.dash; icon: "skip_next"; height: 44; width: 52; iconSize: 22
                    active: !!mt.player && mt.player.canGoNext
                    onClicked: mt.player.next()
                }
                DButton {
                    dash: mt.dash; width: 40; height: 44
                    icon: mt.player && mt.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    checked: !!mt.player && mt.player.loopState !== MprisLoopState.None
                    active: !!mt.player && mt.player.loopSupported
                    onClicked: mt.player.loopState = mt.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                                   : mt.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                                   : MprisLoopState.None
                }
            }
        }

        // ── lyrics ──
        Item {
            id: lyricsSection
            width: 300; height: parent.height
            clip: true
            SyncedLyrics {
                id: lyrics
                anchors.centerIn: parent
                width: parent.width
                root: mt.root
                family: "Google Sans Flex"
                currentColor: mt.dash.primary
                otherColor: mt.dash.onSurfaceVariant
                currentSize: 18
                otherSize: 15
                lineH: 30
                visibleLines: Math.max(3, Math.floor(parent.height / lineH) | 1)
                active: mt.visible && !!mt.player
                title: mt.player ? (mt.player.trackTitle || "") : ""
                artist: mt.player ? (mt.player.trackArtist || "") : ""
                album: mt.player ? (mt.player.trackAlbum || "") : ""
                length: mt.player ? (mt.player.length || 0) : 0
                position: mt.dash.pos
            }
            Column {
                anchors.centerIn: parent
                visible: !lyrics.visible
                spacing: 6
                IconText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "lyrics"
                    color: mt.dash.outline
                    font.pointSize: 30
                }
                DText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No synced lyrics"
                    color: mt.dash.outline
                }
            }
        }
    }

    // played part as a sine wave (still while paused), the rest a flat track
    component WavySeek: Item {
        id: ws
        property bool dragging: false
        property real dragFrac: 0
        readonly property bool canSeek: !!mt.player && mt.player.canSeek && mt.player.length > 0
        readonly property real frac: dragging ? dragFrac
            : mt.player && mt.player.length > 0 ? Math.min(1, mt.dash.pos / mt.player.length) : 0
        readonly property real hx: frac * width
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: mt.dash.primary
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: {
                        var pts = [], w = Math.max(0, ws.hx - 8), cy = ws.height / 2
                        for (var x = 0; x <= w; x += 2)
                            pts.push(Qt.point(x, cy + 3 * Math.sin(x / 40 * 2 * Math.PI + mt.phase * 2)))
                        if (pts.length < 2) pts = [Qt.point(0, cy), Qt.point(0.01, cy)]
                        return pts
                    }
                }
            }
            ShapePath {
                strokeColor: mt.dash.secondaryContainer
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: Math.min(ws.width, ws.hx + 8); startY: ws.height / 2
                PathLine { x: ws.width; y: ws.height / 2 }
            }
        }
        Rectangle {
            x: ws.hx - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 4; height: 22; radius: 2
            color: mt.dash.primary
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            enabled: ws.canSeek
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            function at(mx) { return Math.max(0, Math.min(1, (mx - 6) / ws.width)) }
            onPressed: function (m) { ws.dragFrac = at(m.x); ws.dragging = true }
            onPositionChanged: function (m) { if (pressed) ws.dragFrac = at(m.x) }
            onReleased: {
                var t = ws.dragFrac * mt.player.length
                mt.player.position = t
                mt.dash.pos = t
                ws.dragging = false
            }
            onCanceled: ws.dragging = false
        }
    }
}
