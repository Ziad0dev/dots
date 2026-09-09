import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: thermalsPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-thermals"

    readonly property int barBottom: 35
    readonly property int gap: 8

    property real reveal: root.thermalVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.thermalVisible ? 160 : 120
            easing.type: root.thermalVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.thermalVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.thermalVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.thermalBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: thermalsPanel.reveal
        focus: root.thermalVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.thermalVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "THERMALS"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.thermalVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Repeater {
                model: [
                    { label: "CPU PKG",  value: root.cpuTemperatureC,
                      crit: root.cpuTemperatureCriticalC > 0 ? root.cpuTemperatureCriticalC : 100 },
                    { label: "CORE MAX", value: root.cpuCoreMaxTemperatureC,
                      crit: root.cpuTemperatureCriticalC > 0 ? root.cpuTemperatureCriticalC : 100 },
                    { label: "GPU",      value: root.gpuTemperatureC, crit: 90 },
                    { label: "NVME",     value: root.nvmeTemperatureC,
                      crit: root.nvmeTemperatureCriticalC > 0 ? root.nvmeTemperatureCriticalC : 85 },
                    { label: "MEMORY",   value: root.memoryTemperatureC, crit: 85 }
                ]

                Item {
                    required property var modelData
                    visible: modelData.value > 0
                    width: col.width
                    height: visible ? 16 : 0

                    UiText {
                        id: tLbl
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label; color: root.sumiHi
                        font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                    }
                    UiText {
                        id: tVal
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.value + "\u00B0C"
                        color: parent.modelData.value >= parent.modelData.crit * 0.9 ? root.color01 : root.seal
                        font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                    }
                    Rectangle {
                        anchors.left: tLbl.right; anchors.leftMargin: 8
                        anchors.right: tVal.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8; radius: 4
                        color: root.fillActive
                        Rectangle {
                            width: Math.round(parent.width * Math.max(0, Math.min(1,
                                parent.parent.modelData.value / parent.parent.modelData.crit)))
                            height: parent.height
                            radius: parent.radius
                            color: parent.parent.modelData.value >= parent.parent.modelData.crit * 0.9
                                ? root.color01 : root.seal
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Item {
                width: parent.width
                height: 14
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "BAR SOURCE"; color: root.sumiHi
                    font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: root.barTemperatureSourceLabel(root.barTemperatureSource)
                    color: srcMa.containsMouse ? root.seal : root.ink
                    font.family: root.mono; font.pixelSize: 10
                    MouseArea {
                        id: srcMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var order = ["cpu", "core", "gpu", "nvme", "memory"]
                            var i = order.indexOf(root.barTemperatureSource)
                            for (var n = 1; n <= order.length; n++) {
                                var cand = order[(i + n) % order.length]
                                if (root.barTemperatureSourceAvailable(cand)) {
                                    root.barTemperatureSource = cand
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
