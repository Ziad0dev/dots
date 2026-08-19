import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: bar
    required property var root

    readonly property int  btnRadius: 6
    readonly property int  slotHeight: 25
    readonly property int  clusterSpacing: 2
    readonly property int  inlineSpacing: 4
    readonly property int  sectionSpacing: 10
    readonly property int  groupPadding: 5
    readonly property int  barHeight: 33
    readonly property real barOpacity: 0.94
    readonly property color content: root.seal

    readonly property color islandColor: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, bar.barOpacity)

    property string timeText: ""
    property string dateText: ""

    SystemClock {
        id: clk
        precision: SystemClock.Seconds
        onDateChanged: {
            bar.timeText = Qt.formatDateTime(clk.date, "HH:mm")
            bar.dateText = Qt.formatDateTime(clk.date, "ddd d MMM")
        }
    }
    Component.onCompleted: {
        bar.timeText = Qt.formatDateTime(new Date(), "HH:mm")
        bar.dateText = Qt.formatDateTime(new Date(), "ddd d MMM")
    }

    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }
    readonly property var  sink: Pipewire.defaultAudioSink
    readonly property int  volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    readonly property var  batt: UPower.displayDevice
    readonly property bool hasBatt: batt && batt.isLaptopBattery

    property int cpuPct: 0
    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0]
    property int memPct: 0
    property int tempC: 0

    Process {
        id: sysProc
        property int lastIdle: 0
        property int lastTotal: 0
        command: ["bash", "-c",
            "read -r _ a b c d e f g _ < /proc/stat; " +
            "idle=$((d+e)); total=$((a+b+c+d+e+f+g)); " +
            "mt=$(awk '/MemTotal/{print $2}' /proc/meminfo); " +
            "ma=$(awk '/MemAvailable/{print $2}' /proc/meminfo); " +
            "t=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -rn | head -1); " +
            "echo \"$idle $total $mt $ma ${t:-0}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim().split(/\s+/)
                if (p.length < 5) return
                var idle = parseInt(p[0])
                var total = parseInt(p[1])
                if (sysProc.lastTotal > 0 && total > sysProc.lastTotal) {
                    var dt = total - sysProc.lastTotal
                    var di = idle - sysProc.lastIdle
                    bar.cpuPct = Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt)))
                    var h = bar.cpuHistory.slice(1)
                    h.push(bar.cpuPct / 100)
                    bar.cpuHistory = h
                }
                sysProc.lastIdle = idle
                sysProc.lastTotal = total
                var mt = parseInt(p[2])
                var ma = parseInt(p[3])
                if (mt > 0) bar.memPct = Math.round(100 * (mt - ma) / mt)
                var t = parseInt(p[4])
                if (t > 0) bar.tempC = Math.round(t / 1000)
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: sysProc.running = true
    }

    component Donut: Canvas {
        property real value: 0
        property color tint: bar.content
        implicitWidth: 13
        implicitHeight: 13
        onValueChanged: requestPaint()
        onTintChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2, r = width / 2 - 1.2
            ctx.lineWidth = 2.0
            ctx.strokeStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.22)
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
            ctx.strokeStyle = tint
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.001, value))
            ctx.stroke()
        }
    }

    component Spark: Canvas {
        property var samples: []
        property color tint: bar.content
        implicitWidth: 22
        implicitHeight: 13
        onSamplesChanged: requestPaint()
        onTintChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var n = samples.length
            if (n < 2) return
            var bw = width / n
            ctx.fillStyle = tint
            for (var i = 0; i < n; i++) {
                var h = Math.max(1, samples[i] * (height - 1))
                ctx.fillRect(i * bw, height - h, Math.max(1, bw - 1), h)
            }
        }
    }

    component Gauge: Rectangle {
        property real value: 0
        property color tint: bar.content
        implicitWidth: 20
        implicitHeight: 7
        radius: 3.5
        color: Qt.rgba(tint.r, tint.g, tint.b, 0.22)
        Rectangle {
            width: Math.max(parent.radius * 2, parent.width * Math.max(0, Math.min(1, parent.value)))
            height: parent.height
            radius: parent.radius
            color: parent.tint
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
    }

    component Group: Rectangle {
        default property alias data_: inner.data
        property alias spacing: inner.spacing
        implicitWidth: inner.implicitWidth > 0 ? Math.round(inner.implicitWidth) + 2 * bar.groupPadding : 0
        implicitHeight: bar.slotHeight
        radius: bar.btnRadius
        color: bar.islandColor
        border.width: 1
        border.color: bar.root.barBorder
        visible: implicitWidth > 0.5
        Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on border.color { ColorAnimation { duration: 220 } }
        Row {
            id: inner
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round((parent.width - width) / 2)
            spacing: bar.inlineSpacing
        }
    }

    component Btn: Item {
        id: btn
        property string glyph: ""
        property string label: ""
        property color fg: bar.content
        property bool active: false
        signal activated(int button)
        signal wheeled(int dy)

        implicitWidth: brow.implicitWidth + 8
        implicitHeight: bar.slotHeight
        scale: ma.containsMouse ? 1.08 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Row {
            id: brow
            anchors.centerIn: parent
            spacing: 4
            IconText {
                anchors.verticalCenter: parent.verticalCenter
                visible: btn.glyph !== ""
                text: btn.glyph
                font.pixelSize: 15
                font.weight: Font.Medium
                fill: 1
                color: btn.active ? bar.root.seal : btn.fg
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: btn.label !== ""
                text: btn.label
                font.family: bar.root.mono
                font.pixelSize: 11
                color: btn.active ? bar.root.seal : btn.fg
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function (m) { btn.activated(m.button) }
            onWheel: function (w) { btn.wheeled(w.angleDelta.y) }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "dots-bar"
            anchors { top: true; left: true; right: true }
            implicitHeight: bar.barHeight
            exclusiveZone: bar.barHeight

            // the connecting line, behind every island
            Waveform {
                z: 0
                anchors.fill: parent
                root: bar.root
                active: bar.root.waveformActive
                lines: bar.root.waveLines
                speed: bar.root.waveSpeed
                lineColor: bar.root.seal
            }

            Row {
                id: leftRow
                z: 1
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: bar.sectionSpacing

                Group {
                    anchors.verticalCenter: parent.verticalCenter
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "apps"
                        fg: root.seal
                        active: root.controlVisible
                        onActivated: function (b) {
                            root.activePopupScreen = win.modelData
                            if (b === Qt.RightButton) root.launcherVisible = !root.launcherVisible
                            else root.controlVisible = !root.controlVisible
                        }
                    }
                }

                Group {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    visible: root.showWorkspaces

                    Repeater {
                        model: root.showWorkspaces ? Hyprland.workspaces : null

                        Item {
                            id: ws
                            required property var modelData
                            readonly property bool isFocused: Hyprland.focusedWorkspace
                                                              && Hyprland.focusedWorkspace.id === modelData.id
                            readonly property bool isOccupied: modelData.toplevels
                                                               && modelData.toplevels.values.length > 0
                            readonly property color cc: bar.content

                            visible: modelData.id > 0
                            implicitWidth: isFocused ? 34 : 16
                            implicitHeight: bar.slotHeight
                            scale: wsMa.containsMouse ? 1.12 : 1.0
                            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            Rectangle {
                                anchors.centerIn: parent
                                width: ws.isFocused ? 34 : 16
                                height: 16
                                radius: 8
                                color: ws.isFocused ? Qt.rgba(ws.cc.r, ws.cc.g, ws.cc.b, 0.20)
                                     : ws.isOccupied ? Qt.rgba(ws.cc.r, ws.cc.g, ws.cc.b, 0.18)
                                                    : Qt.rgba(ws.cc.r, ws.cc.g, ws.cc.b, 0.06)
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: ws.isFocused ? 26 : 8
                                height: 8
                                radius: 4
                                color: ws.isFocused || ws.isOccupied ? ws.cc
                                                                     : Qt.rgba(ws.cc.r, ws.cc.g, ws.cc.b, 0.25)
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                id: wsMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("\"workspace " + ws.modelData.id + "\"")
                            }
                        }
                    }
                }

                Group {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: bar.clusterSpacing
                    visible: root.showTray
                    Repeater {
                        model: root.showTray ? SystemTray.items : null
                        Item {
                            required property SystemTrayItem modelData
                            implicitWidth: 22
                            implicitHeight: bar.slotHeight
                            scale: trayMa.containsMouse ? 1.15 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 16
                                source: modelData.icon
                            }
                            MouseArea {
                                id: trayMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function (m) {
                                    if (m.button === Qt.LeftButton) modelData.activate()
                                    else modelData.secondaryActivate()
                                }
                            }
                        }
                    }
                }

                Group {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showSystem
                    spacing: 10

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "MEM"
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 0.6
                            color: Qt.rgba(bar.content.r, bar.content.g, bar.content.b, 0.55)
                        }
                        Donut {
                            anchors.verticalCenter: parent.verticalCenter
                            value: bar.memPct / 100
                            tint: bar.memPct > 85 ? root.color01 : bar.content
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.memPct + "%"
                            font.family: root.mono
                            font.pixelSize: 11
                            color: bar.memPct > 85 ? root.color01 : bar.content
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CPU"
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 0.6
                            color: Qt.rgba(bar.content.r, bar.content.g, bar.content.b, 0.55)
                        }
                        Spark {
                            anchors.verticalCenter: parent.verticalCenter
                            samples: bar.cpuHistory
                            tint: bar.cpuPct > 85 ? root.color01 : bar.content
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.cpuPct + "%"
                            font.family: root.mono
                            font.pixelSize: 11
                            color: bar.cpuPct > 85 ? root.color01 : bar.content
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        visible: bar.tempC > 0
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "thermostat"
                            font.pixelSize: 14
                            fill: 1
                            color: bar.tempC > 80 ? root.color01 : bar.content
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.tempC + "\u00B0"
                            font.family: root.mono
                            font.pixelSize: 11
                            color: bar.tempC > 80 ? root.color01 : bar.content
                        }
                    }
                }
            }

            Group {
                z: 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: root.showClock

                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    label: bar.timeText
                    fg: bar.content
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 12
                    color: root.sep
                }
                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    label: bar.dateText
                    fg: root.sumiHi
                }
            }

            Row {
                id: rightRow
                z: 1
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: bar.sectionSpacing

                Group {
                    anchors.verticalCenter: parent.verticalCenter

                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "palette"
                        active: root.imagePickerVisible
                        fg: bar.content
                        onActivated: function (b) {
                            root.activePopupScreen = win.modelData
                            root.open(b === Qt.RightButton ? "wallpaper" : "theme")
                        }
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "graphic_eq"
                        active: root.waveformActive
                        fg: bar.content
                        onActivated: root.waveformActive = !root.waveformActive
                    }
                }

                Group {
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showVolume && bar.sink !== null
                        implicitWidth: volRow.implicitWidth + 10
                        implicitHeight: bar.slotHeight
                        readonly property color vc: bar.muted
                            ? Qt.rgba(bar.content.r, bar.content.g, bar.content.b, 0.35)
                            : bar.content

                        Row {
                            id: volRow
                            anchors.centerIn: parent
                            spacing: 5
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "VOL"
                                font.family: root.mono
                                font.pixelSize: 10
                                font.letterSpacing: 0.6
                                color: Qt.rgba(parent.parent.vc.r, parent.parent.vc.g, parent.parent.vc.b, 0.55)
                            }
                            Gauge {
                                anchors.verticalCenter: parent.verticalCenter
                                value: bar.volume / 100
                                tint: parent.parent.vc
                            }
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(bar.volume).padStart(2, "0") + "%"
                                font.family: root.mono
                                font.pixelSize: 11
                                color: parent.parent.vc
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (bar.sink && bar.sink.audio) bar.sink.audio.muted = !bar.sink.audio.muted
                            onWheel: function (w) {
                                if (!bar.sink || !bar.sink.audio) return
                                var v = bar.sink.audio.volume + (w.angleDelta.y > 0 ? 0.02 : -0.02)
                                bar.sink.audio.volume = Math.max(0, Math.min(1, v))
                            }
                        }
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bar.hasBatt
                        glyph: "battery_full"
                        label: bar.hasBatt ? Math.round(bar.batt.percentage * 100) + "%" : ""
                        fg: bar.hasBatt && bar.batt.percentage < 0.2 ? root.color01 : bar.content
                    }
                }
            }
        }
    }
}
