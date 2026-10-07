import QtQuick
import QtQuick.Effects
import Quickshell
import "../../modules"

// Dashboard tab (Caelestia's grid):
//   [ weather ][ user          ][ media ]
//   [ clock ][ calendar ][ res ][       ]
//   [ shortcuts · quote        ][       ]
Item {
    id: ov
    required property var dash
    readonly property var root: dash.root
    property bool shown: true
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    readonly property int gap: 12
    readonly property int minLeftW: 275 + gap + 340
    readonly property real leftW: Math.max(minLeftW, width - gap - 200)
    readonly property int topH: 120
    readonly property int bottomH: 56
    // the middle row takes any extra height (implicit size uses the calendar's own)
    readonly property real calH: calendarCard.implicitHeight
    readonly property real midH: Math.max(calH, height - topH - bottomH - 2 * gap)
    implicitWidth: minLeftW + gap + 200
    implicitHeight: topH + gap + calH + gap + bottomH

    component Card: Rectangle {
        color: ov.dash.surfaceContainer
        radius: 28
    }

    // ── weather ──
    Card {
        id: weatherCard
        width: 275; height: ov.topH
        radius: 42
        Row {
            anchors.centerIn: parent
            spacing: 20
            IconText {
                anchors.verticalCenter: parent.verticalCenter
                text: ov.dash.wx ? ov.dash.wxIcon(ov.dash.wx.code) : "cloud_off"
                color: ov.dash.secondary
                font.pointSize: 52
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                DText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ov.dash.wx ? ov.dash.deg(ov.dash.wx.tempC, ov.dash.wx.tempF) : "--°"
                    color: ov.dash.primary
                    font.pointSize: 28; font.weight: Font.DemiBold
                    font.variableAxes: { "wdth": 110 }
                }
                DText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, 130)
                    horizontalAlignment: Text.AlignHCenter
                    text: ov.dash.wx ? ov.dash.wx.desc : "No weather"
                    color: ov.dash.onSurface
                    wrapMode: Text.WordWrap; maximumLineCount: 2
                }
                DText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: ov.dash.wx !== null
                    text: ov.dash.wx ? "↓ " + ov.dash.deg(ov.dash.wx.minC, ov.dash.wx.minF) + "   ↑ " + ov.dash.deg(ov.dash.wx.maxC, ov.dash.wx.maxF) : ""
                    color: ov.dash.onSurfaceVariant
                    font.pointSize: 9
                }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ov.dash.tab = "weather" }
    }

    // ── user: OS gem, face, uptime clam and a greeting bubble ──
    Card {
        id: userCard
        x: 275 + ov.gap
        width: ov.leftW - x; height: ov.topH
        Item {
            id: user
            anchors.fill: parent
            anchors.margins: 16

            DashShape {
                id: logoGem
                x: 4
                width: 46; height: 46
                kind: "gem"
                color: ov.dash.primaryContainer
                Text {
                    anchors.centerIn: parent
                    text: ""                       // nf-linux-nixos
                    color: ov.dash.onPrimaryContainer
                    font.family: ov.root.mono
                    font.pixelSize: 24
                }
            }

            Item {
                id: face
                anchors.top: parent.top; anchors.bottom: parent.bottom
                x: logoGem.x + logoGem.width - 24
                width: height
                DashShape {
                    id: faceShape
                    anchors.fill: parent
                    kind: "pill"
                    color: ov.dash.surfaceContainerHighest
                }
                DashShape {
                    id: faceMask
                    anchors.fill: parent
                    kind: "pill"
                    visible: false
                    layer.enabled: true
                }
                Image {
                    id: faceImg
                    anchors.fill: parent
                    source: ov.dash.hasFace ? "file://" + Quickshell.env("HOME") + "/.face" : ""
                    sourceSize.width: 160
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: faceImg
                    visible: faceImg.status === Image.Ready
                    maskEnabled: true
                    maskSource: faceMask
                }
                DText {
                    anchors.centerIn: parent
                    visible: faceImg.status !== Image.Ready
                    text: ov.dash.user.charAt(0).toUpperCase()
                    color: ov.dash.onSurfaceVariant
                    font.pointSize: 24; font.weight: Font.Medium
                }
            }

            DashShape {
                id: clam
                anchors.bottom: parent.bottom; anchors.bottomMargin: -8
                x: face.x + face.width - 32
                width: 46; height: 46
                kind: "clam"
                color: ov.dash.tertiaryContainer
                IconText {
                    anchors.centerIn: parent
                    text: "schedule"
                    color: ov.dash.onTertiaryContainer
                    font.pointSize: 15
                }
            }
            DText {
                anchors.left: clam.right; anchors.leftMargin: 8
                anchors.verticalCenter: clam.verticalCenter
                width: user.width - x - 4
                text: (ov.dash.uptimeS > 0 ? "up " + ov.dash.uptimeText : "") + (ov.dash.host ? "  ·  " + ov.dash.host : "")
                color: ov.dash.onSurface
            }

            // the greeting bubble, with its two little bubbles trailing to the face
            Rectangle {
                id: bubbleSmall
                x: face.x + face.width + 6
                y: bubbleBig.y + bubbleBig.height - 4
                width: 10; height: 10; radius: 5
                color: ov.dash.secondaryContainer
            }
            Rectangle {
                id: bubbleBig
                x: bubbleSmall.x + bubbleSmall.width + 4
                y: greet.y + greet.height - height / 2
                width: 15; height: 15; radius: 7.5
                color: ov.dash.secondaryContainer
            }
            Rectangle {
                id: greet
                x: bubbleBig.x - 12
                y: 4
                width: Math.min(greetRow.implicitWidth + 24, user.width - x)
                height: greetRow.implicitHeight + 14
                radius: 20
                color: ov.dash.secondaryContainer
                Row {
                    id: greetRow
                    anchors.centerIn: parent
                    spacing: 4
                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "waving_hand"
                        color: ov.dash.onSecondaryContainer
                        font.pointSize: 11
                    }
                    DText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, user.width - greet.x - 48)
                        text: ov.dash.greeting
                        color: ov.dash.onSecondaryContainer
                        font.pointSize: 11; font.italic: true
                    }
                }
            }
        }
    }

    // ── date & time, stacked ──
    Card {
        id: clockCard
        y: ov.topH + ov.gap
        width: 110; height: ov.midH
        radius: 16
        Column {
            anchors.centerIn: parent
            spacing: -12
            ClockPart { text: Qt.formatTime(ov.dash.now, ov.root.clock12h ? "hh" : "HH") }
            ClockDots {}
            ClockPart { text: Qt.formatTime(ov.dash.now, "mm") }
            ClockDots {}
            ClockPart { text: Qt.formatTime(ov.dash.now, "ss") }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 14
                visible: ov.root.clock12h
                text: Qt.formatTime(ov.dash.now, "AP")
                color: ov.dash.primary
                font.family: "Rubik"; font.pointSize: 18; font.weight: Font.DemiBold
            }
        }
    }
    component ClockPart: Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: ov.dash.secondary
        font.family: "Rubik"; font.pointSize: 28; font.weight: Font.DemiBold
    }
    component ClockDots: Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "•••"
        color: ov.dash.primary
        font.family: "Rubik"; font.pointSize: 25
    }

    // ── calendar ──
    Card {
        id: calendarCard
        x: 110 + ov.gap
        y: ov.topH + ov.gap
        width: ov.leftW - x - ov.gap - resourcesCard.width
        height: ov.midH
        implicitHeight: cal.implicitHeight + 32
        Calendar {
            id: cal
            anchors.fill: parent
            anchors.margins: 16
            dash: ov.dash
        }
    }

    // ── resources ──
    Card {
        id: resourcesCard
        x: ov.leftW - width
        y: ov.topH + ov.gap
        width: 78; height: ov.midH
        radius: 16
        Column {
            anchors.centerIn: parent
            spacing: 10
            Repeater {
                model: [
                    { icon: "memory", value: ov.root.systemCpuPercent, text: ov.root.systemCpuPercent + "%", color: ov.dash.primary },
                    { icon: "memory_alt", value: ov.root.systemMemPercent, text: ov.root.systemMemUsedGiB.toFixed(1) + "G", color: ov.dash.tertiary },
                    ov.root.gpuAvailable
                        ? { icon: "developer_board", value: ov.root.gpuPercent, text: ov.root.gpuPercent + "%", color: ov.dash.secondary }
                        : { icon: "hard_drive", value: ov.root.storagePercent, text: ov.root.storagePercent + "%", color: ov.dash.secondary },
                    { icon: "thermometer", value: Math.min(100, ov.root.cpuTemperatureC), text: ov.root.cpuTemperatureC + "°", color: ov.dash.error }
                ]
                delegate: Ring {
                    id: res
                    required property var modelData
                    width: Math.min(46, (ov.midH - 32 - 30) / 4); height: width
                    value: modelData.value / 100
                    color: modelData.color
                    trackColor: ov.dash.secondaryContainer
                    thickness: 5
                    HoverHandler { id: resHover }
                    IconText {
                        anchors.centerIn: parent
                        visible: !resHover.hovered
                        text: res.modelData.icon
                        color: res.modelData.color
                        font.pointSize: 13
                    }
                    DText {
                        anchors.centerIn: parent
                        visible: resHover.hovered
                        text: res.modelData.text
                        color: res.modelData.color
                        font.pointSize: 8; font.weight: Font.DemiBold
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: ov.dash.tab = "performance" }
    }

    // ── shortcuts + quote ──
    Card {
        id: actionsCard
        y: ov.topH + ov.gap + ov.midH + ov.gap
        width: ov.leftW; height: ov.bottomH
        radius: height / 2
        Row {
            id: actions
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: [
                    { icon: "lock", tip: "Lock", act: "lock" },
                    { icon: "screenshot_region", tip: "Screenshot", act: "shot" },
                    { icon: "palette", tip: "Themes", act: "themes" },
                    { icon: "tune", tip: "Settings", act: "settings" },
                    { icon: "power_settings_new", tip: "Power", act: "power" }
                ]
                delegate: DButton {
                    required property var modelData
                    dash: ov.dash
                    icon: modelData.icon
                    filled: modelData.act === "power"
                    onClicked: ov.dash.action(modelData.act)
                }
            }
        }
        DText {
            anchors.left: actions.right; anchors.leftMargin: 16
            anchors.right: parent.right; anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap; maximumLineCount: 2
            text: ov.dash.quote.text ? "“" + ov.dash.quote.text + "”" + (ov.dash.quote.author ? "  — " + ov.dash.quote.author : "") : ""
            color: ov.dash.onSurfaceVariant
            font.pointSize: 10; font.italic: true
        }
    }

    // ── media ──
    Card {
        id: mediaCard
        x: ov.leftW + ov.gap
        width: 200; height: ov.height
        radius: 56
        MediaCard { anchors.fill: parent; dash: ov.dash }
    }
}
