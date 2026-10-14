import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

// Themed system-tray context menu, rendered from the DBusMenu model so it
// matches the bar (QsMenuAnchor draws its own unthemeable native popup).
PanelWindow {
    id: trayMenu
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-traymenu"

    readonly property int gap: 8

    // drill-down stack of menu handles (root menu + any opened submenus)
    property var menuStack: []
    readonly property var currentHandle: menuStack.length > 0 ? menuStack[menuStack.length - 1] : null

    function strip(t) { return (t || "").replace(/_([^_])/, "$1") }   // drop GTK mnemonic underscore

    Connections {
        target: root
        function onTrayMenuVisibleChanged() {
            trayMenu.menuStack = root.trayMenuVisible && root.trayMenuHandle ? [root.trayMenuHandle] : []
        }
        // another tray app took over the open menu: show its menu from the top
        function onTrayMenuHandleChanged() {
            if (root.trayMenuVisible && root.trayMenuHandle)
                trayMenu.menuStack = [root.trayMenuHandle]
        }
    }

    QsMenuOpener {
        id: opener
        menu: trayMenu.currentHandle
    }

    property real reveal: root.trayMenuVisible ? 1 : 0
    Behavior on reveal {
        // Keep the frame blob responsive; it reshapes as this value changes.
        NumberAnimation { duration: root.trayMenuVisible ? 90 : 70; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001 || (root.popout.last === "trayMenuVisible" && root.popout.shown)
    WlrLayershell.keyboardFocus: root.trayMenuVisible && !root.popout.hoverMode
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        readonly property bool hover: trayMenu.root.popout.hoverMode
        readonly property int gap: trayMenu.gap
        x: hover ? popClip.x : 0
        y: hover ? popClip.y - (trayMenu.root.barPosition === "bottom" ? 0 : gap) : 0
        width: hover ? popClip.width : trayMenu.width
        height: hover ? popClip.height + gap : trayMenu.height
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.trayMenuVisible = false
    }

    // The shared PopoutMorph owns this surface and its frame rim. Keep the
    // menu content transparent so the border transfers with every popout.
    PopoutClip {
        id: popClip
        root: trayMenu.root
        flag: "trayMenuVisible"
        card: card

        Rectangle {
            id: card
            width: 220
            height: col.implicitHeight + 16
            radius: root.pillRadius
            color: "transparent"
            border.color: root.pillBorder
            border.width: 0

            x: popClip.cardX
            y: popClip.cardY
            opacity: trayMenu.reveal
            focus: root.trayMenuVisible && !root.popout.hoverMode

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.trayMenuVisible = false; event.accepted = true }
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: col
                anchors.fill: parent
                anchors.margins: 8
                spacing: 1

                // App identity stays visible while navigating its DBusMenu tree.
                Item {
                    width: parent.width
                    height: 28

                    TrayAppIcon {
                        id: appIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.trayMenuItem !== null
                        root: trayMenu.root
                        item: root.trayMenuItem || ({})
                        size: 16
                    }

                    UiText {
                        anchors.left: appIcon.right
                        anchors.leftMargin: appIcon.visible ? 8 : 0
                        anchors.right: closeX.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.trayMenuTitle !== "" ? root.trayMenuTitle : "App Menu"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    UiText {
                        id: closeX
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u2715"
                        color: closeMa.containsMouse ? root.seal : root.sumi
                        font.pixelSize: 12
                        Behavior on color { CAnim { ms: 120 } }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.trayMenuVisible = false
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.sep }

                // back row (only when inside a submenu)
                Rectangle {
                    width: parent.width; height: 24; radius: root.tileRadius
                    visible: trayMenu.menuStack.length > 1
                    color: backMa.containsMouse ? root.fillHover : "transparent"
                    UiText {
                        anchors.left: parent.left; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "‹  back"; color: root.sumiHi
                        font.family: root.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: trayMenu.menuStack = trayMenu.menuStack.slice(0, -1)
                    }
                }
                Rectangle {
                    width: parent.width; height: 1; color: root.sep
                    visible: trayMenu.menuStack.length > 1
                }

                Repeater {
                    model: opener.children

                    delegate: Item {
                        id: entry
                        required property var modelData
                        width: col.width
                        height: modelData.isSeparator ? 7 : 26

                        // separator
                        Rectangle {
                            visible: entry.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 1
                            color: root.sep
                        }

                        // entry row
                        Rectangle {
                            visible: !entry.modelData.isSeparator
                            anchors.fill: parent
                            radius: root.tileRadius
                            color: (entryMa.containsMouse && entry.modelData.enabled)
                                ? root.fillActive : "transparent"
                            Behavior on color { CAnim { ms: 100 } }

                            // check / radio indicator
                            UiText {
                                id: check
                                anchors.left: parent.left; anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                text: entry.modelData.checkState === Qt.Checked ? "✓" : ""
                                color: root.seal
                                font.family: root.mono; font.pixelSize: 11
                            }

                            Image {
                                id: entryIcon
                                anchors.left: check.right; anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: (entry.modelData.icon || "") !== ""
                                source: entry.modelData.icon || ""
                                sourceSize.width: 14; sourceSize.height: 14
                                width: visible ? 14 : 0; height: 14
                                fillMode: Image.PreserveAspectFit; smooth: true
                            }

                            UiText {
                                anchors.left: entryIcon.right; anchors.leftMargin: 6
                                anchors.right: arrow.left; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: trayMenu.strip(entry.modelData.text)
                                color: entry.modelData.enabled ? root.ink
                                     : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                                font.family: root.mono; font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            // submenu arrow
                            UiText {
                                id: arrow
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entry.modelData.hasChildren
                                text: "›"; color: root.sumiHi
                                font.family: root.mono; font.pixelSize: 13
                            }

                            MouseArea {
                                id: entryMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: entry.modelData.enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (entry.modelData.hasChildren) {
                                        trayMenu.menuStack = trayMenu.menuStack.concat([entry.modelData])
                                    } else {
                                        entry.modelData.triggered()
                                        root.trayMenuVisible = false
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
