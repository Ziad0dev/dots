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
        NumberAnimation {
            duration: root.langVisible ? 160 : 120
            easing.type: root.langVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.langVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onVisibleChanged: if (visible) lang.refresh()

    MouseArea {
        anchors.fill: parent
        onClicked: root.langVisible = false
    }

    Rectangle {
        id: card
        width: 220
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.languageBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
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
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 1
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
                    Behavior on color { ColorAnimation { duration: 120 } }

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
