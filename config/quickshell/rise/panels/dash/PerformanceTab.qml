import QtQuick
import "../../modules"

// Performance tab (Caelestia's layout): CPU and GPU hero cards over storage,
// network and memory. The hero cards keep the usage history behind them.
Item {
    id: pt
    required property var dash
    readonly property var root: dash.root
    property bool shown: true
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    readonly property int gap: 12
    // the lower row sets the width; the hero cards share it (one card spans it without a GPU)
    readonly property int memoryW: 200
    implicitWidth: storageCard.width + netCard.width + memoryW + 2 * gap
    readonly property real heroW: root.gpuAvailable ? (width - gap) / 2 : width
    implicitHeight: heroRow.height + gap + lowerRow.height + gap + footer.implicitHeight

    Row {
        id: heroRow
        spacing: pt.gap
        Hero {
            width: pt.heroW
            icon: "memory"
            label: "CPU"
            sub: pt.root.cpuModelName || ""
            sub2: "load " + pt.root.systemLoad1.toFixed(2) + " · " + pt.root.systemLoad5.toFixed(2) + " · " + pt.root.systemLoad15.toFixed(2)
            usage: pt.root.systemCpuPercent
            temp: pt.root.cpuTemperatureAvailable ? pt.root.cpuTemperatureC : -1
            history: pt.root.cpuHist
            accent: pt.dash.primary
        }
        Hero {
            visible: pt.root.gpuAvailable
            width: pt.heroW
            icon: "developer_board"
            label: "GPU"
            sub: pt.root.gpuName || ""
            sub2: (pt.root.gpuMemoryTotalMiB > 0 ? (pt.root.gpuMemoryUsedMiB / 1024).toFixed(1) + " / " + (pt.root.gpuMemoryTotalMiB / 1024).toFixed(0) + " GiB" : "")
                + (pt.root.gpuPowerW > 0 ? "  ·  " + Math.round(pt.root.gpuPowerW) + " W" : "")
            usage: pt.root.gpuPercent
            temp: pt.root.gpuTemperatureC > 0 ? pt.root.gpuTemperatureC : -1
            history: pt.root.gpuHist
            accent: pt.dash.secondary
        }
    }

    Row {
        id: lowerRow
        y: heroRow.height + pt.gap
        spacing: pt.gap
        height: 220

        // ── storage ──
        Rectangle {
            id: storageCard
            width: storageRow.implicitWidth + 56
            height: parent.height
            radius: 48
            color: pt.dash.surfaceContainer
            Row {
                id: storageRow
                anchors.centerIn: parent
                spacing: 16
                Ring {
                    width: 128; height: 128
                    anchors.verticalCenter: parent.verticalCenter
                    startAngle: 135; sweep: 270
                    value: pt.root.storagePercent / 100
                    color: pt.dash.secondary
                    trackColor: pt.dash.secondaryContainer
                    Column {
                        anchors.centerIn: parent
                        IconText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "hard_drive"
                            color: pt.dash.secondary
                            font.pointSize: 18
                        }
                        DText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pt.root.storagePercent + "%"
                            color: pt.dash.secondary
                            font.pointSize: 22; font.weight: Font.Medium
                            font.variableAxes: { "wdth": 90 }
                        }
                        DText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Used"
                            color: pt.dash.onSurfaceVariant
                        }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    width: 150
                    DText {
                        text: "Storage"
                        color: pt.dash.onSurface
                        font.pointSize: 16; font.weight: Font.Medium
                    }
                    DText {
                        width: parent.width
                        text: pt.root.storageTotalGiB > 0 ? pt.root.storageUsedGiB.toFixed(0) + " / " + pt.root.storageTotalGiB.toFixed(0) + " GiB" : "No disks"
                        color: pt.dash.secondary
                        font.pointSize: 16
                    }
                }
            }
        }

        // ── network ──
        Rectangle {
            id: netCard
            width: 390
            height: parent.height
            radius: 28
            color: pt.dash.surfaceContainer
            readonly property real peak: Math.max(1024, Math.max.apply(null, pt.dash.rxHist.concat(pt.dash.txHist).concat([0])))
            Row {
                id: netTitle
                x: 16; y: 16
                spacing: 8
                IconText { text: "swap_vert"; color: pt.dash.primary; font.pointSize: 18 }
                DText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Network"
                    color: pt.dash.onSurface
                    font.pointSize: 16; font.weight: Font.Medium
                }
            }
            Item {
                x: 16; width: parent.width - 32
                y: netTitle.y + netTitle.height + 12
                height: parent.height - y - 76
                Graph {
                    anchors.fill: parent
                    values: pt.dash.txHist
                    maxValue: netCard.peak
                    lineColor: pt.dash.secondary
                    fillAlpha: 0.15
                }
                Graph {
                    anchors.fill: parent
                    values: pt.dash.rxHist
                    maxValue: netCard.peak
                    lineColor: pt.dash.tertiary
                    fillAlpha: 0.2
                }
                DText {
                    anchors.centerIn: parent
                    visible: pt.dash.rxHist.length < 2
                    text: "Collecting data…"
                    color: pt.dash.outline
                }
            }
            Column {
                x: 16; width: parent.width - 32
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                spacing: 4
                Repeater {
                    model: [
                        { icon: "download", label: "Download", rate: pt.dash.rxRate, color: pt.dash.tertiary },
                        { icon: "upload", label: "Upload", rate: pt.dash.txRate, color: pt.dash.secondary }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: parent.width; height: 24
                        IconText {
                            id: rateIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.icon
                            color: parent.modelData.color
                            font.pointSize: 16
                        }
                        DText {
                            anchors.left: rateIcon.right; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.label
                            color: pt.dash.onSurfaceVariant
                        }
                        DText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: pt.dash.rate(parent.modelData.rate)
                            color: parent.modelData.color
                            font.pointSize: 13; font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        // ── memory ──
        Rectangle {
            width: pt.width - storageCard.width - netCard.width - 2 * pt.gap
            height: parent.height
            radius: 12
            color: pt.dash.surfaceContainer
            Column {
                anchors.centerIn: parent
                spacing: 4
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    IconText { text: "memory_alt"; fill: 1; color: pt.dash.tertiary; font.pointSize: 18 }
                    DText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Memory"
                        color: pt.dash.onSurface
                        font.pointSize: 16; font.weight: Font.Medium
                    }
                }
                Ring {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 112; height: 112
                    startAngle: 135; sweep: 270
                    value: pt.root.systemMemPercent / 100
                    color: pt.dash.tertiary
                    trackColor: pt.dash.secondaryContainer
                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 4
                        DText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pt.root.systemMemPercent + "%"
                            color: pt.dash.tertiary
                            font.pointSize: 22; font.weight: Font.Medium
                            font.variableAxes: { "wdth": 90 }
                        }
                        DText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Used"
                            color: pt.dash.onSurfaceVariant
                        }
                    }
                }
                DText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pt.root.systemMemUsedGiB.toFixed(1) + " / " + pt.root.systemMemTotalGiB.toFixed(1) + " GiB"
                    color: pt.dash.onSurface
                    font.pointSize: 13
                }
            }
        }
    }

    DText {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: (pt.root.kernelRelease ? "linux " + pt.root.kernelRelease : "") + (pt.dash.uptimeS > 0 ? "   ·   up " + pt.dash.uptimeText : "")
        color: pt.dash.outline
        font.pointSize: 10
    }

    component Hero: Rectangle {
        id: hero
        property string icon
        property string label
        property string sub
        property string sub2
        property real usage: 0        // percent
        property int temp: -1         // °C, -1 = unknown
        property var history: []
        property color accent
        height: 160
        radius: 28
        color: pt.dash.surfaceContainer
        clip: true

        Graph {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: parent.height * 0.55
            values: hero.history
            lineColor: hero.accent
            fillAlpha: 0.14
            lineWidth: 1.5
            opacity: 0.55
        }

        Ring {
            id: heroRing
            x: 16; y: 16
            width: 52; height: 52
            thickness: 4
            value: hero.usage / 100
            color: hero.accent
            trackColor: pt.dash.secondaryContainer
            IconText {
                anchors.centerIn: parent
                text: hero.icon
                color: hero.accent
                font.pointSize: 17
            }
        }
        Column {
            anchors.left: heroRing.right; anchors.leftMargin: 14
            anchors.right: usageShape.left; anchors.rightMargin: 8
            anchors.verticalCenter: heroRing.verticalCenter
            spacing: 2
            DText {
                text: hero.label
                color: hero.accent
                font.pointSize: 16; font.weight: Font.Medium
            }
            DText {
                width: parent.width
                text: hero.sub
                color: pt.dash.onSurfaceVariant
                font.pointSize: 10
            }
            DText {
                width: parent.width
                visible: text !== ""
                text: hero.sub2
                color: pt.dash.onSurfaceVariant
                font.pointSize: 10
            }
        }

        Column {
            x: 20
            anchors.bottom: parent.bottom; anchors.bottomMargin: 20
            spacing: 6
            visible: hero.temp >= 0
            Row {
                spacing: 4
                IconText {
                    text: hero.temp > 90 ? "thermometer_alert" : "thermometer"
                    color: hero.temp > 90 ? pt.dash.error : hero.accent
                    fill: 1
                    font.pointSize: 17
                }
                DText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hero.temp + "°C"
                    color: pt.dash.onSurface
                    font.pointSize: 14
                }
            }
            Rectangle {
                width: 170; height: 8; radius: 4
                color: pt.dash.secondaryContainer
                Rectangle {
                    height: parent.height; radius: 4
                    width: Math.max(height, parent.width * Math.min(1, hero.temp / 100))
                    color: hero.accent
                    Behavior on width { Anim { kind: "size"; ms: 600 } }
                }
            }
        }

        DashShape {
            id: usageShape
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 12
            width: 100; height: 100
            kind: hero.usage >= 80 ? "burst" : hero.usage >= 40 ? "sunny" : "cookie"
            sides: hero.usage >= 80 ? 0 : hero.usage >= 40 ? 0 : 4
            color: pt.dash.secondaryContainer
            DText {
                anchors.centerIn: parent
                text: Math.round(hero.usage) + "%"
                color: hero.accent
                font.pointSize: 22
                font.variableAxes: { "wdth": 60 }
            }
        }
        DText {
            anchors.bottom: usageShape.top; anchors.bottomMargin: 2
            anchors.horizontalCenter: usageShape.horizontalCenter
            text: "Usage"
            color: pt.dash.onSurfaceVariant
            font.pointSize: 10
        }
    }
}
