import QtQuick
import "../modules"

// Workspace layouts (Omarchy 4.5's Super + L and its Workspace Layout menu):
// this workspace tiles, scrolls or floats, and the default for every
// workspace without one of its own. Choices go through `dots-layout`
// (Theme: wsLayout*), which applies them in Hyprland.
ToolPanel {
    id: layPanel
    flag: "layoutVisible"
    title: "Layout"
    namespace: "dots-layout"
    cardWidth: 320

    component Choice: Rectangle {
        id: choice
        required property string mode
        property bool current: false
        signal picked()
        width: root.evenW((layPanel.innerWidth - 2 * 6) / 3)
        height: 58
        radius: root.tileRadius
        color: current ? root.fillActive : choiceMa.containsMouse ? root.fillHover : root.fillIdle
        border.width: current ? 1 : 0
        border.color: root.seal
        Behavior on color { CAnim { ms: 140 } }

        Column {
            anchors.centerIn: parent
            spacing: 2
            IconText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.wsLayoutIcon(choice.mode)
                font.pixelSize: 20
                color: choice.current ? root.seal : root.ink
                fill: choice.current ? 1 : 0
            }
            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.wsLayoutLabel(choice.mode)
                color: choice.current ? root.ink : root.sumi
                font.family: root.mono
                font.pixelSize: 11
            }
        }
        MouseArea {
            id: choiceMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.picked()
        }
    }

    UiText {
        text: root.wsLayoutWorkspace >= 1 ? "Workspace " + root.wsLayoutWorkspace : "This workspace keeps its own layout"
        color: root.sumi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
    }
    Row {
        spacing: 6
        visible: root.wsLayoutWorkspace >= 1
        Repeater {
            model: root.wsLayoutModes
            delegate: Choice {
                required property string modelData
                mode: modelData
                current: root.wsLayoutCurrent === modelData
                onPicked: root.setWsLayout(modelData)
            }
        }
    }

    Rectangle { width: layPanel.innerWidth; height: 1; color: root.sep }

    UiText {
        text: "New workspaces"
        color: root.sumi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
    }
    Row {
        spacing: 6
        Repeater {
            model: root.wsLayoutModes
            delegate: Choice {
                required property string modelData
                mode: modelData
                current: root.wsLayoutDefault === modelData
                onPicked: root.setDefaultWsLayout(modelData)
            }
        }
    }

    UiText {
        width: layPanel.innerWidth
        wrapMode: Text.WordWrap
        text: "Super + T cycles this workspace, Super + Ctrl + T backwards. A new default leaves workspaces with windows as they are."
        color: root.sumi; font.family: root.mono; font.pixelSize: 10
    }
}
