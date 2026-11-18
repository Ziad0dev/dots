import QtQuick
import Quickshell.Io
import Quickshell

Item {
    id: rootMod
    required property var root

    readonly property string tooltipText: root.notifCount > 0
        ? (root.notifCount + (root.notifCount === 1 ? " notification" : " notifications"))
        : "No notifications"

    implicitWidth: 26
    implicitHeight: 28

    IconText {
        id: bellIcon
        anchors.centerIn: parent
        text: "\uE7F4"   // notifications (bell)
        font.pixelSize: 15
        color: root.notifCount > 0
            ? root.seal
            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
        Behavior on color { CAnim { ms: 150 } }
    }

    // count badge — top-right, theme red with high-contrast text
    Rectangle {
        visible: root.notifCount > 0
        width: Math.max(12, badgeTxt.implicitWidth + 6)
        height: 12
        radius: 6
        color: root.seal
        anchors {
            verticalCenter: bellIcon.verticalCenter; verticalCenterOffset: -6
            horizontalCenter: bellIcon.horizontalCenter; horizontalCenterOffset: 7
        }
        Text {
            id: badgeTxt
            anchors.centerIn: parent
            text: root.notifCount > 99 ? "99" : root.notifCount
            color: root.paper
            font.family: root.mono
            font.pixelSize: 7
            font.weight: Font.Bold
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    // the same toggle as NotificationSilenceWidget
    Process {
        id: dndProc
        command: ["bash", "-c", "if command -v dots-toggle-notification-silencing >/dev/null 2>&1; then exec dots-toggle-notification-silencing; fi; exec dots toggle notification silencing"]
        onExited: root.refreshStatusIndicators()
    }

    // left: the notification centre; right: Do Not Disturb; middle: clear all
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) { dndProc.running = false; dndProc.running = true }
            else if (e.button === Qt.MiddleButton) { if (root.notifService) root.notifService.clearAll() }
            else root.notifVisible = !root.notifVisible
        }
    }
}
