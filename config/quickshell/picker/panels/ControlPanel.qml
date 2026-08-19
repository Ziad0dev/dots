import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: win
    required property var root

    visible: root.controlVisible
    screen: root.activePopupScreen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-control"
    WlrLayershell.keyboardFocus: root.controlVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }

    readonly property color island: Qt.rgba(
        root.paper.r + (root.ink.r - root.paper.r) * 0.07,
        root.paper.g + (root.ink.g - root.paper.g) * 0.07,
        root.paper.b + (root.ink.b - root.paper.b) * 0.07, 1.0)

    MouseArea {
        anchors.fill: parent
        onClicked: root.controlVisible = false
    }

    component SectionLabel: Text {
        font.family: win.root.mono
        font.pixelSize: 9
        font.letterSpacing: 1.6
        color: win.root.sumiHi
        topPadding: 10
        bottomPadding: 4
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool on: false
        signal clicked_()

        implicitWidth: ct.implicitWidth + 20
        implicitHeight: 26
        radius: 6
        color: chip.on ? win.root.seal
                       : (cma.containsMouse ? win.root.frameWeak : win.island)
        border.width: 1
        border.color: chip.on ? win.root.seal : win.root.sep
        scale: cma.containsMouse ? 1.04 : 1.0

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 110 } }

        Text {
            id: ct
            anchors.centerIn: parent
            text: chip.label
            font.family: win.root.mono
            font.pixelSize: 11
            color: chip.on ? win.root.paper : win.root.ink
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            id: cma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked_()
        }
    }

    component Toggle: Rectangle {
        id: tg
        property string label: ""
        property bool on: false
        signal clicked_()

        implicitWidth: 150
        implicitHeight: 30
        radius: 6
        color: tma.containsMouse ? win.root.frameWeak : "transparent"
        Behavior on color { ColorAnimation { duration: 180 } }

        Text {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: tg.label
            font.family: win.root.mono
            font.pixelSize: 11
            color: win.root.ink
        }

        Rectangle {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            width: 30; height: 16; radius: 8
            color: tg.on ? win.root.seal : win.root.sep
            Behavior on color { ColorAnimation { duration: 180 } }

            Rectangle {
                width: 12; height: 12; radius: 6
                color: win.root.paper
                y: 2
                x: tg.on ? 16 : 2
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: tma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tg.clicked_()
        }
    }

    Rectangle {
        id: card
        width: 360
        height: Math.min(col.implicitHeight + 28, win.height - 80)
        radius: 12
        color: root.paper
        border.width: 1
        border.color: root.sep

        x: 10
        y: 46
        opacity: root.controlVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.root.controlVisible = false
        }

        Flickable {
            anchors { fill: parent; margins: 14 }
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: parent.width
                spacing: 2

                SectionLabel { text: "ACTIONS" }

                Flow {
                    width: parent.width
                    spacing: 6
                    Chip {
                        label: "Launcher"
                        onClicked_: { root.controlVisible = false; root.launcherVisible = true }
                    }
                    Chip {
                        label: "Theme"
                        onClicked_: { root.controlVisible = false; root.open("theme") }
                    }
                    Chip {
                        label: "Wallpaper"
                        onClicked_: { root.controlVisible = false; root.open("wallpaper") }
                    }
                    Chip {
                        label: "Lock"
                        onClicked_: { root.controlVisible = false; lockProc.running = true }
                    }
                    Chip {
                        label: "Reload"
                        onClicked_: reloadProc.running = true
                    }
                }

                SectionLabel { text: "PICKER STYLE" }

                Flow {
                    width: parent.width
                    spacing: 6
                    Chip {
                        label: "Carousel"
                        on: root.pickerStyle === "carousel"
                        onClicked_: root.pickerStyle = "carousel"
                    }
                    Chip {
                        label: "Tanzaku"
                        on: root.pickerStyle === "tanzaku"
                        onClicked_: root.pickerStyle = "tanzaku"
                    }
                    Chip {
                        label: "Hearthstone"
                        on: root.pickerStyle === "hearthstone"
                        onClicked_: root.pickerStyle = "hearthstone"
                    }
                }

                SectionLabel { text: "WAVEFORM" }

                Flow {
                    width: parent.width
                    spacing: 6
                    Chip { label: "1"; on: root.waveLines === 1; onClicked_: root.waveLines = 1 }
                    Chip { label: "2"; on: root.waveLines === 2; onClicked_: root.waveLines = 2 }
                    Chip { label: "3"; on: root.waveLines === 3; onClicked_: root.waveLines = 3 }
                    Chip { label: "5"; on: root.waveLines === 5; onClicked_: root.waveLines = 5 }
                }
                Flow {
                    width: parent.width
                    spacing: 6
                    Chip { label: "Slow"; on: root.waveSpeed < 0.8; onClicked_: root.waveSpeed = 0.5 }
                    Chip { label: "Normal"; on: root.waveSpeed >= 0.8 && root.waveSpeed <= 1.4; onClicked_: root.waveSpeed = 1.0 }
                    Chip { label: "Fast"; on: root.waveSpeed > 1.4; onClicked_: root.waveSpeed = 2.2 }
                }

                SectionLabel { text: "BAR FUNCTIONS" }

                Toggle {
                    width: parent.width
                    label: "Waveform"
                    on: root.waveformActive
                    onClicked_: root.waveformActive = !root.waveformActive
                }
                Toggle {
                    width: parent.width
                    label: "Workspaces"
                    on: root.showWorkspaces
                    onClicked_: root.showWorkspaces = !root.showWorkspaces
                }
                Toggle {
                    width: parent.width
                    label: "System tray"
                    on: root.showTray
                    onClicked_: root.showTray = !root.showTray
                }
                Toggle {
                    width: parent.width
                    label: "CPU / Memory / Temp"
                    on: root.showSystem
                    onClicked_: root.showSystem = !root.showSystem
                }
                Toggle {
                    width: parent.width
                    label: "Clock"
                    on: root.showClock
                    onClicked_: root.showClock = !root.showClock
                }
                Toggle {
                    width: parent.width
                    label: "Volume"
                    on: root.showVolume
                    onClicked_: root.showVolume = !root.showVolume
                }
                Toggle {
                    width: parent.width
                    label: "Bar"
                    on: root.barVisible
                    onClicked_: root.barVisible = !root.barVisible
                }

                SectionLabel { text: "THEME" }

                Flow {
                    width: parent.width
                    spacing: 6
                    Chip { label: "Prev"; onClicked_: themeProc.step("prev") }
                    Chip { label: "Next"; onClicked_: themeProc.step("next") }
                    Chip { label: "BG prev"; onClicked_: themeProc.bg("prev") }
                    Chip { label: "BG next"; onClicked_: themeProc.bg("next") }
                }

                Item { width: 1; height: 8 }
            }
        }
    }

    Process { id: lockProc; command: ["hyprlock"] }
    Process { id: reloadProc; command: ["themectl", "reload"] }

    QtObject {
        id: themeProc
        function step(dir) { stepper.command = ["themectl", dir]; stepper.running = true }
        function bg(dir) { stepper.command = ["themectl", "bg", dir]; stepper.running = true }
    }
    Process { id: stepper }

    onVisibleChanged: if (visible) keyCatcher.forceActiveFocus()
}
