import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: kbPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-keybinds"

    readonly property int barBottom: 35
    readonly property int gap: 8

    readonly property var groups: [
        {
            title: "Apps & launcher",
            binds: [
                ["SUPER + Return", "Terminal"],
                ["SUPER + D", "App launcher"],
                ["SUPER + E", "Wallpaper picker"],
            ]
        },
        {
            title: "Windows",
            binds: [
                ["SUPER + H/J/K/L", "Focus window"],
                ["SUPER + SHIFT + H/J/K/L", "Move window"],
                ["SUPER + F", "Fullscreen"],
                ["SUPER + SHIFT + Space", "Toggle floating"],
                ["SUPER + Space", "Focus last window"],
                ["SUPER + SHIFT + Q", "Close window"],
                ["SUPER + R", "Resize mode"],
            ]
        },
        {
            title: "Workspaces",
            binds: [
                ["SUPER + 0-9", "Switch workspace"],
                ["SUPER + SHIFT + 0-9", "Move window to workspace"],
                ["SUPER + Tab", "Next workspace"],
                ["SUPER + SHIFT + Tab", "Previous workspace"],
                ["SUPER + Minus", "Toggle special workspace"],
                ["SUPER + SHIFT + Minus", "Move window to special"],
            ]
        },
        {
            title: "Theming",
            binds: [
                ["SUPER + CTRL + SHIFT + Space", "Theme picker"],
                ["SUPER + SHIFT + T", "Next theme"],
                ["SUPER + CTRL + E", "Next wallpaper"],
            ]
        },
        {
            title: "Screenshots & recording",
            binds: [
                ["Print", "Screenshot region (edit)"],
                ["SUPER + Print", "Screenshot full (copy)"],
                ["SUPER + SHIFT + R", "Save replay buffer"],
                ["SUPER + ALT + R", "Toggle replay buffer"],
            ]
        },
        {
            title: "System",
            binds: [
                ["SUPER + Escape", "Lock screen"],
                ["SUPER + CTRL + L", "Lock screen"],
                ["SUPER + CTRL + R", "Reload Hyprland"],
                ["SUPER + SHIFT + E", "Exit Hyprland"],
            ]
        },
    ]

    property real reveal: root.keybindsVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.keybindsVisible ? 160 : 120
            easing.type: root.keybindsVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.keybindsVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.keybindsVisible = false }

    Rectangle {
        id: card
        width: 360
        height: Math.min(col.implicitHeight + 24, parent.height - kbPanel.barBottom - kbPanel.gap * 2)
        radius: root.pillRadius
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW

        x: Math.round(Math.max(6, Math.min(root.quickActionsBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - kbPanel.barBottom - kbPanel.gap - height)
            : (kbPanel.barBottom + kbPanel.gap)
        opacity: kbPanel.reveal
        focus: root.keybindsVisible
        clip: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.keybindsVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: scroller.width
                spacing: 10

                Item {
                    width: parent.width
                    height: 24
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "KEYBINDS"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: closeMa.containsMouse ? root.seal : root.sumi
                        font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: 120 } }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.keybindsVisible = false
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.sep }

                Repeater {
                    model: kbPanel.groups
                    delegate: Column {
                        id: groupCol
                        required property var modelData
                        width: col.width
                        spacing: 4

                        UiText {
                            text: groupCol.modelData.title
                            color: root.sumiHi
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }

                        Repeater {
                            model: groupCol.modelData.binds
                            delegate: Row {
                                id: bindRow
                                required property var modelData
                                width: groupCol.width
                                height: 20
                                UiText {
                                    text: bindRow.modelData[0]
                                    color: root.seal
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    width: bindRow.width * 0.52
                                    elide: Text.ElideRight
                                }
                                UiText {
                                    text: bindRow.modelData[1]
                                    color: root.ink
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    width: bindRow.width * 0.48
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
