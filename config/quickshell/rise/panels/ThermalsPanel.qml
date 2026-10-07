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
        Anim { kind: "effects" }
    }
    visible: reveal > 0.001
        || (root.popout.last === "thermalVisible" && root.popout.shown)
    WlrLayershell.keyboardFocus: root.thermalVisible && !root.popout.hoverMode
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        readonly property bool hover: thermalsPanel.root.popout.hoverMode
        readonly property int gap: thermalsPanel.root.popout.gap
        x: hover ? popClip.x : 0
        y: hover ? popClip.y - (thermalsPanel.root.popout.barOnTop ? gap : 0) : 0
        width: hover ? popClip.width : thermalsPanel.width
        height: hover ? popClip.height + gap : thermalsPanel.height
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.thermalVisible = false
    }

    PopoutClip {
        id: popClip
        root: thermalsPanel.root
        flag: "thermalVisible"
        card: card
        Rectangle {
            id: card
            width: 320
            height: col.implicitHeight + 24
            radius: reveal > 0.001 ? root.pillRadius : 0
            color: "transparent"
            border.color: root.pillBorder
            border.width: 0

            x: popClip.cardX
            y: popClip.cardY
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
                        text: "Thermals"
                        color: root.ink
                        font.family: root.gothic
                        font.pixelSize: 20
                        font.letterSpacing: 0.5
                        font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u2715"
                        color: closeMa.containsMouse ? root.seal : root.sumi
                        font.pixelSize: 12
                        Behavior on color { CAnim { ms: 120 } }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.thermalVisible = false
                        }
                    }
                }

                GrimRule { root: thermalsPanel.root; width: parent.width }

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
                                Behavior on width { Anim { kind: "size"; ms: 250 } }
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
}
