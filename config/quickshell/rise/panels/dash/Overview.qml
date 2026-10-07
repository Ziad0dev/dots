import QtQuick
import Quickshell
import "../../modules"
import "Occult.js" as Occult

// Almanac tab, the dashboard's first page, laid out as a grimoire spread:
//   [ omen ][ seal · moon · planetary hour      ][ hymn ]
//   [ hour ][ calendar ][ engine ]               [      ]
//   [ rites · a line from the book ]             [      ]
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

    // almanac state, recomputed with the dashboard's clock
    readonly property var moon: Occult.moon(dash.now)
    readonly property var hour: Occult.planetaryHour(dash.now,
        dash.wx ? dash.wx.sunrise : "", dash.wx ? dash.wx.sunset : "")

    // ── omen: the weather ──
    Frame {
        id: weatherCard
        dash: ov.dash
        width: 275; height: ov.topH
        Row {
            anchors.centerIn: parent
            spacing: 18
            IconText {
                anchors.verticalCenter: parent.verticalCenter
                text: ov.dash.wx ? ov.dash.wxIcon(ov.dash.wx.code) : "cloud_off"
                color: ov.dash.bone
                font.pointSize: 44
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                GText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ov.dash.wx ? ov.dash.deg(ov.dash.wx.tempC, ov.dash.wx.tempF) : "--°"
                    color: ov.dash.bloodText
                    font.pointSize: 30
                }
                DText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, 130)
                    horizontalAlignment: Text.AlignHCenter
                    text: ov.dash.wx ? ov.dash.wx.desc : "the sky is silent"
                    color: ov.dash.bone
                    font.italic: true; font.pointSize: 13
                    wrapMode: Text.WordWrap; maximumLineCount: 2
                }
                DText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: ov.dash.wx !== null
                    text: ov.dash.wx ? "↓ " + ov.dash.deg(ov.dash.wx.minC, ov.dash.wx.minF) + "   ↑ " + ov.dash.deg(ov.dash.wx.maxC, ov.dash.wx.maxF) : ""
                    color: ov.dash.ash
                    font.pointSize: 10
                }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ov.dash.tab = "weather" }
    }

    // ── seal, moon and the planetary hour ──
    Frame {
        id: userCard
        dash: ov.dash
        x: 275 + ov.gap
        width: ov.leftW - x; height: ov.topH

        Sigil {
            id: seal
            dash: ov.dash
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: ov.topH - 18; height: width
            word: ov.dash.user
            legend: "✦ " + ov.dash.user.toUpperCase() + " ✦ " + (ov.dash.host || "").toUpperCase()
                + " ✦ " + Occult.roman(ov.dash.now.getFullYear()) + " "
        }

        Column {
            anchors.left: seal.right; anchors.leftMargin: 18
            anchors.right: moonDisc.left; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            DText {
                width: parent.width
                text: Occult.vigil(ov.dash.now) + "  ·  day of " + ov.hour.day.toLowerCase()
                color: ov.dash.ash
                font.italic: true; font.pointSize: 12
            }
            GText {
                width: parent.width
                text: ov.moon.name
                color: ov.dash.bone
                font.pointSize: 25
            }
            Row {
                spacing: 6
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ov.hour.hourGlyph
                    color: ov.dash.blood
                    font.pointSize: 13
                }
                DText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "hour of " + ov.hour.hour
                        + (ov.dash.uptimeS > 0 ? "   ·   vigil " + ov.dash.uptimeText : "")
                        + (ov.dash.host ? "   ·   " + ov.dash.host : "")
                    color: ov.dash.bone
                    font.pointSize: 12
                }
            }
        }

        Moon {
            id: moonDisc
            dash: ov.dash
            anchors.right: parent.right; anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -8
            width: 54; height: 54
            frac: ov.moon.frac
        }
        DText {
            anchors.horizontalCenter: moonDisc.horizontalCenter
            anchors.top: moonDisc.bottom; anchors.topMargin: 4
            text: Math.round(ov.moon.illum * 100) + "% lit"
            color: ov.dash.ash
            font.pointSize: 10; font.italic: true
        }
    }

    // ── the hour, in blackletter ──
    Frame {
        id: clockCard
        dash: ov.dash
        y: ov.topH + ov.gap
        width: 110; height: ov.midH
        Column {
            anchors.centerIn: parent
            spacing: -4
            ClockPart { text: Qt.formatTime(ov.dash.now, ov.root.clock12h ? "hh" : "HH") }
            ClockSign {}
            ClockPart { text: Qt.formatTime(ov.dash.now, "mm") }
            ClockSign {}
            ClockPart {
                text: Qt.formatTime(ov.dash.now, "ss")
                color: ov.dash.ash
                font.pointSize: 24
            }
            GText {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 10
                visible: ov.root.clock12h
                text: Qt.formatTime(ov.dash.now, "AP")
                color: ov.dash.bloodText
                font.pointSize: 16
            }
        }
    }
    component ClockPart: GText {
        anchors.horizontalCenter: parent.horizontalCenter
        color: ov.dash.bone
        font.pointSize: 32
    }
    component ClockSign: Glyph {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "✦"
        color: ov.dash.blood
        font.family: "DejaVu Sans"
        font.pointSize: 9
    }

    // ── calendar ──
    Frame {
        id: calendarCard
        dash: ov.dash
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

    // ── engine: four gauges under planetary signs ──
    Frame {
        id: resourcesCard
        dash: ov.dash
        x: ov.leftW - width
        y: ov.topH + ov.gap
        width: 78; height: ov.midH
        Column {
            anchors.centerIn: parent
            spacing: 10
            Repeater {
                model: [
                    { sign: "☿", value: ov.root.systemCpuPercent, text: ov.root.systemCpuPercent + "%" },
                    { sign: "☽", value: ov.root.systemMemPercent, text: ov.root.systemMemUsedGiB.toFixed(1) + "G" },
                    ov.root.gpuAvailable
                        ? { sign: "♂", value: ov.root.gpuPercent, text: ov.root.gpuPercent + "%" }
                        : { sign: "♄", value: ov.root.storagePercent, text: ov.root.storagePercent + "%" },
                    { sign: "🜂", value: Math.min(100, ov.root.cpuTemperatureC), text: ov.root.cpuTemperatureC + "°", hot: true }
                ]
                delegate: Ring {
                    id: res
                    required property var modelData
                    width: Math.min(46, (ov.midH - 32 - 30) / 4); height: width
                    value: modelData.value / 100
                    color: modelData.hot && modelData.value >= 80 ? ov.dash.bloodText : ov.dash.blood
                    trackColor: ov.dash.secondaryContainer
                    thickness: 2.5
                    HoverHandler { id: resHover }
                    Glyph {
                        anchors.centerIn: parent
                        visible: !resHover.hovered
                        text: res.modelData.sign
                        color: ov.dash.bone
                        font.family: res.modelData.hot ? "Noto Sans Symbols" : "Libertinus Serif Display"
                        font.pointSize: 14
                    }
                    DText {
                        anchors.centerIn: parent
                        visible: resHover.hovered
                        text: res.modelData.text
                        color: ov.dash.bloodText
                        font.pointSize: 10; font.weight: Font.Bold
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: ov.dash.tab = "performance" }
    }

    // ── rites + a line from the book ──
    Frame {
        id: actionsCard
        dash: ov.dash
        bosses: false
        y: ov.topH + ov.gap + ov.midH + ov.gap
        width: ov.leftW; height: ov.bottomH
        Row {
            id: actions
            anchors.left: parent.left; anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: [
                    { icon: "lock", act: "lock" },
                    { icon: "screenshot_region", act: "shot" },
                    { icon: "palette", act: "themes" },
                    { icon: "tune", act: "settings" },
                    { icon: "power_settings_new", act: "power" }
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
        GText {
            id: quoteAuthor
            anchors.right: parent.right; anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 160)
            visible: !!ov.dash.quote.author
            text: "— " + ov.dash.quote.author
            color: ov.dash.bloodText
            font.pointSize: 12
        }
        DText {
            anchors.left: actions.right; anchors.leftMargin: 16
            anchors.right: quoteAuthor.visible ? quoteAuthor.left : parent.right
            anchors.rightMargin: quoteAuthor.visible ? 10 : 20
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap; maximumLineCount: 2
            text: ov.dash.quote.text ? "“" + ov.dash.quote.text + "”" : ""
            color: ov.dash.bone
            font.italic: true; font.pointSize: 12
        }
    }

    // ── hymn: the media column ──
    Frame {
        id: mediaCard
        dash: ov.dash
        x: ov.leftW + ov.gap
        width: 200; height: ov.height
        MediaCard { anchors.fill: parent; dash: ov.dash }
    }
}
