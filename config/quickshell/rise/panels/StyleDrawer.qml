import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Theme / wallpaper drawer (SUPER+W, push into the bottom-centre frame band,
// `ipc call drawer toggle`): a strip of previews with Themes and Wallpapers
// tabs; click applies and the drawer stays open to try another. With the frame
// on it grows out of the bottom band (FrameCard edge "bottom"). Applies with
// the same commands as the big pickers (dots-theme-set / dots-theme-bg-set).
PanelWindow {
    id: drawer
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-drawer"

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property bool framed: root.frameOn
    readonly property int bottomBand: root.barPosition === "bottom" ? barBottom : (framed ? root.frameThickness : 0)

    property string tab: "themes"             // "themes" | "wallpapers"
    property var themes: []                   // [{ name, preview }]
    property var wallpapers: []               // [path]
    property string currentWallpaper: ""
    readonly property string themesDir: root.dotsShellRoot + "/../../themes"

    Process {
        id: themeScan
        command: ["bash", "-c",
            "shopt -s nullglob nocaseglob; for d in \"$1\"/*/; do n=$(basename \"$d\"); " +
            "[ \"${n#_}\" = \"$n\" ] || continue; p=; for c in \"$d\"wallpaper.* \"$d\"preview.* \"$d\"backgrounds/*; do " +
            "case \"$c\" in *.jpg|*.jpeg|*.png|*.webp) p=$c; break;; esac; done; " +
            "[ -n \"$p\" ] && printf '%s\\t%s\\n' \"$n\" \"$p\"; done", "_", drawer.themesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], rows = String(this.text || "").split("\n")
                for (var i = 0; i < rows.length; i++) {
                    var f = rows[i].split("\t")
                    if (f.length === 2) out.push({ name: f[0], preview: f[1] })
                }
                drawer.themes = out
            }
        }
    }
    Process {
        id: wallScan
        command: ["bash", "-c",
            "readlink -f \"$1\" 2>/dev/null || echo; shift; " +
            "find -L \"$@\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "2>/dev/null | sort -u | head -300", "_", root.currentBackgroundPath].concat(root.wallpaperSourcePaths || [])
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = String(this.text || "").split("\n")
                drawer.currentWallpaper = rows.shift() || ""
                drawer.wallpapers = rows.filter(function (r) { return r !== "" })
            }
        }
    }
    function rescan() {
        themeScan.running = false; themeScan.running = true
        wallScan.running = false; wallScan.running = true
    }

    // detached: dots-theme-set takes a moment and must survive the drawer
    // closing (it unloads)
    function applyTheme(name) {
        Quickshell.execDetached(["env", "DOTS_SHELL_PATH=" + root.dotsShellRoot, "dots-theme-set", name])
    }
    function applyWallpaper(path) {
        currentWallpaper = path
        Quickshell.execDetached(["dots-theme-bg-set", path])
    }

    // loaded on open (VariantRoot): start closed so the reveal animates
    property bool loaded: false
    Component.onCompleted: loaded = true
    property real reveal: loaded && root.drawerVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.drawerVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001
    onVisibleChanged: if (visible) rescan()
    WlrLayershell.keyboardFocus: root.drawerVisible && !root.drawerHoverOpened
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.drawerVisible = false
    }

    // hover-opened: close once the pointer has left the card and the band below
    Item {
        x: card.x
        y: card.y + card.height
        width: card.width
        height: parent.height - y
        HoverHandler { id: stripHover }
    }
    Timer {
        interval: 350
        running: root.drawerHoverOpened && root.drawerVisible && !cardHover.hovered && !stripHover.hovered
        onTriggered: root.drawerVisible = false
    }

    FrameCard { root: drawer.root; card: card; reveal: drawer.reveal; edge: "bottom" }
    Rectangle {
        id: card
        width: Math.min(1100, parent.width - 160)
        height: 244
        x: Math.round((parent.width - width) / 2)
        y: parent.height - height - drawer.bottomBand - (drawer.framed ? 0 : drawer.gap)
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW
        PillShadow { theme: root ; visible: root.styleShadow && !root.frameOn }

        opacity: drawer.reveal
        transform: Translate { y: (1 - drawer.reveal) * 56 }
        focus: root.drawerVisible
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.drawerVisible = false; event.accepted = true }
            else if (event.key === Qt.Key_Tab) { drawer.tab = drawer.tab === "themes" ? "wallpapers" : "themes"; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }
        HoverHandler { id: cardHover }

        // ── tabs ──
        Row {
            id: tabs
            anchors.top: parent.top; anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: [{ id: "themes", label: "Themes", glyph: "" }, { id: "wallpapers", label: "Wallpapers", glyph: "" }]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: drawer.tab === modelData.id
                    width: tabRow.implicitWidth + 24
                    height: 28
                    radius: 14
                    color: on ? root.fillActive : tabMa.containsMouse ? root.fillHover : "transparent"
                    border.color: on ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { CAnim { ms: 140 } }
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.modelData.glyph
                            fill: parent.parent.on ? 1 : 0
                            color: parent.parent.on ? root.seal : root.sumi
                            font.pixelSize: 14
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.modelData.label
                            color: parent.parent.on ? root.ink : root.sumi
                            font.family: root.mono; font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: drawer.tab = parent.modelData.id
                    }
                }
            }
        }

        // ── preview strip ──
        // wheel → sideways scroll. A wheel-only MouseArea on top: the thumbnails'
        // MouseAreas would otherwise eat wheel events before the list sees them.
        MouseArea {
            anchors.fill: strip
            z: 1
            acceptedButtons: Qt.NoButton
            onWheel: function (wheel) {
                var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                strip.scrollBy(-d * 1.4)
                wheel.accepted = true
            }
        }
        ListView {
            id: strip
            anchors { left: parent.left; right: parent.right; top: tabs.bottom; bottom: parent.bottom }
            anchors.margins: 16
            anchors.topMargin: 14
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: drawer.tab === "themes" ? drawer.themes : drawer.wallpapers
            // eased sideways scroll; the target accumulates while an animation runs
            property real scrollTarget: 0
            function scrollBy(dx) {
                var from = scrollAnim.running ? scrollTarget : contentX
                scrollTarget = Math.max(0, Math.min(Math.max(0, contentWidth - width), from + dx))
                scrollAnim.to = scrollTarget
                scrollAnim.restart()
            }
            NumberAnimation {
                id: scrollAnim
                target: strip
                property: "contentX"
                duration: 260
                easing.type: Easing.OutCubic
            }
            onModelChanged: { scrollAnim.stop(); contentX = 0 }

            delegate: Item {
                id: cell
                required property var modelData
                readonly property bool isTheme: drawer.tab === "themes"
                readonly property string path: isTheme ? modelData.preview : modelData
                readonly property string label: isTheme ? modelData.name
                    : modelData.replace(/^.*\//, "").replace(/\.[^.]+$/, "")
                readonly property bool current: isTheme ? modelData.name === root.currentThemeName
                                                        : modelData === drawer.currentWallpaper
                width: 220
                height: strip.height

                Rectangle {
                    id: thumb
                    width: parent.width
                    height: parent.height - 22
                    radius: root.tileRadius + 4
                    color: root.frameWeak
                    clip: true
                    border.color: cell.current ? root.seal : thumbMa.containsMouse ? root.sumi : "transparent"
                    border.width: cell.current ? 2 : 1
                    scale: thumbMa.pressed ? 0.96 : thumbMa.containsMouse ? 1.03 : 1
                    Behavior on scale { Anim { kind: "spatialFast" } }
                    Image {
                        anchors.fill: parent
                        anchors.margins: cell.current ? 2 : 1
                        source: "file://" + cell.path
                        sourceSize.width: 440
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    MouseArea {
                        id: thumbMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cell.isTheme ? drawer.applyTheme(cell.modelData.name)
                                                : drawer.applyWallpaper(cell.modelData)
                    }
                }
                UiText {
                    anchors.top: thumb.bottom; anchors.topMargin: 5
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.label
                    color: cell.current ? root.seal : root.sumi
                    font.family: root.mono; font.pixelSize: 10
                    elide: Text.ElideMiddle
                }
            }
        }
    }
}
