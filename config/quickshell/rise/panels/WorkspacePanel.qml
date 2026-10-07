import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: wsPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-workspace"

    readonly property int barBottom: 35
    readonly property int gap: 8

    property real reveal: root.workspaceVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: "effects" }
    }
    visible: reveal > 0.001
        || (root.popout.last === "workspaceVisible" && root.popout.shown)
    WlrLayershell.keyboardFocus: root.workspaceVisible && !root.popout.hoverMode
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        readonly property bool hover: wsPanel.root.popout.hoverMode
        readonly property int gap: wsPanel.root.popout.gap
        x: hover ? popClip.x : 0
        y: hover ? popClip.y - (wsPanel.root.popout.barOnTop ? gap : 0) : 0
        width: hover ? popClip.width : wsPanel.width
        height: hover ? popClip.height + gap : wsPanel.height
    }

    MouseArea { anchors.fill: parent; onClicked: root.workspaceVisible = false }

    PopoutClip {
        id: popClip
        root: wsPanel.root
        flag: "workspaceVisible"
        card: card
        Rectangle {
            id: card
            width: 240
            height: col.implicitHeight + 24
            radius: reveal > 0.001 ? root.pillRadius : 0
            color: "transparent"
            border.color: root.pillBorder
            border.width: 0

            x: popClip.cardX
            y: popClip.cardY
            opacity: wsPanel.reveal
            focus: root.workspaceVisible

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.workspaceVisible = false; event.accepted = true }
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
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "Workspaces"
                        color: root.ink; font.family: root.gothic; font.pixelSize: 20
                        font.letterSpacing: 0.5; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                        Behavior on color { CAnim { ms: 120 } }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.workspaceVisible = false }
                    }
                }

                GrimRule { root: wsPanel.root; width: parent.width }

                Column {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: Hyprland.workspaces

                        delegate: Rectangle {
                            required property var modelData
                            visible: modelData.id > 0   // F13: hide special (negative-id) workspaces from the normal list
                            readonly property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
                            width: col.width
                            height: 30; radius: root.tileRadius
                            color: isActive ? root.fillActive
                                    : ma.containsMouse ? root.fillHover : root.fillIdle
                            border.color: (ma.containsMouse || isActive) ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { CAnim { ms: 120 } }

                            UiText {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Workspace " + modelData.id
                                color: (ma.containsMouse || isActive) ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 12
                                font.weight: isActive ? Font.Medium : Font.Normal
                            }
                            UiText {
                                anchors.right: parent.right; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.toplevels && modelData.toplevels.values ? modelData.toplevels.values.length : ""
                                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.gotoWorkspace(modelData.id)
                                    root.workspaceVisible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
