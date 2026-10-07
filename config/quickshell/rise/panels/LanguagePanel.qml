import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: langPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-language"

    readonly property int barBottom: 35
    readonly property int gap: 8

    LanguageData { id: lang; watch: false }

    property real reveal: root.langVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: "effects" }
    }
    visible: reveal > 0.001
        || (root.popout.last === "langVisible" && root.popout.shown)
    WlrLayershell.keyboardFocus: root.langVisible && !root.popout.hoverMode
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        readonly property bool hover: langPanel.root.popout.hoverMode
        readonly property int gap: langPanel.root.popout.gap
        x: hover ? popClip.x : 0
        y: hover ? popClip.y - (langPanel.root.popout.barOnTop ? gap : 0) : 0
        width: hover ? popClip.width : langPanel.width
        height: hover ? popClip.height + gap : langPanel.height
    }
    onVisibleChanged: if (visible) lang.refresh()

    MouseArea {
        anchors.fill: parent
        onClicked: root.langVisible = false
    }

    PopoutClip {
        id: popClip
        root: langPanel.root
        flag: "langVisible"
        card: card
        Rectangle {
            id: card
            width: 220
            height: col.implicitHeight + 24
            radius: reveal > 0.001 ? root.pillRadius : 0
            color: "transparent"
            border.color: root.pillBorder
            border.width: 0

            x: popClip.cardX
            y: popClip.cardY
            opacity: langPanel.reveal
            focus: root.langVisible

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.langVisible = false;
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
                        text: "Keyboard layout"
                        color: root.ink
                        font.family: root.gothic
                        font.pixelSize: 20
                        font.letterSpacing: 0.5
                        font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: closeMa.containsMouse ? root.seal : root.sumi
                        font.pixelSize: 12
                        Behavior on color { CAnim { ms: 120 } }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.langVisible = false
                        }
                    }
                }

                Repeater {
                    model: lang.layouts
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool active: index === lang.activeIndex
                        width: parent.width
                        height: 32
                        radius: root.tileRadius
                        color: active ? root.fillActive : itemMa.containsMouse ? root.fillHover : root.fillIdle
                        border.color: active ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { CAnim { ms: 120 } }

                        UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.full
                            color: row.active ? root.seal : root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                        UiText {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            color: row.active ? root.seal : root.sumi
                            font.family: root.mono
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: itemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                lang.switchTo(row.index)
                                root.langVisible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
