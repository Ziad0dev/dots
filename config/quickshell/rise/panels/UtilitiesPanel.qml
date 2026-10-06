import QtQuick
import "../modules"
import "../IconMap.js" as IconMap
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Utilities corner (SUPER+U, `qs -c rise ipc call utilities toggle`): quick
// toggles and the latest screenshots. With the frame on it docks in the
// bottom-right corner and grows up out of the bottom band (FrameCard edge
// "bottom"), touching the right band too, so it melts out of the corner.
// Every toggle runs the same command as its bar widget.
PanelWindow {
    id: utilPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-utilities"

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property bool framed: root.frameOn
    readonly property int bottomBand: root.barPosition === "bottom" ? barBottom : (framed ? root.frameThickness : 0)
    readonly property int rightBand: framed ? root.frameThickness : 0

    // live state read when the panel opens ("na" = no such device here)
    property string wifi: "na"
    property string bluetooth: "na"
    property bool nightLight: false
    property var shots: []

    readonly property string stateScript:
        "w=na; if rfkill list wifi 2>/dev/null | grep -q .; then " +
        "  rfkill list wifi | grep -qi 'Soft blocked: yes' && w=0 || w=1; fi; " +
        "b=na; s=$(timeout 2 bluetoothctl show 2>/dev/null); if [ -n \"$s\" ]; then " +
        "  printf '%s' \"$s\" | grep -q 'Powered: yes' && b=1 || b=0; fi; " +
        "n=0; [ -e \"${XDG_STATE_HOME:-$HOME/.local/state}/dots/indicators/nightlight\" ] && n=1; " +
        "printf 'wifi=%s\\nbt=%s\\nnl=%s\\n' \"$w\" \"$b\" \"$n\"; " +
        "D=\"${DOTS_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$(xdg-user-dir PICTURES 2>/dev/null)}}\"; " +
        "case \"$D\" in \"\"|\"$HOME\") D=\"$HOME/Pictures\";; esac; " +
        "find \"$D\" -maxdepth 1 -type f -iname 'screenshot-*.png' -printf '%T@\\t%p\\n' 2>/dev/null " +
        "| sort -rn | head -4 | cut -f2- | sed 's/^/shot=/'"

    function refresh() { stateProc.running = false; stateProc.running = true }
    // detached, so closing the panel (it unloads) can't kill a toggle mid-way;
    // the state is re-read once it has had time to land
    function run(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd])
        stateRefresh.restart()
    }

    Process {
        id: stateProc
        command: ["bash", "-c", utilPanel.stateScript]
        stdout: StdioCollector {
            onStreamFinished: {
                var shots = []
                var lines = String(this.text || "").split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i], eq = l.indexOf("=")
                    if (eq < 0) continue
                    var k = l.slice(0, eq), v = l.slice(eq + 1)
                    if (k === "wifi") utilPanel.wifi = v
                    else if (k === "bt") utilPanel.bluetooth = v
                    else if (k === "nl") utilPanel.nightLight = v === "1"
                    else if (k === "shot" && v !== "") shots.push(v)
                }
                utilPanel.shots = shots
            }
        }
    }
    Timer {
        id: stateRefresh
        interval: 700
        onTriggered: {
            utilPanel.refresh()
            root.refreshStatusIndicators()
            root.refreshRecordingStatus()
        }
    }

    readonly property var tiles: [
        { id: "wifi", label: "Wi-Fi", glyph: "", shown: wifi !== "na", on: wifi === "1",
          cmd: wifi === "1" ? "rfkill block wifi" : "rfkill unblock wifi" },
        { id: "bt", label: "Bluetooth", glyph: IconMap.icon("bluetooth"), shown: bluetooth !== "na", on: bluetooth === "1",
          cmd: "bluetoothctl power " + (bluetooth === "1" ? "off" : "on") },
        { id: "dnd", label: "Silence", glyph: "", shown: true, on: root.notifSilenced,
          cmd: "if command -v dots-toggle-notification-silencing >/dev/null 2>&1; then exec dots-toggle-notification-silencing; fi; exec dots toggle notification silencing" },
        { id: "awake", label: "Stay awake", glyph: "", shown: true, on: root.stayAwake,
          cmd: "if command -v dots-toggle-idle >/dev/null 2>&1; then exec dots-toggle-idle; fi; exec dots toggle idle" },
        { id: "inhibit", label: "Caffeine", glyph: "", shown: true, on: root.idleInhibited, cmd: "" },
        { id: "night", label: "Night light", glyph: "", shown: true, on: nightLight, cmd: "dots-nightlight toggle" },
        { id: "rec", label: root.screenRecording ? "Stop rec" : "Record", glyph: "", shown: true, on: root.screenRecording,
          cmd: root.screenRecording ? "dots-capture-screenrecording --stop" : "dots-capture-screenrecording" }
    ]
    readonly property var shownTiles: tiles.filter(function (t) { return t.shown })

    function activate(tile) {
        if (tile.id === "inhibit") { root.idleInhibited = !root.idleInhibited; return }
        if (tile.id === "rec") root.utilitiesVisible = false   // don't record the panel itself
        run(tile.cmd)
    }

    // loaded on open (VariantRoot): start closed so the reveal animates
    property bool loaded: false
    Component.onCompleted: loaded = true
    property real reveal: loaded && root.utilitiesVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.utilitiesVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001
    onVisibleChanged: if (visible) refresh()
    // a hover-opened panel must not steal the keyboard (games, editors…)
    WlrLayershell.keyboardFocus: root.utilitiesVisible && !root.utilitiesHoverOpened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // hover-opened: close once the pointer has left the card and the frame
    // bands around it (it comes in from the bottom band's corner)
    Item {
        x: card.x
        y: card.y
        width: parent.width - x
        height: parent.height - y
        HoverHandler { id: stripHover }
    }
    Timer {
        interval: 350
        running: root.utilitiesHoverOpened && root.utilitiesVisible && !cardHover.hovered && !stripHover.hovered
        onTriggered: root.utilitiesVisible = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.utilitiesVisible = false
    }

    FrameCard { root: utilPanel.root; card: card; reveal: utilPanel.reveal; edge: "bottom" }
    Rectangle {
        id: card
        width: 360
        height: col.implicitHeight + 28
        x: parent.width - width - (utilPanel.framed ? utilPanel.rightBand : utilPanel.gap)
        y: parent.height - height - utilPanel.bottomBand - (utilPanel.framed ? 0 : utilPanel.gap)
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW
        PillShadow { theme: root ; visible: root.styleShadow && !root.frameOn }

        // content rises out of the bottom band as the blob grows
        opacity: utilPanel.reveal
        transform: Translate { y: (1 - utilPanel.reveal) * 48 }
        focus: root.utilitiesVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.utilitiesVisible = false
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }
        // on the card itself (a parent of its content), so hover over buttons counts
        HoverHandler { id: cardHover }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 14
            spacing: 12

            Item {
                width: parent.width
                height: 22
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Utilities"
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
                        onClicked: root.utilitiesVisible = false
                    }
                }
            }

            // ── quick toggles ──
            Grid {
                id: toggleGrid
                width: parent.width
                columns: 3
                spacing: 8
                readonly property real tileW: (width - 2 * spacing) / 3

                Repeater {
                    model: utilPanel.shownTiles
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        width: toggleGrid.tileW
                        height: 58
                        radius: root.tileRadius + 4
                        color: modelData.on
                            ? (modelData.id === "rec" ? Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.32) : root.fillActive)
                            : tileMa.containsMouse ? root.fillHover : root.fillIdle
                        border.color: modelData.on || tileMa.containsMouse ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { CAnim { ms: 160 } }
                        scale: tileMa.pressed ? 0.95 : 1
                        Behavior on scale { Anim { kind: "spatialFast" } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.glyph
                                fill: tile.modelData.on ? 1 : 0
                                color: tile.modelData.on ? root.seal : root.ink
                                font.pixelSize: 18
                            }
                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                color: tile.modelData.on ? root.ink : root.sumi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            id: tileMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: utilPanel.activate(tile.modelData)
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep; visible: utilPanel.shots.length > 0 }

            // ── latest screenshots ──
            Item {
                width: parent.width
                height: 18
                visible: utilPanel.shots.length > 0
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RECENT CAPTURES"
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "All →"
                    color: allMa.containsMouse ? root.seal : root.sumi
                    font.family: root.mono
                    font.pixelSize: 10
                    MouseArea {
                        id: allMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.utilitiesVisible = false; root.ipcOpenPicker("screenshots") }
                    }
                }
            }
            Row {
                width: parent.width
                spacing: 8
                visible: utilPanel.shots.length > 0
                readonly property real thumbW: (width - 3 * spacing) / 4
                Repeater {
                    model: utilPanel.shots
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.thumbW
                        height: Math.round(width * 9 / 16)
                        radius: root.tileRadius
                        color: root.frameWeak
                        clip: true
                        border.color: shotMa.containsMouse ? root.seal : "transparent"
                        border.width: 1
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: "file://" + parent.modelData
                            sourceSize.width: 256
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                        MouseArea {
                            id: shotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.utilitiesVisible = false
                                Qt.openUrlExternally("file://" + parent.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
