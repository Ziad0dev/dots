import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Omarchy-style theme carousel — overlay only. Does not replace Waybar.
ShellRoot {
    id: root

    readonly property string themesDir: Quickshell.env("HOME") + "/dots/config/themes"
    property var themes: []
    property int index: 0
    property string query: ""

    readonly property var visibleThemes: {
        if (query === "")
            return themes
        const q = query.toLowerCase()
        return themes.filter(t => t.name.toLowerCase().includes(q))
    }

    Component.onCompleted: listProc.running = true

    function apply(name) {
        applyProc.exec(["themectl", "set", name])
        Qt.quit()
    }

    function move(delta) {
        const n = visibleThemes.length
        if (n === 0)
            return
        index = (index + delta + n) % n
    }

    Process {
        id: listProc
        command: [
            "sh", "-c",
            "find '" + root.themesDir + "' -mindepth 1 -maxdepth 1 -type d ! -name '_*' -printf '%f\\n' | sort"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.trim().split("\n").filter(n => n.length)
                root.themes = names.map(n => ({
                    name: n,
                    preview: root.themesDir + "/" + n + "/preview.png",
                    dir: root.themesDir + "/" + n
                }))
                root.index = 0
            }
        }
    }

    Process { id: applyProc }

    PanelWindow {
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "theme-picker"

        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
            Rectangle {
                anchors.fill: parent
                color: "#cc0a0a0a"
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, 1100)
            height: Math.min(parent.height - 64, 420)
            radius: 20
            color: "#161616"
            border.color: "#393939"
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: "Style › Theme"
                        color: "#ee5396"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    TextField {
                        id: search
                        Layout.fillWidth: true
                        placeholderText: "filter themes…"
                        color: "#f2f4f8"
                        placeholderTextColor: "#525252"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        background: Rectangle {
                            radius: 10
                            color: "#262626"
                            border.color: search.activeFocus ? "#33b1ff" : "#393939"
                            border.width: 1
                        }
                        onTextChanged: {
                            root.query = text
                            root.index = 0
                        }
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Left || e.key === Qt.Key_H) {
                                root.move(-1); e.accepted = true
                            } else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) {
                                root.move(1); e.accepted = true
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                if (root.visibleThemes.length)
                                    root.apply(root.visibleThemes[root.index].name)
                                e.accepted = true
                            } else if (e.key === Qt.Key_Escape) {
                                Qt.quit(); e.accepted = true
                            }
                        }
                        Component.onCompleted: forceActiveFocus()
                    }
                }

                ListView {
                    id: carousel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: 18
                    clip: true
                    model: root.visibleThemes
                    currentIndex: root.index
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: width / 2 - 140
                    preferredHighlightEnd: width / 2 + 140
                    highlightMoveDuration: 120

                    delegate: Item {
                        width: 280
                        height: carousel.height
                        scale: ListView.isCurrentItem ? 1.0 : 0.88
                        opacity: ListView.isCurrentItem ? 1.0 : 0.55
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 260
                            height: parent.height - 8
                            radius: 14
                            color: "#0d0d0d"
                            border.color: ListView.isCurrentItem ? "#ee5396" : "#393939"
                            border.width: ListView.isCurrentItem ? 2 : 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 6
                                source: modelData.preview
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 36
                                color: "#cc161616"
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: ListView.isCurrentItem ? "#ee5396" : "#f2f4f8"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.bold: ListView.isCurrentItem
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.index = index
                                    root.apply(modelData.name)
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "← → / h l   Enter apply   Esc close   ·   Waybar & terminal stay Oxocarbon"
                    color: "#525252"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
            }
        }
    }
}
