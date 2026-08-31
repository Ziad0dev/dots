import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../modules"

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
        NumberAnimation {
            duration: root.overviewVisible ? 180 : 130
            easing.type: root.overviewVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    property int sel: 0

    readonly property color island: Qt.rgba(
        root.paper.r + (root.ink.r - root.paper.r) * 0.07,
        root.paper.g + (root.ink.g - root.paper.g) * 0.07,
        root.paper.b + (root.ink.b - root.paper.b) * 0.07, 1.0)

    readonly property var cells: {
        var out = []
        var vals = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var i = 0; i < vals.length; i++) {
            var w = vals[i]
            if (!w || w.id < 0) continue
            var tl = (w.toplevels && w.toplevels.values) ? w.toplevels.values : []
            out.push({ id: w.id, name: w.name, wins: tl })
        }
        out.sort(function (a, b) { return a.id - b.id })
        return out
    }

    onVisibleChanged: if (visible) sel = 0

    function activate(i) {
        if (i < 0 || i >= cells.length) return
        root.gotoWorkspace(cells[i].id)
        root.overviewVisible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.72 * win.reveal)
        MouseArea { anchors.fill: parent; onClicked: root.overviewVisible = false }
    }

    Item {
        anchors.centerIn: parent
        width: grid.width
        height: grid.height
        opacity: win.reveal
        scale: 0.96 + 0.04 * win.reveal
        focus: root.overviewVisible

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.overviewVisible = false; event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                win.sel = Math.min(win.sel + 1, win.cells.length - 1); event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                win.sel = Math.max(win.sel - 1, 0); event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                win.sel = Math.min(win.sel + grid.columns, win.cells.length - 1); event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                win.sel = Math.max(win.sel - grid.columns, 0); event.accepted = true
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
            columns: Math.min(4, Math.max(1, win.cells.length))
            spacing: 14

            Repeater {
                model: win.cells

                Rectangle {
                    id: cell
                    required property var modelData
                    required property int index

                    width: 260
                    height: 156
                    radius: root.pillRadius
                    color: win.island
                    border.width: 2
                    border.color: index === win.sel ? root.seal : root.pillBorder
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    readonly property bool isActive:
                        Hyprland.focusedWorkspace
                        && Hyprland.focusedWorkspace.id === modelData.id

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Row {
                            spacing: 6
                            UiText {
                                text: cell.modelData.name && cell.modelData.name !== ""
                                    ? cell.modelData.name : String(cell.modelData.id)
                                font.family: root.mono
                                font.pixelSize: 13
                                font.bold: cell.isActive
                                color: cell.isActive ? root.seal : root.ink
                            }
                            UiText {
                                text: cell.modelData.wins.length > 0
                                    ? "· " + cell.modelData.wins.length : ""
                                font.family: root.mono
                                font.pixelSize: 12
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 3

                            Repeater {
                                model: cell.modelData.wins.slice(0, 5)

                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 20
                                    radius: 4
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                                    UiText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        elide: Text.ElideRight
                                        text: parent.modelData.title && parent.modelData.title !== ""
                                            ? parent.modelData.title : "—"
                                        font.family: root.mono
                                        font.pixelSize: 11
                                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.sel = cell.index
                        onClicked: win.activate(cell.index)
                    }
                }
            }
        }
    }
}
