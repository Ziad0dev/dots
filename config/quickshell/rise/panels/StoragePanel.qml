import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: storagePanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-storage"

    readonly property int barBottom: 35
    readonly property int gap: 8

    function gib(bytes) { return (bytes / 1073741824).toFixed(1) }
    function sizeLabel(bytes) {
        if (bytes >= 1099511627776) return (bytes / 1099511627776).toFixed(1) + " TiB"
        return (bytes / 1073741824).toFixed(0) + " GiB"
    }

    property real reveal: root.storageVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: "effects" }
    }
    visible: reveal > 0.001
        || (root.popout.last === "storageVisible" && root.popout.shown)
    WlrLayershell.keyboardFocus: root.storageVisible && !root.popout.hoverMode
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        readonly property bool hover: storagePanel.root.popout.hoverMode
        readonly property int gap: storagePanel.root.popout.gap
        x: hover ? popClip.x : 0
        y: hover ? popClip.y - (storagePanel.root.popout.barOnTop ? gap : 0) : 0
        width: hover ? popClip.width : storagePanel.width
        height: hover ? popClip.height + gap : storagePanel.height
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.storageVisible = false
    }

    PopoutClip {
        id: popClip
        root: storagePanel.root
        flag: "storageVisible"
        card: card
        Rectangle {
            id: card
            width: 380
            height: col.implicitHeight + 24
            radius: reveal > 0.001 ? root.pillRadius : 0
            color: "transparent"
            border.color: root.pillBorder
            border.width: 0

            x: popClip.cardX
            y: popClip.cardY
            opacity: storagePanel.reveal
            focus: root.storageVisible

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.storageVisible = false;
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
                        text: "Storage"
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
                            onClicked: root.storageVisible = false
                        }
                    }
                }

                GrimRule { root: storagePanel.root; width: parent.width }

                Item {
                    width: parent.width
                    height: 16
                    visible: root.storageAvailable
                    UiText {
                        id: rLbl
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "ROOT"; color: root.sumiHi
                        font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                    }
                    UiText {
                        id: rVal
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: storagePanel.gib(root.storageUsedBytes) + "/"
                            + storagePanel.gib(root.storageTotalBytes) + "G"
                        color: root.storagePercent >= 90 ? root.color01 : root.seal
                        font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                    }
                    Rectangle {
                        anchors.left: rLbl.right; anchors.leftMargin: 8
                        anchors.right: rVal.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8; radius: 4
                        color: root.fillActive
                        Rectangle {
                            width: Math.round(parent.width * Math.max(0, Math.min(1, root.storagePercent / 100)))
                            height: parent.height
                            radius: parent.radius
                            color: root.storagePercent >= 90 ? root.color01 : root.seal
                            Behavior on width { Anim { kind: "size"; ms: 250 } }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1; color: root.sep
                    visible: root.storageInventoryAvailable && root.storageDrives.length > 0
                }

                Repeater {
                    model: root.storageInventoryAvailable ? root.storageDrives : []

                    Column {
                        required property var modelData
                        width: col.width
                        spacing: 3

                        Item {
                            width: parent.width
                            height: 14
                            UiText {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.6
                                text: parent.parent.modelData.model
                                color: root.ink; elide: Text.ElideRight
                                font.family: root.mono; font.pixelSize: 10
                            }
                            UiText {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: parent.parent.modelData.media + "  "
                                    + storagePanel.sizeLabel(parent.parent.modelData.size)
                                color: root.sumiHi
                                font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                            }
                        }

                        Item {
                            width: parent.width
                            height: 14
                            UiText {
                                id: dState
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: parent.parent.modelData.state
                                color: root.sumi; elide: Text.ElideRight
                                font.family: root.mono; font.pixelSize: 10
                            }
                            UiText {
                                id: dPct
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                visible: parent.parent.modelData.percent >= 0
                                text: parent.parent.modelData.percent + "%"
                                color: parent.parent.modelData.percent >= 90 ? root.color01 : root.seal
                                font.family: root.mono; font.pixelSize: 10; font.weight: Font.Medium
                            }
                            Rectangle {
                                visible: parent.parent.modelData.percent >= 0
                                anchors.left: dState.right; anchors.leftMargin: 8
                                anchors.right: dPct.left; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                height: 6; radius: 3
                                color: root.fillActive
                                Rectangle {
                                    width: Math.round(parent.width * Math.max(0, Math.min(1,
                                        parent.parent.parent.modelData.percent / 100)))
                                    height: parent.height
                                    radius: parent.radius
                                    color: parent.parent.parent.modelData.percent >= 90 ? root.color01 : root.seal
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
