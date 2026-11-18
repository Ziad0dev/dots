pragma ComponentBehavior: Bound
// Ported from dhrruvsharma/shell (quickshell/modules/lockthemes/WidgetsTab.qml), GPL-3.0-or-later.
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.ext.colors
import qs.ext.components
import qs.ext.modules.desktoptheme
import qs.ext.modules.desktopwidgets
import qs.ext.modules.lock
import qs.ext.services as Services

// Themes panel, Widgets tab: switch desktop widgets on and off
// (services/DesktopWidgets.qml) and arrange them on a miniature of the
// desktop in the current theme. Widgets can be dragged there or on the
// desktop itself.
//
// Keys (forwarded by the panel): ↑↓ choose, Enter toggle, R reset positions.
Item {
    id: tab

    readonly property var dw: Services.DesktopWidgets
    readonly property string themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    property int sel: 0

    function handleKey(event) {
        const n = dw.widgets.length;
        if (event.key === Qt.Key_Down)
            sel = (sel + 1) % n;
        else if (event.key === Qt.Key_Up)
            sel = (sel + n - 1) % n;
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
            dw.toggle(dw.widgets[sel].id);
        else if (event.key === Qt.Key_R)
            dw.resetPositions();
        else
            return false;
        return true;
    }

    // ── Miniature desktop ─────────────────────────────────────────────────────
    Item {
        id: mock

        readonly property real s: width / desktop.width

        width: Math.min(parent.width * 0.62, (parent.height - hint.height - 14) * desktop.width / desktop.height)
        height: width * desktop.height / desktop.width

        Rectangle {
            id: mockMask
            anchors.fill: parent
            radius: Services.DesktopTheme.rad(18)
            visible: false
            layer.enabled: true
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mockMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.background
            }

            Image {
                anchors.fill: parent
                source: Services.WallpaperEngine.current ? "file://" + Services.WallpaperEngine.current : ""
                sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            ThemeLayer {
                width: desktop.width
                height: desktop.height
                scale: mock.s
                transformOrigin: Item.TopLeft
                pxScale: mock.s
                still: true
                visible: tab.themeId !== ""
                themeId: tab.themeId
            }

            WidgetPreview {
                id: desktop
                scale: mock.s
                transformOrigin: Item.TopLeft
                editable: true
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Services.DesktopTheme.rad(18)
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(Colors.outline_variant, 0.8)
        }
    }

    Row {
        id: hint
        anchors.top: mock.bottom
        anchors.topMargin: 14
        spacing: 8

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: "drag_pan"
            font.pixelSize: 18
            color: Colors.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Drag widgets here, or grab them anywhere on the desktop. They take on the look of the desktop theme" + (tab.themeId ? " (" + Services.DesktopTheme.current.name + ")." : ".")
            font.pixelSize: 12
            color: Colors.on_surface_variant
        }
    }

    // ── Widget list ───────────────────────────────────────────────────────────
    Flickable {
        id: flick
        anchors.left: mock.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 10

            Repeater {
                model: tab.dw.widgets

                // a gallery card: the widget itself, live but inert, scaled
                // into a preview box; a click puts it on the desktop or takes
                // it off (after lucid's widget gallery)
                ClickableRect {
                    id: card

                    required property var modelData
                    required property int index
                    readonly property bool on: tab.dw.enabled(modelData.id)
                    readonly property var preview: desktop.components[modelData.id] ?? null
                    readonly property bool isSel: tab.sel === index
                    // keyboard choice scrolls into view
                    onIsSelChanged: if (isSel && (y < flick.contentY || y + height > flick.contentY + flick.height))
                        flick.contentY = Math.max(0, Math.min(y, flick.contentHeight - flick.height))

                    width: list.width
                    height: (preview ? 176 : 0) + 64
                    radius: Services.DesktopTheme.rad(22)
                    color: on ? Colors.primary_container : card.hovered ? Colors.surface_container_high : Colors.surface_container
                    border.width: tab.sel === index ? 2 : 0
                    border.color: Colors.primary
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tab.sel = index;
                        tab.dw.toggle(modelData.id);
                    }

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    Item {
                        id: stage
                        visible: card.preview !== null
                        x: 10
                        y: 10
                        width: parent.width - 20
                        height: 166
                        clip: true

                        // the wallpaper behind it, so it looks as on the desktop
                        Rectangle {
                            anchors.fill: parent
                            radius: Services.DesktopTheme.rad(14)
                            color: Colors.surface_container_lowest
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: Services.WallpaperEngine.current ? "file://" + Services.WallpaperEngine.current : ""
                                sourceSize.width: 400
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: 0.5
                            }
                        }

                        Loader {
                            id: live
                            active: card.preview !== null && tab.visible
                            sourceComponent: card.preview
                            enabled: false
                            readonly property real k: item ? Math.min(1, (stage.width - 16) / Math.max(1, item.implicitWidth), (stage.height - 16) / Math.max(1, item.implicitHeight)) : 1
                            anchors.centerIn: parent
                            scale: k
                        }
                    }

                    Glyph {
                        id: icon
                        x: 18
                        y: (card.preview ? 176 : 0) + 20
                        text: card.modelData.icon
                        filled: card.on
                        font.pixelSize: 24
                        color: card.on ? Colors.on_primary_container : Colors.on_surface_variant
                    }

                    Column {
                        anchors.left: icon.right
                        anchors.leftMargin: 14
                        anchors.right: badge.left
                        anchors.rightMargin: 12
                        y: (card.preview ? 176 : 0) + 12
                        spacing: 2

                        StyledText {
                            text: card.modelData.name
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: card.on ? Colors.on_primary_container : Colors.on_surface
                        }

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: card.modelData.description
                            font.pixelSize: 12
                            color: card.on ? Colors.withAlpha(Colors.on_primary_container, 0.8) : Colors.on_surface_variant
                        }
                    }

                    // add / on the desktop
                    Rectangle {
                        id: badge
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: (card.preview ? 176 : 0) + 14
                        width: badgeRow.implicitWidth + 20
                        height: 34
                        radius: Services.DesktopTheme.rad(17)
                        color: card.on ? Colors.primary : Colors.surface_container_highest

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 4
                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.on ? "check" : "add"
                                font.pixelSize: 18
                                color: card.on ? Colors.on_primary : Colors.on_surface
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.on ? "On desktop" : "Add"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: card.on ? Colors.on_primary : Colors.on_surface
                            }
                        }
                    }
                }
            }

            ClickableRect {
                id: resetButton
                width: resetRow.implicitWidth + 32
                height: 38
                radius: Services.DesktopTheme.rad(19)
                color: resetButton.hovered ? Colors.surface_container_high : Colors.surface_container
                border.width: 1
                border.color: Colors.withAlpha(Colors.outline_variant, 0.7)
                cursorShape: Qt.PointingHandCursor
                onClicked: tab.dw.resetPositions()

                Row {
                    id: resetRow
                    anchors.centerIn: parent
                    spacing: 8

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "restart_alt"
                        font.pixelSize: 18
                        color: Colors.on_surface_variant
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Reset positions (R)"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Each widget is its own small surface, so only it redraws: the clock once a minute, the music player once a second while something plays, the system monitor every two seconds, the visualizer only while audio plays. The visualizer's shape, colour and tilt are still set in its own editor (SUPER+T)."
                font.pixelSize: 12
                lineHeight: 1.2
                color: Colors.on_surface_variant
            }
        }
    }
}
