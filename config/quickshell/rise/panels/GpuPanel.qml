import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: gpuPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-gpu"

    readonly property int barBottom: 35
    readonly property int gap: 8

    readonly property real memPercent: root.gpuMemoryTotalMiB > 0
        ? Math.max(0, Math.min(100, root.gpuMemoryUsedMiB / root.gpuMemoryTotalMiB * 100))
        : 0
    readonly property real powerPercent: root.gpuPowerLimitW > 0
        ? Math.max(0, Math.min(100, root.gpuPowerW / root.gpuPowerLimitW * 100))
        : 0

    property real reveal: root.gpuVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.gpuVisible ? 160 : 120
            easing.type: root.gpuVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.gpuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.gpuVisible = false
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

        x: Math.round(Math.max(6, Math.min(root.gpuBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: gpuPanel.reveal
        focus: root.gpuVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.gpuVisible = false;
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
                    text: "GPU"
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
                        onClicked: root.gpuVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            UiText {
                width: parent.width
                visible: root.gpuAvailable
                text: root.gpuName
                color: root.sumiHi
                elide: Text.ElideRight
                font.family: root.mono
                font.pixelSize: 11
            }

            UiText {
                width: parent.width
                visible: !root.gpuAvailable
                text: "No GPU telemetry"
                color: root.sumi
                font.family: root.mono
                font.pixelSize: 11
            }

            Repeater {
                model: root.gpuAvailable ? [
                    { label: "UTIL",  value: root.gpuPercent + "%",
                      frac: root.gpuPercent / 100 },
                    { label: "VRAM",  value: (root.gpuMemoryUsedMiB / 1024).toFixed(1) + "/"
                        + (root.gpuMemoryTotalMiB / 1024).toFixed(1) + "G",
                      frac: gpuPanel.memPercent / 100 },
                    { label: "POWER", value: root.gpuPowerW.toFixed(0) + "/"
                        + root.gpuPowerLimitW.toFixed(0) + "W",
                      frac: gpuPanel.powerPercent / 100 }
                ] : []

                Item {
                    required property var modelData
                    width: col.width
                    height: 16

                    UiText {
                        id: rowLbl
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label; color: root.sumiHi
                        font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                    }
                    UiText {
                        id: rowVal
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.value; color: root.seal
                        font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                    }
                    Rectangle {
                        anchors.left: rowLbl.right; anchors.leftMargin: 8
                        anchors.right: rowVal.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8; radius: 4
                        color: root.fillActive
                        Rectangle {
                            width: Math.round(parent.width
                                * Math.max(0, Math.min(1, parent.parent.modelData.frac)))
                            height: parent.height
                            radius: parent.radius
                            color: root.seal
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep; visible: root.gpuAvailable }

            Grid {
                width: parent.width
                visible: root.gpuAvailable
                columns: 2
                columnSpacing: 8
                rowSpacing: 4

                Repeater {
                    model: root.gpuAvailable ? [
                        { k: "TEMP",   v: root.gpuTemperatureC + "\u00B0C" },
                        { k: "CLOCK",  v: root.gpuClockMHz + " MHz" },
                        { k: "FAN",    v: root.gpuFanPercent + "%" },
                        { k: "PSTATE", v: root.gpuPerformanceState },
                        { k: "DRIVER", v: root.gpuDriverVersion },
                        { k: "BACKEND", v: root.gpuBackend }
                    ] : []

                    Item {
                        required property var modelData
                        width: (col.width - 8) / 2
                        height: 14
                        UiText {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.k; color: root.sumiHi
                            font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                        }
                        UiText {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.v; color: root.ink
                            elide: Text.ElideRight
                            font.family: root.mono; font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
