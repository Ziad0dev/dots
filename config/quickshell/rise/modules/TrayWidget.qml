import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

// Every tray app shows here unless it's in trayHiddenIcons; hidden ones live
// in the overflow panel (TrayPanel) behind the "…" button.
//   left: activate (or the menu, for menu-only apps)   middle: the app's menu
//   right: hide into the overflow                       hover: the menu, with hover popouts on
Item {
    id: rootMod
    required property var root

    // apps in the overflow panel, i.e. running but hidden from the bar
    readonly property int hiddenCount: {
        var n = 0, vals = SystemTray.items.values
        for (var i = 0; i < vals.length; i++)
            if (root.trayIsSuppressed(vals[i])) n++
        return n
    }

    implicitWidth: trayRow.implicitWidth + (root.trayBackground ? 12 : 0)
    implicitHeight: 28
    visible: trayRow.implicitWidth > 0

    function showMenu(item, anchor, pinned) {
        if (!item || !item.hasMenu) return
        root.openTrayMenu(item.menu, root.trayDisplayName(item), item, anchor, pinned)
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: root.pillH
        radius: root.pillRadius
        visible: root.trayBackground
        color: root.widgetFillColor("G3")
        border.color: root.widgetBorderColor("G3")
        border.width: root.widgetBorderWidth("G3")
        PillShadow { theme: root }
    }

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: root.trayCompact ? 1 : 5

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate
                required property SystemTrayItem modelData

                readonly property bool suppressed: root.trayIsSuppressed(modelData)
                readonly property int iconSize: root.trayCompact ? 14 : 18
                implicitWidth: root.trayCompact ? 18 : 24
                implicitHeight: 28
                visible: !suppressed

                TrayAppIcon {
                    anchors.centerIn: parent
                    root: rootMod.root
                    item: modelData
                    size: trayDelegate.iconSize
                }

                TooltipMixin {
                    id: tip
                    root: rootMod.root
                    owner: trayDelegate
                    text: root.trayDisplayName(modelData) + "\nRight-click to hide"
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (modelData.hasMenu && root.popoutHover)
                            rootMod.showMenu(modelData, trayDelegate, false)
                        else
                            tip.show()
                    }
                    onExited: {
                        tip.hide()
                        if (modelData.hasMenu) root.popout.hoverLeave()
                    }
                    onClicked: function (mouse) {
                        tip.hide()
                        if (mouse.button === Qt.RightButton) {
                            if (root.trayMenuItem === modelData) root.trayMenuVisible = false
                            root.trayToggleHidden(modelData)
                        } else if (mouse.button === Qt.MiddleButton
                                   || (modelData.onlyMenu && modelData.hasMenu)) {
                            rootMod.showMenu(modelData, trayDelegate, true)
                        } else {
                            modelData.activate()
                        }
                    }
                }
            }
        }

        // the overflow: hidden apps, with a count
        Item {
            id: overflow
            visible: rootMod.hiddenCount > 0
            implicitWidth: root.trayCompact ? 22 : 28
            implicitHeight: 28

            IconText {
                anchors.centerIn: parent
                text: "more_horiz"
                color: overflowMa.containsMouse || root.trayVisible ? root.seal : root.ink
                font.pixelSize: root.trayCompact ? 14 : 18
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2
                width: Math.max(12, badge.implicitWidth + 6)
                height: 12
                radius: 6
                color: root.seal

                UiText {
                    id: badge
                    anchors.centerIn: parent
                    text: rootMod.hiddenCount
                    color: root.paper
                    font.family: root.mono
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }
            }

            TooltipMixin {
                id: overflowTip
                root: rootMod.root
                owner: overflow
                text: rootMod.hiddenCount + " hidden tray " + (rootMod.hiddenCount === 1 ? "app" : "apps")
                popout: "trayVisible"
            }

            MouseArea {
                id: overflowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    overflowTip.show()
                    root.popout.hoverOpen("trayVisible", overflow)
                }
                onExited: {
                    overflowTip.hide()
                    root.popout.hoverLeave()
                }
                onClicked: {
                    overflowTip.hide()
                    root.popout.noteItem("trayVisible", overflow)
                    root.popout.click("trayVisible")
                }
            }
        }
    }
}
