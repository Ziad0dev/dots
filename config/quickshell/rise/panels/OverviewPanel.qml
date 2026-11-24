import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.ext.colors
import qs.ext.services as Services
import "../modules"

// Every workspace as a miniature of its screen, after lucid's workspaces
// overview (github.com/Sn3akyy1/lucid, MIT): a tonal card with the wallpaper,
// each window a live picture of itself where it really sits, its app's icon
// on it. Click a window to go to it, middle-click to close it, click the
// card's empty space for the workspace. Keys: arrows / hjkl move, 1-9 jump,
// Enter goes, Escape leaves.
PanelWindow {
    id: win
    required property var root

    visible: reveal > 0.001
    screen: root.activePopupScreen
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-overview"
    WlrLayershell.keyboardFocus: root.overviewVisible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real reveal: root.overviewVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.overviewVisible ? "spatial" : "exit" }
    }

    property int sel: 0

    readonly property var cells: {
        var out = []
        var vals = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var i = 0; i < vals.length; i++) {
            var w = vals[i]
            if (!w || w.id < 0) continue
            var tl = (w.toplevels && w.toplevels.values) ? w.toplevels.values : []
            out.push({ id: w.id, name: w.name, wins: tl, monitor: w.monitor })
        }
        out.sort(function (a, b) { return a.id - b.id })
        return out
    }
    // the cards take the shape of the screen the overview opens on
    readonly property real aspect: screen ? screen.height / Math.max(1, screen.width) : 9 / 16
    readonly property int columns: Math.min(4, Math.max(1, cells.length))
    readonly property real cardW: Math.min(480, (width - 160) / columns - 18)
    readonly property real cardH: cardW * aspect

    // window and monitor geometry is only fetched on request
    onVisibleChanged: if (visible) {
        sel = Math.max(0, cells.findIndex(c => Hyprland.focusedWorkspace && c.id === Hyprland.focusedWorkspace.id))
        Hyprland.refreshMonitors()
        Hyprland.refreshToplevels()
    }

    function activate(i) {
        if (i < 0 || i >= cells.length) return
        root.gotoWorkspace(cells[i].id)
        root.overviewVisible = false
    }

    // the scrim: dimmed, and blurred by Hyprland (the dots-* layer rule)
    Rectangle {
        anchors.fill: parent
        color: Colors.withAlpha(Colors.background, 0.55 * win.reveal)
        MouseArea { anchors.fill: parent; onClicked: root.overviewVisible = false }
    }

    Item {
        anchors.centerIn: parent
        width: grid.width
        height: grid.height
        opacity: win.reveal
        scale: 0.94 + 0.06 * win.reveal
        focus: root.overviewVisible

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.overviewVisible = false; event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                win.sel = Math.min(win.sel + 1, win.cells.length - 1); event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                win.sel = Math.max(win.sel - 1, 0); event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                win.sel = Math.min(win.sel + win.columns, win.cells.length - 1); event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                win.sel = Math.max(win.sel - win.columns, 0); event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                win.activate(win.sel); event.accepted = true
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                var want = event.key - Qt.Key_0
                for (var i = 0; i < win.cells.length; i++)
                    if (win.cells[i].id === want) { win.activate(i); break }
                event.accepted = true
            }
        }

        Grid {
            id: grid
            columns: win.columns
            spacing: 18

            Repeater {
                model: win.cells

                Item {
                    id: cell
                    required property var modelData
                    required property int index

                    readonly property bool isActive: Hyprland.focusedWorkspace !== null
                        && Hyprland.focusedWorkspace.id === modelData.id
                    readonly property bool isSel: index === win.sel
                    // the workspace's screen, for placing its windows
                    // (Quickshell's screen has the logical, rotated size; Hyprland's
                    // monitor reports the mode before rotation)
                    readonly property var mon: modelData.monitor
                    readonly property var scr: mon ? Quickshell.screens.find(s => s.name === mon.name) ?? null : null
                    readonly property real monX: scr ? scr.x : mon ? mon.x : 0
                    readonly property real monY: scr ? scr.y : mon ? mon.y : 0
                    readonly property real monW: scr ? scr.width : mon && mon.width > 0 ? mon.width / (mon.scale || 1) : 1920
                    readonly property real monH: scr ? scr.height : mon && mon.height > 0 ? mon.height / (mon.scale || 1) : 1080
                    // the screen fitted into the card, centred
                    readonly property real k: Math.min(win.cardW / monW, win.cardH / monH)
                    readonly property real offX: (win.cardW - monW * k) / 2
                    readonly property real offY: (win.cardH - monH * k) / 2

                    width: win.cardW
                    height: win.cardH + 34

                    // the miniature screen
                    ClippingRectangle {
                        id: screenCard
                        width: win.cardW
                        height: win.cardH
                        radius: 22
                        color: Qt.tint(Colors.surface_container_high, Colors.withAlpha(Colors.primary, 0.10))
                        border.width: cell.isSel || cell.isActive ? 3 : 0
                        border.color: cell.isActive ? Colors.primary : Colors.withAlpha(Colors.primary, 0.55)
                        scale: cardArea.containsMouse ? 1.02 : 1
                        Behavior on scale { Anim { kind: "spatialFast" } }

                        Image {
                            anchors.fill: parent
                            // a video (wallpaper or intro) can't load as an image:
                            // use the still link, whose frame wallpaper-apply keeps
                            // (stillSerial moves once the link is rewritten, and makes
                            // the unchanged link path reload)
                            source: !Services.WallpaperEngine.current ? ""
                                : Services.WallpaperEngine.kind(Services.WallpaperEngine.current) === "video"
                                    ? "file://" + Services.WallpaperEngine.link + "?" + Services.WallpaperEngine.stillSerial
                                    : "file://" + Services.WallpaperEngine.current
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 480
                            asynchronous: true
                            cache: false
                            opacity: 0.55
                        }

                        // the empty part of the card: the workspace itself
                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.sel = cell.index
                            onClicked: win.activate(cell.index)
                        }

                        Repeater {
                            model: cell.modelData.wins

                            Item {
                                id: thumb
                                required property var modelData
                                readonly property var ipc: modelData.lastIpcObject
                                readonly property bool placed: !!(ipc && ipc.at && ipc.size)
                                x: placed ? cell.offX + (ipc.at[0] - cell.monX) * cell.k : 8
                                y: placed ? cell.offY + (ipc.at[1] - cell.monY) * cell.k : 8
                                width: placed ? Math.max(24, ipc.size[0] * cell.k) : win.cardW * 0.4
                                height: placed ? Math.max(18, ipc.size[1] * cell.k) : win.cardH * 0.4
                                visible: !ipc || !ipc.hidden

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Colors.surface_container_highest
                                    border.width: thumbArea.containsMouse ? 2 : 0
                                    border.color: Colors.primary

                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: win.visible && thumb.modelData.wayland ? thumb.modelData.wayland : null
                                        live: win.root.overviewVisible
                                    }
                                }

                                // the app, in the middle of its window
                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.min(40, Math.max(16, Math.min(parent.width, parent.height) * 0.35))
                                    source: {
                                        const cls = thumb.ipc && thumb.ipc.class ? thumb.ipc.class : "";
                                        const entry = cls ? DesktopEntries.heuristicLookup(cls) : null;
                                        return Quickshell.iconPath(entry ? entry.icon : cls.toLowerCase(), "application-x-executable");
                                    }
                                }

                                MouseArea {
                                    id: thumbArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    onEntered: win.sel = cell.index
                                    onClicked: (e) => {
                                        const w = thumb.modelData.wayland;
                                        if (e.button === Qt.MiddleButton) {
                                            if (w) w.close();
                                            return;
                                        }
                                        if (w) w.activate(); else win.root.gotoWorkspace(cell.modelData.id);
                                        win.root.overviewVisible = false;
                                    }
                                }
                            }
                        }
                    }

                    // the workspace's number, and how many windows it holds
                    Row {
                        anchors.top: screenCard.bottom
                        anchors.topMargin: 8
                        anchors.horizontalCenter: screenCard.horizontalCenter
                        spacing: 8

                        Rectangle {
                            width: Math.max(26, num.implicitWidth + 14)
                            height: 24
                            radius: 12
                            color: cell.isActive ? Colors.primary : Colors.withAlpha(Colors.surface_container_highest, 0.9)
                            Text {
                                id: num
                                anchors.centerIn: parent
                                text: cell.modelData.name && cell.modelData.name !== "" ? cell.modelData.name : String(cell.modelData.id)
                                font.family: "Google Sans Flex"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: cell.isActive ? Colors.on_primary : Colors.on_surface
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.modelData.wins.length === 1 ? "1 window" : cell.modelData.wins.length + " windows"
                            font.family: "Google Sans Flex"
                            font.pixelSize: 12
                            color: Colors.withAlpha(Colors.on_surface, 0.7)
                        }
                    }
                }
            }
        }
    }
}
