import QtQuick
import "../../modules"

// Weather tab: place and date, the current conditions, detail cards and the
// three-day forecast (wttr.in, fetched by the dashboard at most every 10 min).
Item {
    id: wt
    required property var dash
    readonly property var wx: dash.wx
    property bool shown: true
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    implicitWidth: 840
    implicitHeight: wx ? content.implicitHeight : 260

    Column {
        anchors.centerIn: parent
        visible: !wt.wx
        spacing: 8
        IconText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "cloud_off"
            color: wt.dash.onSurfaceVariant
            font.pointSize: 48
        }
        DText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: wt.dash.wxLoading ? "Loading weather…" : "Weather unavailable"
            color: wt.dash.onSurface
            font.pointSize: 18; font.weight: Font.Medium
        }
    }

    Column {
        id: content
        width: parent.width
        y: Math.max(0, (wt.height - implicitHeight) / 2)
        visible: !!wt.wx
        spacing: 12

        // ── place · date, sunrise and sunset ──
        Item {
            width: parent.width
            height: placeCol.implicitHeight
            Column {
                id: placeCol
                x: 16
                GText {
                    text: wt.wx ? (wt.wx.place || "Here") : ""
                    color: wt.dash.onSurface
                    font.pointSize: 28; font.weight: Font.DemiBold
                }
                DText {
                    text: Qt.formatDate(wt.dash.now, "dddd, MMMM d")
                    color: wt.dash.onSurfaceVariant
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Repeater {
                    model: wt.wx ? [{ icon: "wb_twilight", text: wt.wx.sunrise }, { icon: "bedtime", text: wt.wx.sunset }] : []
                    delegate: Rectangle {
                        required property var modelData
                        width: sunRow.implicitWidth + 24; height: 36
                        radius: 2
                        color: "transparent"
                        border.color: wt.dash.outlineVariant; border.width: 1
                        Row {
                            id: sunRow
                            anchors.centerIn: parent
                            spacing: 6
                            IconText { text: parent.parent.modelData.icon; color: wt.dash.blood; font.pointSize: 14 }
                            DText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.parent.modelData.text
                                color: wt.dash.bone
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }

        // ── now ──
        Rectangle {
            width: parent.width
            height: 132
            radius: 2
            color: wt.dash.surfaceContainer
            border.color: wt.dash.outlineVariant; border.width: 1
            Row {
                anchors.left: parent.left; anchors.leftMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                spacing: 20
                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wt.wx ? wt.dash.wxIcon(wt.wx.code) : ""
                    color: wt.dash.secondary
                    font.pointSize: 64
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    DText {
                        text: wt.wx ? wt.dash.deg(wt.wx.tempC, wt.wx.tempF) : ""
                        color: wt.dash.primary
                        font.pointSize: 52; font.weight: Font.Medium
                    }
                    DText {
                        leftPadding: 4
                        text: wt.wx ? wt.wx.desc : ""
                        color: wt.dash.onSurfaceVariant
                        font.pointSize: 14
                    }
                }
            }
            Column {
                anchors.right: parent.right; anchors.rightMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                DText {
                    anchors.right: parent.right
                    text: wt.wx ? "Feels like " + wt.dash.deg(wt.wx.feelsC, wt.wx.feelsF) : ""
                    color: wt.dash.onSurface
                    font.pointSize: 14; font.weight: Font.Medium
                }
                DText {
                    anchors.right: parent.right
                    text: wt.wx ? "↓ " + wt.dash.deg(wt.wx.minC, wt.wx.minF) + "    ↑ " + wt.dash.deg(wt.wx.maxC, wt.wx.maxF) : ""
                    color: wt.dash.tertiary
                    font.pointSize: 13
                }
            }
        }

        // ── details ──
        Row {
            id: detailRow
            width: parent.width
            spacing: 8
            Repeater {
                model: !wt.wx ? [] : [
                    { icon: "humidity_percentage", label: "Humidity", value: wt.wx.humidity + "%", color: wt.dash.primary },
                    { icon: "air", label: "Wind", value: wt.wx.wind + " km/h " + wt.wx.windDir, color: wt.dash.secondary },
                    { icon: "compress", label: "Pressure", value: wt.wx.pressure + " hPa", color: wt.dash.tertiary },
                    { icon: "light_mode", label: "UV index", value: wt.wx.uv, color: wt.dash.error },
                    { icon: "visibility", label: "Visibility", value: wt.wx.visibility + " km", color: wt.dash.primary },
                    { icon: "water_drop", label: "Rain", value: wt.wx.precip + " mm", color: wt.dash.secondary }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: (detailRow.width - 5 * detailRow.spacing) / 6
                    height: 60
                    radius: 2
                    color: wt.dash.surfaceContainer
                    border.color: wt.dash.outlineVariant; border.width: 1
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.modelData.icon
                            color: parent.parent.modelData.color
                            font.pointSize: 18
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            DText {
                                text: parent.parent.parent.modelData.label
                                color: wt.dash.onSurfaceVariant
                                font.pointSize: 9
                            }
                            DText {
                                text: parent.parent.parent.modelData.value
                                color: wt.dash.onSurface
                                font.pointSize: 12; font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }

        GText {
            leftPadding: 12
            topPadding: 4
            text: "3-day forecast"
            color: wt.dash.onSurface
            font.pointSize: 14; font.weight: Font.DemiBold
        }

        // ── forecast ──
        Row {
            id: fcRow
            width: parent.width
            spacing: 8
            Repeater {
                model: wt.wx ? wt.wx.forecast : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: (fcRow.width - (wt.wx.forecast.length - 1) * fcRow.spacing) / Math.max(1, wt.wx.forecast.length)
                    height: fcCol.implicitHeight + 24
                    radius: 2
                    color: wt.dash.surfaceContainer
                    border.color: wt.dash.outlineVariant; border.width: 1
                    Row {
                        id: fcCol
                        anchors.centerIn: parent
                        spacing: 18
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            DText {
                                text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "dddd")
                                color: wt.dash.primary
                                font.pointSize: 14; font.weight: Font.DemiBold
                            }
                            DText {
                                text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "MMM d")
                                color: wt.dash.onSurfaceVariant
                            }
                        }
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: wt.dash.wxIcon(modelData.code, true)
                            color: wt.dash.secondary
                            font.pointSize: 30
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            DText {
                                text: wt.dash.deg(modelData.minC, modelData.minF) + " / " + wt.dash.deg(modelData.maxC, modelData.maxF)
                                color: wt.dash.tertiary
                                font.pointSize: 13; font.weight: Font.DemiBold
                            }
                            DText {
                                text: modelData.rain + "% rain"
                                color: wt.dash.onSurfaceVariant
                                font.pointSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
