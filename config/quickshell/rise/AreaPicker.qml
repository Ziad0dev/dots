pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "modules"

// Screenshot area picker, after Caelestia's (modules/areapicker): every screen
// freezes, the window under the pointer is offered (the selection glides to
// it), a drag picks any region, Escape cancels. The pick is cut from the
// frozen frame and handed to `dots-shot import`, which files it, copies it
// and posts the Open / Edit notification like every other shot.
// `dots-shot region` (Print) opens it over IPC and falls back to slurp when
// Rise isn't running.
Scope {
    id: picker
    required property var root

    property bool open: false
    property bool busy: false        // saving: one shot per opening

    function close() { picker.open = false; picker.busy = false }

    IpcHandler {
        target: "areapicker"
        function open(): bool {
            if (picker.open) return true
            // window positions are only as fresh as the last refresh
            Hyprland.refreshToplevels()
            Hyprland.refreshMonitors()
            picker.busy = false
            picker.open = true
            return true
        }
        function close(): void { picker.close() }
    }

    LazyLoader {
        active: picker.open

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win
                required property ShellScreen modelData
                screen: modelData
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "dots-areapicker"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                // the windows on this screen's workspace, topmost kinds first
                // (pinned, fullscreen, floating): the first under the pointer wins
                readonly property var clients: {
                    const mon = Hyprland.monitorFor(win.modelData)
                    const ws = mon ? mon.activeWorkspace : null
                    const list = ws && ws.toplevels ? ws.toplevels.values.slice() : []
                    return list.sort(function (a, b) {
                        const ac = a.lastIpcObject || {}, bc = b.lastIpcObject || {}
                        return ((bc.pinned ? 1 : 0) - (ac.pinned ? 1 : 0))
                            || (((bc.fullscreen || 0) !== 0) - ((ac.fullscreen || 0) !== 0))
                            || ((bc.floating ? 1 : 0) - (ac.floating ? 1 : 0))
                    })
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                    focus: true
                    Keys.onEscapePressed: picker.close()

                    property bool onClient: false
                    property real ssx: 0
                    property real ssy: 0
                    property real sx: width / 2 - 120
                    property real sy: height / 2 - 80
                    property real ex: width / 2 + 120
                    property real ey: height / 2 + 80
                    property real rsx: Math.min(sx, ex)
                    property real rsy: Math.min(sy, ey)
                    property real sw: Math.abs(sx - ex)
                    property real sh: Math.abs(sy - ey)
                    // until the pointer moves here, this screen offers nothing
                    property bool engaged: false

                    // glide between windows; follow the pointer exactly while dragging
                    Behavior on rsx { enabled: !area.pressed; Anim { kind: "spatialFast" } }
                    Behavior on rsy { enabled: !area.pressed; Anim { kind: "spatialFast" } }
                    Behavior on sw { enabled: !area.pressed; Anim { kind: "spatialFast" } }
                    Behavior on sh { enabled: !area.pressed; Anim { kind: "spatialFast" } }

                    function snapTo(x, y) {
                        for (const c of win.clients) {
                            const ipc = c ? c.lastIpcObject : null
                            if (!ipc || !ipc.at || !ipc.size) continue
                            const cx = ipc.at[0] - win.modelData.x, cy = ipc.at[1] - win.modelData.y
                            if (x >= cx && y >= cy && x <= cx + ipc.size[0] && y <= cy + ipc.size[1]) {
                                onClient = true
                                sx = cx; sy = cy; ex = cx + ipc.size[0]; ey = cy + ipc.size[1]
                                return
                            }
                        }
                        // no window there: the whole screen
                        onClient = false
                        sx = 0; sy = 0; ex = width; ey = height
                    }

                    onPositionChanged: function (e) {
                        engaged = true
                        if (pressed) {
                            onClient = false
                            sx = ssx; sy = ssy; ex = e.x; ey = e.y
                        } else {
                            snapTo(e.x, e.y)
                        }
                    }
                    onPressed: function (e) { engaged = true; ssx = e.x; ssy = e.y }
                    onReleased: function (e) {
                        // a click without a drag takes what's offered (window or screen)
                        if (Math.abs(e.x - ssx) < 4 && Math.abs(e.y - ssy) < 4)
                            snapTo(e.x, e.y)
                        save()
                    }

                    function save() {
                        if (picker.busy || sw < 2 || sh < 2) return
                        picker.busy = true
                        const dpr = win.modelData.devicePixelRatio || 1
                        const dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
                        const file = dir + "/rise-shot-" + Quickshell.processId + "-" + Date.now() + ".png"
                        crop.grabToImage(function (result) {
                            if (result.saveToFile(file))
                                Quickshell.execDetached(["dots-shot", "import", file])
                            picker.close()
                        }, Qt.size(Math.round(sw * dpr), Math.round(sh * dpr)))
                    }

                    // the frame as it was when the picker opened
                    ScreencopyView {
                        id: frozen
                        anchors.fill: parent
                        captureSource: win.modelData
                        live: false
                    }

                    // the pick, cut from the frozen frame for saving (off to the
                    // side: grabbed, never seen)
                    ShaderEffectSource {
                        id: crop
                        x: -width - 10
                        width: Math.max(1, area.sw)
                        height: Math.max(1, area.sh)
                        sourceItem: frozen
                        sourceRect: Qt.rect(area.rsx, area.rsy, area.sw, area.sh)
                        live: true
                    }

                    // dimmed everywhere but the pick
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, area.engaged ? 0.45 : 0.3)
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskInverted: true
                            maskSource: hole
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 0.02
                        }
                    }
                    Item {
                        id: hole
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            visible: area.engaged
                            x: area.rsx; y: area.rsy; width: area.sw; height: area.sh
                        }
                    }

                    Rectangle {
                        visible: area.engaged
                        x: area.rsx - 1; y: area.rsy - 1
                        width: area.sw + 2; height: area.sh + 2
                        color: "transparent"
                        border.width: 2
                        border.color: picker.root.seal
                    }

                    // size readout, inside the pick's top-left corner
                    Rectangle {
                        visible: area.engaged && area.sw > 60 && area.sh > 24
                        x: area.rsx + 6; y: area.rsy + 6
                        width: sizeText.implicitWidth + 12; height: sizeText.implicitHeight + 6
                        radius: 4
                        color: Qt.rgba(0, 0, 0, 0.6)
                        UiText {
                            id: sizeText
                            anchors.centerIn: parent
                            text: Math.round(area.sw * (win.modelData.devicePixelRatio || 1)) + " × "
                                + Math.round(area.sh * (win.modelData.devicePixelRatio || 1))
                            color: "white"
                            font.family: picker.root.mono
                            font.pixelSize: 11
                        }
                    }

                    // where the pointer already is: offer that window straight away
                    Process {
                        running: true
                        command: ["hyprctl", "cursorpos", "-j"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                try {
                                    const p = JSON.parse(this.text)
                                    const x = p.x - win.modelData.x, y = p.y - win.modelData.y
                                    if (x >= 0 && y >= 0 && x < area.width && y < area.height) {
                                        area.engaged = true
                                        area.snapTo(x, y)
                                    }
                                } catch (e) {}
                            }
                        }
                    }
                }
            }
        }
    }
}
