import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../modules"
import "dash"

// Window info (SUPER+SHIFT+I, `ipc call windowinfo toggle`), after Caelestia's:
// a still preview of the focused window, its details, and actions on it.
// The window is pinned when the panel opens (by address), so the actions keep
// targeting it while the panel has focus. The preview is one capture, not live,
// so an open panel costs no ongoing GPU. Kill (SIGKILL) arms on the first press
// and runs on a second press within 4s. Grows out of the bar.
PanelWindow {
    id: wi
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-windowinfo"
    WlrLayershell.keyboardFocus: root.windowInfoVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    M3Palette { id: m3; root: wi.root }

    // ── the window, pinned on open ──
    property var info: null                 // hyprctl activewindow -j
    property var toplevel: null             // its Wayland toplevel, for the preview
    readonly property string addr: info ? String(info.address || "") : ""
    readonly property string selector: "address:" + addr
    Process {
        id: infoProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var o = null
                try { o = JSON.parse(String(this.text || "")) } catch (e) { }
                wi.info = o && o.address ? o : null
                wi.toplevel = null
                if (!wi.info) return
                var want = wi.addr.replace(/^0x/, "").toLowerCase()
                var tls = Hyprland.toplevels.values
                for (var i = 0; i < tls.length; i++)
                    if (String(tls[i].address || "").replace(/^0x/, "").toLowerCase() === want) { wi.toplevel = tls[i].wayland; break }
            }
        }
    }
    function refresh() { infoProc.running = false; infoProc.running = true }

    // Lua dispatch on the pinned window; most actions refresh the details after
    function act(lua, close) {
        if (!info) return
        Quickshell.execDetached(["hyprctl", "dispatch", lua])
        if (close) root.windowInfoVisible = false
        else refreshSoon.restart()
    }
    Timer { id: refreshSoon; interval: 150; onTriggered: wi.refresh() }
    function dsp(name, extra) { return "hl.dsp.window." + name + "({ window = \"" + selector + "\"" + (extra ? ", " + extra : "") + " })" }

    property bool killArmed: false
    Timer { id: disarm; interval: 4000; onTriggered: wi.killArmed = false }

    // loaded on open (VariantRoot): start closed so the reveal animates
    property bool loaded: false
    Component.onCompleted: { loaded = true; refresh() }
    property real reveal: loaded && root.windowInfoVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.windowInfoVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001
    onVisibleChanged: if (visible) { killArmed = false; refresh() }

    MouseArea {
        anchors.fill: parent
        onClicked: root.windowInfoVisible = false
    }

    FrameCard { root: wi.root; card: card; reveal: wi.reveal; edge: "bar" }
    Rectangle {
        id: card
        readonly property int pad: 16
        width: body.implicitWidth + 2 * pad
        height: body.implicitHeight + 2 * pad
        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom" ? parent.height - height - 35 : 35
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW
        PillShadow { theme: root; visible: root.styleShadow && !root.frameOn }

        opacity: wi.reveal
        transform: Translate { y: (root.barPosition === "bottom" ? 1 : -1) * (1 - wi.reveal) * 40 }
        focus: root.windowInfoVisible
        Keys.onPressed: function (e) {
            if (e.key === Qt.Key_Escape) { root.windowInfoVisible = false; e.accepted = true }
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) { wi.act(wi.dsp("move", "workspace = " + (e.key - Qt.Key_0)), false); e.accepted = true }
            else if (e.key === Qt.Key_F) { wi.act(wi.dsp("float", "action = \"toggle\""), false); e.accepted = true }
            else if (e.key === Qt.Key_P) { wi.act(wi.dsp("pin", "action = \"toggle\""), false); e.accepted = true }
            else if (e.key === Qt.Key_Q) { wi.act(wi.dsp("close"), true); e.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: body
            x: card.pad; y: card.pad
            spacing: 12

            // nothing focused
            Item {
                visible: !wi.info
                width: 420; height: 160
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText { anchors.horizontalCenter: parent.horizontalCenter; text: "select_window_off"; color: m3.onSurfaceVariant; font.pointSize: 36 }
                    DText { anchors.horizontalCenter: parent.horizontalCenter; text: "No focused window"; color: m3.onSurface; font.pointSize: 16; font.weight: Font.Medium }
                }
            }

            Row {
                visible: !!wi.info
                spacing: 12

                // ── preview ──
                Rectangle {
                    id: previewBox
                    width: 380; height: 250
                    radius: 22
                    color: m3.surfaceContainer
                    clip: true
                    ScreencopyView {
                        id: shot
                        anchors.centerIn: parent
                        readonly property real ar: sourceSize.width > 0 ? sourceSize.width / sourceSize.height : 16 / 10
                        width: Math.min(parent.width - 16, (parent.height - 16) * ar)
                        height: width / ar
                        captureSource: wi.visible ? wi.toplevel : null
                        live: false
                    }
                    IconText {
                        anchors.centerIn: parent
                        visible: !shot.hasContent
                        text: "select_window"
                        color: m3.onSurfaceVariant
                        font.pointSize: 40
                    }
                }

                // ── details ──
                Rectangle {
                    width: 330; height: previewBox.height
                    radius: 22
                    color: m3.surfaceContainer
                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 2
                        DText {
                            width: parent.width
                            text: wi.info ? (wi.info.title || "Untitled") : ""
                            color: m3.primary
                            font.pointSize: 14; font.weight: Font.Medium
                        }
                        DText {
                            width: parent.width
                            bottomPadding: 8
                            text: wi.info ? (wi.info.class || wi.info.initialClass || "") : ""
                            color: m3.onSurfaceVariant
                        }
                        Repeater {
                            model: !wi.info ? [] : [
                                { icon: "workspaces", k: "Workspace", v: (wi.info.workspace && wi.info.workspace.name) || "" },
                                { icon: "aspect_ratio", k: "Size", v: wi.info.size ? wi.info.size[0] + " × " + wi.info.size[1] : "" },
                                { icon: "open_with", k: "Position", v: wi.info.at ? wi.info.at[0] + ", " + wi.info.at[1] : "" },
                                { icon: "tag", k: "PID", v: String(wi.info.pid) },
                                { icon: "layers", k: "State", v: [wi.info.floating ? "floating" : "tiled", wi.info.pinned ? "pinned" : "",
                                                                   wi.info.fullscreen ? "fullscreen" : "", wi.info.xwayland ? "XWayland" : "Wayland",
                                                                   wi.info.grouped && wi.info.grouped.length > 0 ? "group of " + wi.info.grouped.length : ""]
                                                                  .filter(function (x) { return x }).join(" · ") }
                            ]
                            delegate: Row {
                                required property var modelData
                                spacing: 10
                                height: 26
                                IconText { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.icon; color: m3.secondary; font.pointSize: 13 }
                                DText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 70
                                    text: parent.modelData.k
                                    color: m3.onSurfaceVariant
                                    font.pointSize: 10
                                }
                                DText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 200
                                    text: parent.modelData.v
                                    color: m3.onSurface
                                    font.pointSize: 11
                                }
                            }
                        }
                    }
                }
            }

            // ── move to workspace ──
            Row {
                visible: !!wi.info
                spacing: 4
                DText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 74
                    text: "Move to"
                    color: m3.onSurfaceVariant
                    font.pointSize: 10
                }
                Repeater {
                    model: 10
                    delegate: DButton {
                        required property int index
                        readonly property int ws: index + 1
                        dash: m3
                        width: 54; height: 36
                        icon: ""
                        label: String(ws)
                        checked: !!wi.info && wi.info.workspace && wi.info.workspace.id === ws
                        onClicked: wi.act(wi.dsp("move", "workspace = " + ws), false)
                    }
                }
            }

            // ── actions ──
            Row {
                visible: !!wi.info
                spacing: 6
                DButton {
                    dash: m3; icon: "picture_in_picture"; label: wi.info && wi.info.floating ? "Tile" : "Float"
                    onClicked: wi.act(wi.dsp("float", "action = \"toggle\""), false)
                }
                DButton {
                    dash: m3; icon: "push_pin"; label: wi.info && wi.info.pinned ? "Unpin" : "Pin"
                    checked: !!wi.info && wi.info.pinned
                    active: !!wi.info && wi.info.floating
                    onClicked: wi.act(wi.dsp("pin", "action = \"toggle\""), false)
                }
                DButton {
                    dash: m3; icon: "fullscreen"; label: "Fullscreen"
                    onClicked: wi.act(wi.dsp("fullscreen"), true)
                }
                DButton {
                    dash: m3; icon: "center_focus_strong"; label: "Center"
                    active: !!wi.info && wi.info.floating
                    onClicked: wi.act(wi.dsp("center"), false)
                }
                DButton {
                    dash: m3; icon: "close"; label: "Close"
                    onClicked: wi.act(wi.dsp("close"), true)
                }
                DButton {
                    dash: m3; icon: "skull"
                    label: wi.killArmed ? "Again to kill" : "Kill"
                    filled: wi.killArmed
                    onClicked: {
                        if (!wi.killArmed) { wi.killArmed = true; disarm.restart(); return }
                        wi.killArmed = false
                        wi.act(wi.dsp("kill"), true)
                    }
                }
            }
        }
    }
}
