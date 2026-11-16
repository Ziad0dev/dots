pragma ComponentBehavior: Bound
// Ported from dhrruvsharma/shell (quickshell/modules/avatar/AvatarPicker.qml), GPL-3.0-or-later.
import QtQuick
import qs.ext.services as Services
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import QtQuick.Controls
import qs.ext.colors
import qs.ext.components

Item {
    id: root

    property bool opened: false
    property int  selectedIdx: -1

    // rise: a card docked in the bottom band of rise's frame (FrameDock).
    // Hidden once it has slid back in, so the tiles' shimmer can't keep
    // repainting.
    anchors.fill: parent
    visible: opened || dock.open

    FrameDock {
        id: dock
        card: dockCard
        shown: root.opened
        edge: "bottom"
    }

    // click-away
    MouseArea {
        anchors.fill: parent
        enabled: root.opened
        onClicked: root.close()
    }

    // ── Data ──────────────────────────────────────────────────────────────────

    FolderListModel {
        id: folderModel
        folder:      "file://" + Quickshell.env("HOME") + "/Pictures/avatars"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
        showDirs:    false
        sortField:   FolderListModel.Name
    }

    Process { id: symlinkProc }

    function applyAvatar(idx) {
        if (idx < 0 || idx >= folderModel.count) return
        const path = folderModel.get(idx, "filePath")
        if (!path) return
        symlinkProc.exec(["ln", "-sf", path,
            Quickshell.env("HOME") + "/.cache/current_avatar"])
        selectedIdx = idx
        root.close()
    }

    // ── Dock card ─────────────────────────────────────────────────────────────

    Rectangle {
        id: dockCard

        PanelDecor {
            visible: !dock.framed
            radius: dockCard.radius
            title: "avatar"
        }
        x: dock.cardX
        y: dock.cardY
        opacity: dock.reveal
        transform: dock.slide
        clip: true
        // swallow clicks on the card itself
        MouseArea { anchors.fill: parent }

        // the empty state needs room for its hint
        width:  folderModel.count === 0 ? 300 : Math.min(folderModel.count, 5) * 88 + 24
        height: 104

        radius: dock.framed ? dock.radius : Services.DesktopTheme.rad(24)
        color:  dock.framed ? "transparent" : Colors.surface_container

        // bottom shadow strip
        Rectangle {
            visible: !dock.framed
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: parent.radius
            color:  Qt.rgba(0, 0, 0, 0.25)
            // clip to card shape via parent's radius
            Rectangle {
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                height: parent.height
                color: Qt.rgba(0, 0, 0, 0.18)
            }
        }

        // outer border
        Rectangle {
            visible: !dock.framed
            anchors.fill: parent; radius: parent.radius; color: "transparent"
            border.width: 1
            border.color: Qt.rgba(
                Qt.color(Colors.outline_variant).r,
                Qt.color(Colors.outline_variant).g,
                Qt.color(Colors.outline_variant).b, 0.5)
        }

        // ── Avatar row ────────────────────────────────────────────────────────

        ListView {
            id: avatarList
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.leftMargin:  12
            anchors.rightMargin: 12
            height: 80

            orientation:     ListView.Horizontal
            spacing:         8
            clip:            true
            model:           folderModel
            boundsBehavior:  Flickable.StopAtBounds
            flickDeceleration: 1500

            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
                id: cell
                required property string filePath
                required property int    index

                property bool hov: false
                property bool sel: root.selectedIdx === index

                width:  76
                height: 80

                // selection glow behind the tile
                Rectangle {
                    anchors.centerIn: tile
                    width:  tile.width + 8
                    height: tile.height + 8
                    radius: tile.radius + 4
                    color:  "transparent"
                    border.width: 2
                    border.color: Colors.primary
                    opacity: cell.sel ? 0.8 : cell.hov ? 0.3 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // tile
                Rectangle {
                    id: tile
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 4

                    width:  68
                    height: 68
                    radius: Services.DesktopTheme.rad(16)
                    clip:   true

                    // scale: unselected tiles shrink slightly so the selected one pops
                    scale: cell.hov ? 1.06 : cell.sel ? 1.0 : 0.88
                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // opacity: dim non-selected
                    opacity: cell.sel ? 1.0 : cell.hov ? 0.95 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // shimmer placeholder
                    Rectangle {
                        anchors.fill: parent
                        color: Colors.surface_container_highest
                        visible: img.status !== Image.Ready
                        SequentialAnimation on opacity {
                            running: root.visible && img.status !== Image.Ready
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 700 }
                            NumberAnimation { to: 1.0;  duration: 700 }
                        }
                    }

                    Image {
                        id: img
                        anchors.fill: parent
                        source:       "file://" + cell.filePath
                        fillMode:     Image.PreserveAspectCrop
                        sourceSize:   Qt.size(136, 136)   // 2x the 68px tile
                        smooth:       true; mipmap: true
                        asynchronous: true; cache: true
                    }
                }

                // selection dot under tile
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width:  cell.sel ? 16 : 4
                    height: 3
                    radius: Services.DesktopTheme.rad(2)
                    color:  Colors.primary
                    opacity: cell.sel ? 1.0 : cell.hov ? 0.4 : 0.0
                    Behavior on width   { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onEntered:    cell.hov = true
                    onExited:     cell.hov = false
                    onClicked:    root.applyAvatar(cell.index)
                }
            }
        }

        // empty state (worded like the network map's)
        Column {
            anchors.centerIn: parent
            visible: folderModel.count === 0
            spacing: 4
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No avatars yet"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Colors.on_surface_variant
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Put images in ~/Pictures/avatars"
                font.pixelSize: 11
                color: Colors.withAlpha(Colors.on_surface_variant, 0.65)
            }
        }
    }

    // ── Open / Close ──────────────────────────────────────────────────────────

    function open() {
        opened = true
        forceActiveFocus()
    }

    function close() {
        opened = false
    }

    Keys.onEscapePressed: close()
}
