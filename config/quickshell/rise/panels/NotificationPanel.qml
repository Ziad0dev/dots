import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: notifPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-notifications"

    readonly property int barBottom: 35
    readonly property int gap: 8

    // history lives in NotificationService (theme.notifService); this panel only shows it
    readonly property var service: root.notifService
    readonly property var pending: service ? service.history : []
    readonly property int unreadCount: pending.length
    // scrollable list height cap, clamped to the monitor
    readonly property int listCap: Math.max(120, Math.min(420, notifPanel.height - 220))

    Binding { target: root; property: "notifCount"; value: notifPanel.unreadCount }

    function dismissOne(entry) { service.dismiss(entry.key) }
    function dismissAll() { service.clearAll() }
    function openNotification(entry) {
        service.invokeDefault(entry.key)
        root.notifVisible = false
    }
    function field(entry, name) { return entry.notif ? entry.notif[name] : entry[name] }
    function ago(t) {
        if (!(t > 0)) return ""
        var s = Math.round((Date.now() - t) / 1000)
        if (s < 45) return "now"
        if (s < 3600) return Math.round(s / 60) + "m"
        if (s < 86400) return Math.round(s / 3600) + "h"
        return Math.round(s / 86400) + "d"
    }

    property real reveal: root.notifVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.notifVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.notifVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.notifVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.cardBg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        // under the bar's bell when it was clicked; right edge when opened by key/IPC
        x: root.notifBarX > 0 ? Math.round(Math.max(6, Math.min(root.notifBarX, parent.width - width - 6)))
                              : parent.width - width - 8
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: notifPanel.reveal
        transformOrigin: root.barPosition === "bottom" ? Item.Bottom : Item.Top
        scale: root.motionHover ? (0.92 + 0.08 * notifPanel.reveal) : 1
        focus: root.notifVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.notifVisible = false
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: notifPanel.unreadCount > 0 ? "Notifications · " + notifPanel.unreadCount : "Notifications"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
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
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notifVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── notification list (scrollable; each individually dismissable) ──
            Flickable {
                width: parent.width
                height: Math.min(listCol.implicitHeight, notifPanel.listCap)
                contentHeight: listCol.implicitHeight
                clip: true
                interactive: listCol.implicitHeight > notifPanel.listCap
                boundsBehavior: Flickable.StopAtBounds   // no overshoot/rebound at the top/bottom edge
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: listCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: notifPanel.pending

                        delegate: Rectangle {
                            required property var modelData
                            width: listCol.width
                            height: entryCol.implicitHeight + 16
                            radius: root.tileRadius
                            color: entryMa.containsMouse ? root.fillHover : root.fillIdle
                            border.color: entryMa.containsMouse ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { CAnim { ms: 120 } }

                            Column {
                                id: entryCol
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                anchors.margins: 8
                                anchors.topMargin: 8
                                anchors.rightMargin: 26   // leave room for the ✕
                                spacing: 3

                                UiText {
                                    text: (notifPanel.field(modelData, "appName") || "App")
                                        + (modelData.time > 0 ? "  ·  " + notifPanel.ago(modelData.time) : "")
                                    color: root.sumiHi
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    font.letterSpacing: 0.5
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                UiText {
                                    text: notifPanel.field(modelData, "summary") || ""
                                    color: root.ink
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                                UiText {
                                    text: notifPanel.service.safeBody(notifPanel.field(modelData, "body"))
                                    textFormat: Text.StyledText
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }

                            // click body → run the notification's default action
                            MouseArea {
                                id: entryMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notifPanel.openNotification(modelData)
                            }

                            // per-item dismiss ✕ (on top, top-right corner)
                            Rectangle {
                                anchors.top: parent.top; anchors.right: parent.right
                                anchors.topMargin: 4; anchors.rightMargin: 4
                                width: 18; height: 18; radius: 9
                                color: "transparent"
                                UiText {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: xMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    id: xMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notifPanel.dismissOne(modelData)
                                }
                            }
                        }
                    }

                    UiText {
                        visible: notifPanel.pending.length === 0
                        width: listCol.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No notifications"
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                }
            }

            // ── clear all ──
            Rectangle {
                width: parent.width
                height: 28; radius: root.tileRadius
                visible: notifPanel.pending.length > 0
                readonly property bool hovered: clearMa.containsMouse
                color: hovered ? root.fillHover : root.fillIdle
                border.color: hovered ? root.seal : root.sep
                border.width: 1
                Behavior on color { CAnim { ms: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: clearMa.containsMouse ? root.seal : root.sumi
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notifPanel.dismissAll()
                }
            }
        }
    }
}
