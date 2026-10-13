import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Item {
    id: rootMod
    required property var root

    implicitWidth: trayRow.implicitWidth + (root.trayBackground ? 12 : 0)
    implicitHeight: 28
    visible: trayRow.implicitWidth > 0

    function showMenu(item, anchor) {
        if (!item || !item.hasMenu) return
        root.openTrayMenu(item.menu, root.trayDisplayName(item), item, anchor)
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

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (modelData.hasMenu)
                            rootMod.showMenu(modelData, trayDelegate)
                    }
                    onExited: if (modelData.hasMenu) root.popout.hoverLeave()
                    onClicked: {
                        if (modelData.onlyMenu && modelData.hasMenu)
                            rootMod.showMenu(modelData, trayDelegate)
                        else
                            modelData.activate()
                    }
                }
            }
        }
    }
}
