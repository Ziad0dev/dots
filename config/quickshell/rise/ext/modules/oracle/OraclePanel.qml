pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.ext.colors
import qs.ext.components
import qs.ext.services as Services

// rise: the Oracle, a chat with the local model dots-llm has running
// (services/Oracle.qml; after dhrruvsharma/shell's OllamaChat). SUPER+ALT+O,
// `qs -c rise ipc call oracle toggle`. Enter asks, Shift+Enter breaks the
// line, Ctrl+L clears, Esc closes (the conversation stays).
Item {
    id: panel

    anchors.fill: parent
    // rise: a chat sidebar out of the frame's left band (FrameDock); visible
    // until it has slid back in
    property bool opened: false
    visible: opened || dock.open

    readonly property var oracle: Services.Oracle
    readonly property string backendName: oracle.backend ? (oracle.unitInfo[oracle.backend] || oracle.backend) : ""

    function open() {
        opened = true;
        oracle.refresh();
        input.forceActiveFocus();
    }
    function close() { opened = false; }
    function toggle() { opened ? close() : open(); }

    FrameDock {
        id: dock
        card: card
        shown: panel.opened
        edge: "left"
    }

    // click-away
    MouseArea {
        anchors.fill: parent
        onClicked: panel.close()
    }

    Rectangle {
        id: card
        x: dock.cardX
        y: dock.cardY
        width: Math.min(640, parent.width - 120)
        height: Math.min(820, parent.height - 160)
        opacity: dock.reveal
        transform: dock.slide
        radius: dock.framed ? dock.radius : Services.DesktopTheme.panelRadius(20)
        color: dock.framed ? "transparent" : Colors.withAlpha(Colors.surface_container_lowest, 0.97)
        border.width: dock.framed ? 0 : 1
        border.color: Colors.withAlpha(Colors.primary, 0.35)

        MouseArea { anchors.fill: parent }

        PanelDecor {
            visible: !dock.framed
            radius: card.radius
            title: "oracle"
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                panel.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                panel.oracle.clear();
                event.accepted = true;
            }
        }

        Column {
            id: head
            x: 28
            y: 22
            width: card.width - 56
            spacing: 4

            Item {
                width: parent.width
                height: title.implicitHeight

                StyledText {
                    id: title
                    text: "The Oracle"
                    font.pixelSize: 26
                    color: Colors.on_surface
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    component Action: StyledText {
                        id: act
                        signal clicked
                        font.pixelSize: 13
                        color: actMa.containsMouse ? Colors.primary : Colors.on_surface_variant
                        MouseArea {
                            id: actMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: act.clicked()
                        }
                    }

                    Action {
                        visible: panel.oracle.messages.length > 0
                        text: "clear"
                        onClicked: panel.oracle.clear()
                    }
                    Action {
                        visible: panel.oracle.backend !== ""
                        text: "put to sleep"
                        onClicked: panel.oracle.sleep()
                    }
                    Action {
                        text: "✕"
                        onClicked: panel.close()
                    }
                }
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                font.pixelSize: 13
                color: panel.oracle.ready ? Colors.tertiary : Colors.on_surface_variant
                text: panel.oracle.ready ? "⸸ " + panel.backendName + (panel.oracle.model ? "  ·  " + panel.oracle.model.split("/").pop() : "")
                    : panel.oracle.waking ? "waking " + panel.backendName + "…"
                    : panel.oracle.backend ? panel.backendName + " is stirring…"
                    : "asleep: wake one below"
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.withAlpha(Colors.primary, 0.3)
            }
        }

        // ── no backend: pick one to wake ──
        Column {
            x: 28
            anchors.top: head.bottom
            anchors.topMargin: 18
            width: card.width - 56
            spacing: 6
            visible: !panel.oracle.backend && !panel.oracle.waking

            Repeater {
                model: panel.oracle.units

                Rectangle {
                    id: unitRow
                    required property string modelData
                    width: parent.width
                    height: 40
                    color: unitMa.containsMouse ? Colors.withAlpha(Colors.primary, 0.14) : "transparent"
                    border.width: 1
                    border.color: unitMa.containsMouse ? Colors.primary : Colors.withAlpha(Colors.outline_variant, 0.7)

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.oracle.unitInfo[unitRow.modelData] || unitRow.modelData
                        font.pixelSize: 14
                    }
                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: unitRow.modelData
                        font.pixelSize: 12
                        color: Colors.on_surface_variant
                    }
                    MouseArea {
                        id: unitMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.oracle.wake(unitRow.modelData)
                    }
                }
            }
        }

        // ── the conversation ──
        ListView {
            id: list
            x: 28
            anchors.top: head.bottom
            anchors.topMargin: 14
            anchors.bottom: inputBox.top
            anchors.bottomMargin: 12
            width: card.width - 56
            visible: panel.oracle.backend !== "" || panel.oracle.messages.length > 0
            clip: true
            spacing: 14
            model: panel.oracle.messages
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: Qt.callLater(positionViewAtEnd)
            onContentHeightChanged: if (panel.oracle.streaming) positionViewAtEnd()

            delegate: Item {
                id: msg
                required property var modelData
                readonly property bool mine: modelData.role === "user"
                width: list.width
                readonly property string thinking: modelData.thinking || ""
                readonly property bool pondering: !mine && thinking !== "" && !modelData.content
                height: body.implicitHeight + (mine ? 20 : 4) + (thought.visible ? thought.implicitHeight + 6 : 0)

                // a reasoning model's thinking: live while it ponders, then
                // folded to one line once it answers
                StyledText {
                    id: thought
                    visible: msg.thinking !== ""
                    width: list.width
                    font.pixelSize: 13
                    font.italic: true
                    color: Colors.on_surface_variant
                    wrapMode: Text.Wrap
                    maximumLineCount: msg.pondering ? 6 : 1
                    elide: Text.ElideRight
                    text: msg.pondering
                        ? "the oracle ponders… " + msg.thinking.slice(-600)
                        : "⸸ pondered " + msg.thinking.trim().split(/\s+/).length + " words"
                }

                Rectangle {
                    visible: msg.mine
                    anchors.right: parent.right
                    width: Math.min(list.width * 0.78, body.implicitWidth + 28)
                    height: parent.height
                    color: Colors.withAlpha(Colors.primary, 0.12)
                    border.width: 1
                    border.color: Colors.withAlpha(Colors.primary, 0.45)
                }

                TextEdit {
                    id: body
                    visible: text !== ""
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.Wrap
                    textFormat: msg.mine ? TextEdit.PlainText : TextEdit.MarkdownText
                    text: msg.modelData.content || (panel.oracle.streaming && !msg.pondering ? "…" : "")
                    color: msg.modelData.role === "error" ? Colors.error : Colors.on_surface
                    selectionColor: Colors.withAlpha(Colors.primary, 0.5)
                    font.family: Services.DesktopTheme.font || "Alegreya Sans"
                    font.pixelSize: 15
                    width: msg.mine ? Math.min(list.width * 0.78 - 28, implicitWidth) : list.width
                    x: msg.mine ? list.width - width - 14 : 0
                    y: msg.mine ? 10 : 2 + (thought.visible ? thought.implicitHeight + 6 : 0)
                }
            }
        }

        // ── the question ──
        Rectangle {
            id: inputBox
            x: 28
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
            width: card.width - 56
            height: Math.min(140, Math.max(48, input.implicitHeight + 20))
            color: Colors.withAlpha(Colors.surface_container, 0.9)
            border.width: 1
            border.color: input.activeFocus ? Colors.primary : Colors.withAlpha(Colors.outline_variant, 0.8)

            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                anchors.rightMargin: 60

                TextArea {
                    id: input
                    enabled: panel.oracle.ready
                    placeholderText: panel.oracle.ready ? "Ask the oracle…   (Enter asks · Shift+Enter breaks the line)" : "Wake an oracle first"
                    placeholderTextColor: Colors.on_surface_variant
                    color: Colors.on_surface
                    wrapMode: TextArea.Wrap
                    font.family: Services.DesktopTheme.font || "Alegreya Sans"
                    font.pixelSize: 15
                    background: null
                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            panel.oracle.send(input.text);
                            input.text = "";
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            panel.close();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                            panel.oracle.clear();
                            event.accepted = true;
                        }
                    }
                }
            }

            // ask / stop
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 32
                color: sendMa.containsMouse ? Colors.primary : Colors.withAlpha(Colors.primary, 0.7)
                opacity: panel.oracle.ready ? 1 : 0.35
                StyledText {
                    anchors.centerIn: parent
                    text: panel.oracle.streaming ? "■" : "⸸"
                    font.pixelSize: 16
                    color: Colors.on_primary
                }
                MouseArea {
                    id: sendMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (panel.oracle.streaming) {
                            panel.oracle.cancel();
                        } else {
                            panel.oracle.send(input.text);
                            input.text = "";
                        }
                    }
                }
            }
        }
    }
}
