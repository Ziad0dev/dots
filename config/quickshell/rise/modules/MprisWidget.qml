import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: rootMod
    required property var root
    property string gid: "G9"

    // shared player selection (ghost-filtering) — see MprisSelect.qml
    MprisSelect { id: sel }
    readonly property var  player:  sel.player
    readonly property bool active:  sel.active
    readonly property bool playing: sel.playing
    readonly property bool fullMode: root.compactMpris

    readonly property string trackLabel: {
        if (!player) return ""
        var t = player.trackTitle  || ""
        var a = player.trackArtist || ""
        return a ? t + "  ·  " + a : t
    }

    // ── FULL / muse: compact real-audio waveform ───────────────────
    readonly property int museBands: 24
    property var museLevels: []

    function resetMuseLevels() {
        var rest = []
        for (var i = 0; i < museBands; i++) rest.push(0.04)
        museLevels = rest
    }

    Component.onCompleted: resetMuseLevels()

    Process {
        id: museCava
        running: rootMod.visible && rootMod.active && rootMod.fullMode && rootMod.playing
        command: ["bash", "-c",
            "command -v cava >/dev/null 2>&1 || exit 0; " +
            "exec cava -p <(printf '%s\\n' " +
            "'[general]' 'bars = 24' 'framerate = 30' 'autosens = 1' 'sleep_timer = 0' " +
            "'[input]' 'method = pipewire' 'source = auto' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'[smoothing]' 'monstercat = 0' 'waves = 0' 'noise_reduction = 20')"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!rootMod.playing || !rootMod.fullMode) return
                var parts = line.split(";")
                var out = []
                for (var i = 0; i < rootMod.museBands; i++) {
                    var value = parseInt(parts[i])
                    out.push(isNaN(value) ? 0 : Math.min(1, value / 100))
                }
                rootMod.museLevels = out
            }
        }
    }

    // ── equalizer bar heights (0.0 – 1.0) ──
    property real barH1: 0.08
    property real barH2: 0.08
    property real barH3: 0.08

    Timer {
        running: rootMod.visible && rootMod.playing && !rootMod.fullMode
        interval: 50
        repeat: true
        onTriggered: {
            rootMod.barH1 = 0.10 + Math.random() * 0.80
            rootMod.barH2 = 0.10 + Math.random() * 0.80
            rootMod.barH3 = 0.10 + Math.random() * 0.80
        }
    }

    // drop bars to rest when paused
    ParallelAnimation {
        id: dropAnim
        NumberAnimation { target: rootMod; property: "barH1"; to: 0.08; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: rootMod; property: "barH2"; to: 0.08; duration: 430; easing.type: Easing.OutCubic }
        NumberAnimation { target: rootMod; property: "barH3"; to: 0.08; duration: 480; easing.type: Easing.OutCubic }
    }
    onPlayingChanged: {
        if (!playing) {
            dropAnim.restart()
            resetMuseLevels()
        }
    }
    onFullModeChanged: {
        resetMuseLevels()
        if (!fullMode) marqueeClip.resetMarquee()
    }

    visible: implicitWidth > 0.5
    implicitWidth: root.modMpris
        ? (active
            ? ((fullMode ? fullRow.implicitWidth : defaultRow.implicitWidth) + 18)
            : (idleNote.implicitWidth + 16))
        : 0
    implicitHeight: 28
    opacity: root.modMpris ? 1 : 0

    Behavior on opacity { Anim { kind: "effects"; ms: 140 } }

    Behavior on implicitWidth {
        Anim { kind: "size"; ms: 250 }
    }

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: rootMod.active
            ? (Math.round(rootMod.fullMode ? fullRow.implicitWidth : defaultRow.implicitWidth) + 18)
            : (Math.round(idleNote.implicitWidth) + 16)
        height: root.pillH
        radius: root.pillRadius
        color: root.widgetFillColor(rootMod.gid)
        border.color: root.widgetBorderColor(rootMod.gid)
        border.width: root.widgetBorderWidth(rootMod.gid)
        PillShadow { theme: root }
    }

    // ── idle: a single music-note, clickable to open the no-song panel ──
    IconText {
        id: idleNote
        anchors.centerIn: parent
        visible: !rootMod.active
        text: ""   // music_note
        font.pixelSize: 15
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.popout.click("mprisVisible")
        }
    }

    Row {
        id: defaultRow
        visible: rootMod.active && !rootMod.fullMode
        anchors.centerIn: parent
        spacing: 4

        // ── prev ──
        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            font.pixelSize: 13
            color: (rootMod.player && rootMod.player.canGoPrevious)
                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7)
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)
            Behavior on color { CAnim { ms: 150 } }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (rootMod.player) rootMod.player.previous()
            }
        }

        // ── play / pause ──
        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.playing ? "" : ""
            font.pixelSize: 13
            color: root.seal
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (rootMod.player) rootMod.player.togglePlaying()
            }
        }

        // ── next ──
        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            font.pixelSize: 13
            color: (rootMod.player && rootMod.player.canGoNext)
                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7)
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)
            Behavior on color { CAnim { ms: 150 } }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (rootMod.player) rootMod.player.next()
            }
        }

        // hidden alpha-mask source for the marquee fade — defined BEFORE the masked
        // item so the layer.effect can resolve the id; visible:false → no Row layout.
        Item {
            id: marqueeFadeMask
            width: 88; height: 28
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: "white" }
                    GradientStop { position: 0.92; color: "white" }
                    GradientStop { position: 1.0;  color: "transparent" }
                }
            }
        }

        // ── marquee title ──
        Item {
            id: marqueeClip
            implicitWidth: 88
            width: 88
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            // alpha-mask fade of the right edge: the scrolling title dissolves into
            // the real pixels behind it (no fixed colour → no seam on the translucent
            // pill). layer.enabled also clips to bounds like the old clip:true.
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: marqueeFadeMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.5
            }

            Text {
                id: marqueeText
                anchors.verticalCenter: parent.verticalCenter
                text: rootMod.trackLabel
                color: rootMod.playing
                    ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.85)
                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
                font.family: root.mono
                font.pixelSize: 12
                x: 0
                Behavior on color { CAnim { ms: 200 } }
                onTextChanged: marqueeClip.resetMarquee()
            }

            function resetMarquee() {
                marqueeAnim.stop()
                marqueeAnim.phase = 0
                marqueeText.x = 0
                if (rootMod.visible && rootMod.playing && marqueeText.implicitWidth > marqueeClip.width)
                    marqueeAnim.start()
            }

            Connections {
                target: rootMod
                function onPlayingChanged() { marqueeClip.resetMarquee() }
                function onVisibleChanged() { marqueeClip.resetMarquee() }   // stop/restart the scroll when the widget is hidden (toggle off)
            }

            // Whole-pixel steps on a timer (50 px/s, 2 s hold, 0.9 s hold at the end).
            // A NumberAnimation redraws the bar every display frame, and each redraw
            // makes Hyprland re-composite the screen: 240 times a second on DP-1.
            Timer {
                id: marqueeAnim
                property int phase: 0   // 0 = hold at start, 1 = scrolling, 2 = hold at end
                interval: phase === 1 ? 20 : phase === 0 ? 2000 : 900
                repeat: true
                onTriggered: {
                    if (phase === 0) { phase = 1; return }
                    if (phase === 2) { marqueeText.x = 0; phase = 0; return }
                    var end = -(marqueeText.implicitWidth - marqueeClip.width + 4)
                    marqueeText.x = Math.max(end, marqueeText.x - 1)
                    if (marqueeText.x <= end) phase = 2
                }
            }
        }

        // ── equalizer: three rounded bars ──
        // Plain Rectangles, not a Canvas: a Canvas rasterises on the CPU on
        // every repaint (20/s while playing, and per frame while they drop).
        Item {
            id: eqBars
            implicitWidth: 16
            width: 16
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            readonly property var levels: [rootMod.barH1, rootMod.barH2, rootMod.barH3]

            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: 3
                    radius: 1.5
                    height: Math.max(3, eqBars.levels[index] * (eqBars.height - 1))
                    x: (eqBars.width - 13) / 2 + index * 5
                    y: eqBars.height - height
                    color: root.seal
                }
            }
        }
    }

    // ── FULL: muse-style vinyl · centered waveform · transport state ──
    Item {
        id: fullRow
        visible: rootMod.active && rootMod.fullMode
        anchors.centerIn: parent
        implicitWidth: fullMuseCore.width
        implicitHeight: 28

        Item {
            id: fullMuseCore
            anchors.centerIn: parent
            width: 144
            height: 28

            Row {
                id: museRow
                anchors.centerIn: parent
                spacing: 7

                Item {
                    id: vinylMark
                    width: 18
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    transformOrigin: Item.Center

                    Canvas {
                        id: vinylCanvas
                        anchors.fill: parent
                        antialiasing: true
                        property color tint: root.seal
                        onTintChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = tint
                            ctx.fillStyle = tint
                            ctx.lineWidth = 1.4

                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, 7.2, 0, Math.PI * 2)
                            ctx.stroke()
                            ctx.globalAlpha = 0.55
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, 4.6, -0.35, 2.35)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, 4.6, 2.8, 5.5)
                            ctx.stroke()
                            ctx.globalAlpha = 1
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, 1.45, 0, Math.PI * 2)
                            ctx.fill()
                        }
                        Component.onCompleted: requestPaint()
                    }

                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 3200
                        loops: Animation.Infinite
                        running: rootMod.visible && rootMod.fullMode && rootMod.playing
                    }
                }

                Item {
                    id: museWaveform
                    width: 96
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    // 24 Rectangles, not a Canvas repainted on the CPU per cava frame
                    Repeater {
                        model: rootMod.museBands
                        Rectangle {
                            required property int index
                            readonly property real level: rootMod.museLevels[index] !== undefined ? rootMod.museLevels[index] : 0.04
                            readonly property real gap: (museWaveform.width - rootMod.museBands * 2) / (rootMod.museBands - 1)
                            width: 2
                            radius: 1
                            height: 2 * (1 + level * (museWaveform.height / 2 - 2))
                            x: index * (2 + gap)
                            y: (museWaveform.height - height) / 2
                            color: root.seal
                        }
                    }
                }

                Item {
                    id: transportMark
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 18

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        visible: rootMod.playing
                        Repeater {
                            model: 2
                            Rectangle {
                                width: 3
                                height: 10
                                radius: 1
                                color: root.seal
                            }
                        }
                    }

                    Canvas {
                        id: playCanvas
                        anchors.centerIn: parent
                        width: 11
                        height: 12
                        visible: !rootMod.playing
                        antialiasing: true
                        property color tint: root.seal
                        onTintChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = tint
                            ctx.beginPath()
                            ctx.moveTo(2, 1)
                            ctx.lineTo(width - 1, height / 2)
                            ctx.lineTo(2, height - 1)
                            ctx.closePath()
                            ctx.fill()
                        }
                        Component.onCompleted: requestPaint()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 2
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: if (rootMod.player) rootMod.player.togglePlaying()
                onWheel: function(wheel) {
                    if (!rootMod.player || wheel.angleDelta.y === 0) return
                    if (wheel.angleDelta.y > 0) {
                        if (rootMod.player.canGoNext) rootMod.player.next()
                    } else if (rootMod.player.canGoPrevious) {
                        rootMod.player.previous()
                    }
                    wheel.accepted = true
                }
            }
        }
    }

    readonly property string tooltipText: player
        ? (player.trackArtist ? player.trackArtist + " — " + player.trackTitle : player.trackTitle)
        : ""

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText; popout: "mprisVisible" }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.RightButton
        onEntered: { if (rootMod.tooltipText) tip.show() }
        onExited:  { tip.hide() }
        onClicked: { tip.hide(); root.popout.click("mprisVisible") }
    }
}
