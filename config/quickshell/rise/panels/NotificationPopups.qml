import QtQuick
import "../modules"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

// Notification popups, stacked under the bar's right edge on the focused
// monitor. Hover pauses the timeout, click runs the default action, right
// click or ✕ dismisses. Only the cards take input; the rest of the window is
// click-through.
PanelWindow {
    id: popups
    required property var root
    readonly property var service: root.notifService

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property int maxShown: 4

    readonly property var shownKeys: service ? service.popups.slice(0, maxShown) : []

    function focusedScreen() {
        var monitor = Hyprland.focusedMonitor
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (monitor && Quickshell.screens[i].name === monitor.name) return Quickshell.screens[i]
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    // pick the monitor when a popup appears, not on every focus change, so a
    // visible stack doesn't jump between screens
    onShownKeysChanged: if (shownKeys.length > 0 && !visible) screen = focusedScreen()

    visible: shownKeys.length > 0
    color: "transparent"
    anchors.top: root.barPosition !== "bottom"
    anchors.bottom: root.barPosition === "bottom"
    anchors.right: true
    margins.top: barBottom + gap
    margins.bottom: barBottom + gap
    margins.right: 8
    implicitWidth: 360
    implicitHeight: Math.max(1, stack.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "dots-notification-popups"
    mask: Region { item: stack }

    function ago(t) {
        if (!(t > 0)) return ""
        var s = Math.round((Date.now() - t) / 1000)
        if (s < 45) return "now"
        if (s < 3600) return Math.round(s / 60) + "m"
        return Math.round(s / 3600) + "h"
    }

    function iconSource(entry) {
        var n = entry.notif
        var img = service.localImage(n ? n.image : entry.image)
        if (img) return img
        var icon = n ? n.appIcon : entry.appIcon
        if (!icon) return ""
        var local = service.localImage(icon)
        if (local) return local
        if (icon.indexOf(":") >= 0) return ""   // some other URL; never fetch it
        return Quickshell.iconPath(icon, true)
    }

    Column {
        id: stack
        width: parent.width
        spacing: 6

        Repeater {
            // ScriptModel diffs the key list, so existing cards (and their
            // countdowns) survive a new popup arriving above them
            model: ScriptModel { values: popups.shownKeys }

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var entry: popups.service.find(modelData)
                readonly property var notif: entry ? entry.notif : null
                readonly property bool critical: entry && (notif ? notif.urgency : entry.urgency) === NotificationUrgency.Critical
                readonly property var actions: notif ? notif.actions.filter(function(a) { return a.identifier !== "default" && a.text !== "" }) : []
                readonly property bool hasDefault: notif ? notif.actions.some(function(a) { return a.identifier === "default" }) : false

                width: stack.width
                height: entry ? body.implicitHeight + 20 : 0
                visible: entry !== null
                radius: root.pillRadius
                color: root.bg
                border.color: critical ? root.sealRaw : hover.hovered ? root.seal : root.pillBorder
                border.width: critical ? 1 : Math.max(1, root.pillBorderW)
                PillShadow { theme: root }

                // slide in from the right edge
                property real enter: 0
                Component.onCompleted: enter = 1
                Behavior on enter { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                opacity: enter
                transform: Translate { x: (1 - card.enter) * 40 }

                HoverHandler { id: hover }

                // countdown; hovering pauses it, finishing hides the popup
                readonly property int timeout: entry ? popups.service.popupTimeout(entry) : 0
                property real progress: 1
                NumberAnimation on progress {
                    from: 1; to: 0
                    duration: card.timeout
                    running: card.timeout > 0
                    paused: running && hover.hovered
                    onFinished: popups.service.hidePopup(card.modelData)
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: card.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton)
                            popups.service.dismiss(card.modelData)
                        else if (!popups.service.invokeDefault(card.modelData))
                            popups.service.hidePopup(card.modelData)
                    }
                }

                Row {
                    id: body
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 10

                    Rectangle {
                        id: iconBox
                        width: 38
                        height: 38
                        radius: root.tileRadius
                        color: root.fillIdle
                        clip: true
                        Image {
                            id: iconImg
                            anchors.fill: parent
                            anchors.margins: card.notif && card.notif.image ? 0 : 4
                            source: card.entry ? popups.iconSource(card.entry) : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 76
                            sourceSize.height: 76
                            asynchronous: true
                            smooth: true
                        }
                        IconText {
                            id: glyph
                            anchors.centerIn: parent
                            visible: iconImg.status !== Image.Ready
                            text: ""   // notifications
                            fill: 1
                            color: card.critical ? root.sealRaw : root.seal
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        width: body.width - iconBox.width - body.spacing
                        spacing: 3

                        Item {
                            width: parent.width
                            height: 14
                            UiText {
                                anchors.left: parent.left
                                anchors.right: closeX.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: (card.notif ? card.notif.appName : (card.entry ? card.entry.appName : "")) || "Notification"
                                color: root.sumiHi
                                font.family: root.mono
                                font.pixelSize: 10
                                font.letterSpacing: 0.5
                            }
                            UiText {
                                id: closeX
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✕"
                                color: xMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                                font.pixelSize: 10
                                MouseArea {
                                    id: xMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popups.service.dismiss(card.modelData)
                                }
                            }
                        }

                        UiText {
                            width: parent.width
                            visible: text !== ""
                            text: card.notif ? card.notif.summary : (card.entry ? card.entry.summary : "")
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: popups.service.safeBody(card.notif ? card.notif.body : (card.entry ? card.entry.body : ""))
                            textFormat: Text.StyledText
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.72)
                            linkColor: root.seal
                            font.family: root.mono
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            onLinkActivated: function(link) { popups.service.openLink(link) }
                        }

                        Flow {
                            width: parent.width
                            spacing: 6
                            topPadding: 4
                            visible: card.actions.length > 0

                            Repeater {
                                model: card.actions
                                delegate: Rectangle {
                                    required property var modelData
                                    width: Math.min(actionLabel.implicitWidth + 20, parent.width)
                                    height: 24
                                    radius: root.tileRadius
                                    color: actMa.containsMouse ? root.fillHover : root.fillIdle
                                    border.color: actMa.containsMouse ? root.seal : root.sep
                                    border.width: 1
                                    UiText {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        width: Math.min(implicitWidth, parent.width - 12)
                                        elide: Text.ElideRight
                                        text: modelData.text
                                        color: actMa.containsMouse ? root.seal : root.ink
                                        font.family: root.mono
                                        font.pixelSize: 10
                                    }
                                    MouseArea {
                                        id: actMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popups.service.invoke(card.modelData, modelData.identifier)
                                    }
                                }
                            }
                        }
                    }
                }

                // time left
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: card.radius
                    height: 2
                    radius: 1
                    color: card.critical ? root.sealRaw : root.seal
                    opacity: 0.5
                    visible: card.timeout > 0
                    width: (parent.width - 2 * card.radius) * card.progress
                }
            }
        }
    }
}
