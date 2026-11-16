import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

// Session menu (SUPER+SHIFT+Escape, `ipc call session toggle`, launcher "> shut
// down", dashboard Power): lock, suspend, log out, restart, shut down. Docked on
// the right frame edge at mid-height and grown out of it (FrameCard "right").
// Log out / restart / shut down arm on the first press and run on a second press
// within 4s, so a stray click or Enter can't end the session. Never hover-opened.
PanelWindow {
    id: session
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-session"
    WlrLayershell.keyboardFocus: root.sessionVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var items: [
        { id: "lock",     label: "Lock",      glyph: "", confirm: false, cmd: ["loginctl", "lock-session"] },
        { id: "suspend",  label: "Suspend",   glyph: "", confirm: false, cmd: ["systemctl", "suspend"] },
        { id: "logout",   label: "Log out",   glyph: "", confirm: true,  cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { id: "reboot",   label: "Restart",   glyph: "", confirm: true,  cmd: ["systemctl", "reboot"] },
        { id: "poweroff", label: "Shut down", glyph: "", confirm: true,  cmd: ["systemctl", "poweroff"] }
    ]
    property int sel: 0
    property string armed: ""            // id waiting for its confirming second press
    Timer { id: disarm; interval: 4000; onTriggered: session.armed = "" }

    function activate(i) {
        var it = items[i]
        if (!it) return
        if (it.confirm && armed !== it.id) {
            armed = it.id
            disarm.restart()
            return
        }
        armed = ""
        root.sessionVisible = false
        Quickshell.execDetached(it.cmd)
    }

    // loaded on open (VariantRoot): start closed so the reveal animates
    property bool loaded: false
    Component.onCompleted: loaded = true
    property real reveal: loaded && root.sessionVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.sessionVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001
    onVisibleChanged: if (visible) { sel = 0; armed = "" }

    MouseArea {
        anchors.fill: parent
        onClicked: root.sessionVisible = false
    }

    FrameCard { root: session.root; card: card; reveal: session.reveal; edge: "right" }
    Rectangle {
        id: card
        width: 120
        height: col.implicitHeight + 28
        x: parent.width - width - (root.frameOn ? root.frameThickness : 8)
        y: Math.round((parent.height - height) / 2)
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW
        PillShadow { theme: root ; visible: root.styleShadow && !root.frameOn }

        opacity: session.reveal
        transform: Translate { x: (1 - session.reveal) * 48 }
        focus: root.sessionVisible
        Keys.onPressed: function (e) {
            if (e.key === Qt.Key_Escape) { root.sessionVisible = false; e.accepted = true }
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_J || e.key === Qt.Key_Tab) { session.sel = (session.sel + 1) % session.items.length; e.accepted = true }
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_K) { session.sel = (session.sel + session.items.length - 1) % session.items.length; e.accepted = true }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { session.activate(session.sel); e.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: session.items
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool current: index === session.sel
                    readonly property bool isArmed: session.armed === modelData.id
                    width: 92
                    height: 80
                    radius: 22
                    color: isArmed ? Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.35)
                         : current ? root.fillActive : btnMa.containsMouse ? root.fillHover : root.fillIdle
                    border.color: isArmed ? root.sealRaw : current ? root.seal : root.sep
                    border.width: current || isArmed ? 2 : 1
                    Behavior on color { CAnim { ms: 160 } }
                    scale: btnMa.pressed ? 0.94 : current ? 1.04 : 1
                    Behavior on scale { Anim { kind: "spatialFast" } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 5
                        IconText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.modelData.glyph
                            fill: btn.current || btn.isArmed ? 1 : 0
                            color: btn.isArmed ? root.sealRaw : btn.current ? root.seal : root.ink
                            font.pixelSize: 28
                        }
                        UiText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.isArmed ? "again to " + btn.modelData.label.toLowerCase() : btn.modelData.label
                            color: btn.isArmed ? root.ink : root.sumi
                            font.family: root.mono
                            font.pixelSize: btn.isArmed ? 9 : 10
                        }
                    }
                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: session.sel = btn.index
                        onClicked: session.activate(btn.index)
                    }
                }
            }
        }
    }
}
