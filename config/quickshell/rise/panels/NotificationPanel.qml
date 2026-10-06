import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Notification centre, a right-hand sidebar. With the frame on it docks against
// the right frame edge between the bar and the bottom band, so its background
// melts out of the frame (FrameCard edge "right"); without it, it floats.
// Notifications are grouped by app (newest group first), each group collapsible
// and dismissable; entries keep click-to-open, per-item dismiss and actions.
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
    readonly property bool framed: root.frameOn
    // frame bands the sidebar sits between (the bar's side is the thick one)
    readonly property int topBand: root.barPosition === "bottom" ? (framed ? root.frameThickness : 0) : barBottom
    readonly property int bottomBand: root.barPosition === "bottom" ? barBottom : (framed ? root.frameThickness : 0)

    // history lives in NotificationService (theme.notifService); this panel only shows it
    readonly property var service: root.notifService
    readonly property var pending: service ? service.history : []
    readonly property int unreadCount: pending.length

    Binding { target: root; property: "notifCount"; value: notifPanel.unreadCount }

    function dismissOne(entry) { service.dismiss(entry.key) }
    function dismissAll() { service.clearAll() }
    function dismissGroup(group) {
        for (var i = 0; i < group.entries.length; i++) service.dismiss(group.entries[i].key)
    }
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
    // actions other than the default one (that's the click on the entry itself)
    function extraActions(entry) {
        if (!entry.notif) return []
        var out = [], acts = service.actionsOf(entry.key)
        for (var i = 0; i < acts.length; i++)
            if (acts[i].identifier !== "default" && acts[i].text) out.push(acts[i])
        return out
    }

    // history is newest-first, so first sight of an app orders the groups
    readonly property var groups: {
        var order = [], byApp = {}
        for (var i = 0; i < pending.length; i++) {
            var app = field(pending[i], "appName") || "App"
            if (!byApp[app]) { byApp[app] = { app: app, entries: [] }; order.push(byApp[app]) }
            byApp[app].entries.push(pending[i])
        }
        return order
    }
    property var collapsed: ({})
    function toggleGroup(app) {
        var next = {}
        for (var k in collapsed) next[k] = collapsed[k]
        next[app] = !next[app]
        collapsed = next
    }

    property real reveal: root.notifVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.notifVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001
    // a hover-opened panel must not steal the keyboard (games, editors…)
    WlrLayershell.keyboardFocus: root.notifVisible && !root.notifHoverOpened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // hover-opened: close once the pointer has left both the card and the frame
    // band beside it (where it came in from)
    Item {
        x: card.x + card.width
        y: card.y
        width: parent.width - x
        height: card.height
        HoverHandler { id: stripHover }
    }
    Timer {
        interval: 350
        running: root.notifHoverOpened && root.notifVisible && !cardHover.hovered && !stripHover.hovered
        onTriggered: root.notifVisible = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.notifVisible = false
    }

    FrameCard { root: notifPanel.root; card: card; reveal: notifPanel.reveal; edge: "right" }
    Rectangle {
        id: card
        width: 380
        x: parent.width - width - (notifPanel.framed ? root.frameThickness : notifPanel.gap)
        y: notifPanel.topBand + (notifPanel.framed ? 0 : notifPanel.gap)
        height: parent.height - notifPanel.topBand - notifPanel.bottomBand
                - (notifPanel.framed ? 0 : 2 * notifPanel.gap)
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW
        PillShadow { theme: root ; visible: root.styleShadow && !root.frameOn }

        // content slides in from the frame edge as the blob grows out of it
        opacity: notifPanel.reveal
        transform: Translate { x: (1 - notifPanel.reveal) * 56 }
        focus: root.notifVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.notifVisible = false
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }
        // on the card itself (a parent of its content), so hover over buttons counts
        HoverHandler { id: cardHover }

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: 14

            // ── header ──
            Item {
                id: header
                width: parent.width
                height: 26
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

            Rectangle { id: headerSep; anchors.top: header.bottom; anchors.topMargin: 8; width: parent.width; height: 1; color: root.sep }

            // ── grouped list ──
            Flickable {
                anchors { top: headerSep.bottom; topMargin: 10; bottom: clearAll.top; bottomMargin: 10 }
                width: parent.width
                contentHeight: groupsCol.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: groupsCol
                    width: parent.width
                    spacing: 12

                    Repeater {
                        model: notifPanel.groups

                        delegate: Column {
                            id: groupCol
                            required property var modelData
                            readonly property bool folded: notifPanel.collapsed[modelData.app] === true
                            width: groupsCol.width
                            spacing: 6

                            // group header: app · count, fold, dismiss group
                            Item {
                                width: parent.width
                                height: 20
                                UiText {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: groupCol.modelData.app + "  ·  " + groupCol.modelData.entries.length
                                    color: groupMa.containsMouse ? root.seal : root.sumiHi
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    font.letterSpacing: 1
                                    Behavior on color { CAnim { ms: 120 } }
                                }
                                UiText {
                                    anchors.right: groupX.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: groupCol.folded ? "▸" : "▾"
                                    color: root.sumi
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    id: groupMa
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: groupX.left }
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notifPanel.toggleGroup(groupCol.modelData.app)
                                }
                                UiText {
                                    id: groupX
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✕"
                                    color: groupXMa.containsMouse ? root.seal : root.sumi
                                    font.pixelSize: 10
                                    MouseArea {
                                        id: groupXMa
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notifPanel.dismissGroup(groupCol.modelData)
                                    }
                                }
                            }

                            Repeater {
                                model: groupCol.folded ? [] : groupCol.modelData.entries

                                delegate: Rectangle {
                                    id: entry
                                    required property var modelData
                                    readonly property var actions: notifPanel.extraActions(modelData)
                                    width: groupCol.width
                                    height: entryCol.implicitHeight + 18
                                    radius: root.tileRadius
                                    color: entryMa.containsMouse ? root.fillHover : root.fillIdle
                                    border.color: entryMa.containsMouse ? root.seal : root.sep
                                    border.width: 1
                                    Behavior on color { CAnim { ms: 120 } }

                                    // click body → run the notification's default action
                                    MouseArea {
                                        id: entryMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notifPanel.openNotification(entry.modelData)
                                    }

                                    Column {
                                        id: entryCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top }
                                        anchors.margins: 9
                                        anchors.rightMargin: 28   // leave room for the ✕
                                        spacing: 4

                                        UiText {
                                            text: notifPanel.field(entry.modelData, "summary") || ""
                                            color: root.ink
                                            font.family: root.mono
                                            font.pixelSize: 11
                                            width: parent.width
                                            elide: Text.ElideRight
                                            visible: text !== ""
                                        }
                                        UiText {
                                            text: notifPanel.service.safeBody(notifPanel.field(entry.modelData, "body"))
                                            textFormat: Text.StyledText
                                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.8)
                                            font.family: root.mono
                                            font.pixelSize: 10
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                            visible: text !== ""
                                        }
                                        // action buttons (above the body MouseArea so they get the click)
                                        Flow {
                                            width: parent.width
                                            spacing: 6
                                            visible: entry.actions.length > 0
                                            z: 1
                                            Repeater {
                                                model: entry.actions
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    width: actLabel.implicitWidth + 16
                                                    height: 22
                                                    radius: 11
                                                    color: actMa.containsMouse ? root.fillActive : root.fillHover
                                                    Behavior on color { CAnim { ms: 120 } }
                                                    UiText {
                                                        id: actLabel
                                                        anchors.centerIn: parent
                                                        text: parent.modelData.text
                                                        color: root.ink
                                                        font.family: root.mono
                                                        font.pixelSize: 10
                                                    }
                                                    MouseArea {
                                                        id: actMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: notifPanel.service.invoke(entry.modelData.key, parent.modelData.identifier)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    UiText {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        text: notifPanel.ago(entry.modelData.time)
                                        color: root.sumi
                                        font.family: root.mono
                                        font.pixelSize: 9
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
                                            color: xMa.containsMouse ? root.seal : root.sumi
                                            font.pixelSize: 10
                                        }
                                        MouseArea {
                                            id: xMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notifPanel.dismissOne(entry.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiText {
                        visible: notifPanel.pending.length === 0
                        width: groupsCol.width
                        topPadding: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: "No notifications"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                }
            }

            // ── clear all ──
            Rectangle {
                id: clearAll
                anchors.bottom: parent.bottom
                width: parent.width
                height: notifPanel.pending.length > 0 ? 30 : 0
                visible: height > 0
                radius: root.tileRadius
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
