import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
    WlrLayershell.namespace: "dots-openrouter"
    WlrLayershell.keyboardFocus: root.openRouterVisible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real reveal: root.openRouterVisible ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    property var models: []
    property string filter: ""
    property string selected: "anthropic/claude-sonnet-4.5"
    property string reply: ""
    property bool busy: false
    property string credit: ""

    readonly property color island: Qt.rgba(
        root.paper.r + (root.ink.r - root.paper.r) * 0.07,
        root.paper.g + (root.ink.g - root.paper.g) * 0.07,
        root.paper.b + (root.ink.b - root.paper.b) * 0.07, 1.0)

    readonly property var shown: {
        var q = filter.toLowerCase()
        var out = []
        for (var i = 0; i < models.length && out.length < 300; i++)
            if (q === "" || models[i].id.toLowerCase().indexOf(q) !== -1)
                out.push(models[i])
        return out
    }

    onVisibleChanged: if (visible) { refreshModels.running = true; refreshKey.running = true }

    Process {
        id: refreshModels
        command: ["python3", Quickshell.env("HOME") + "/dots/config/quickshell/rise/scripts/openrouter", "models"]
        onExited: modelFile.reload()
    }
    Process {
        id: refreshKey
        command: ["python3", Quickshell.env("HOME") + "/dots/config/quickshell/rise/scripts/openrouter", "key"]
        onExited: keyFile.reload()
    }

    FileView {
        id: modelFile
        path: Quickshell.env("HOME") + "/.cache/openrouter-models.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(text())
                win.models = d.models || []
            } catch (e) { win.models = [] }
        }
    }

    FileView {
        id: keyFile
        path: Quickshell.env("HOME") + "/.cache/openrouter-key.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(text())
                if (!d.ok) { win.credit = "key error"; return }
                win.credit = d.remaining !== null && d.remaining !== undefined
                    ? "$" + d.remaining.toFixed(2) + " left"
                    : "$" + d.usage.toFixed(2) + " used"
            } catch (e) { win.credit = "" }
        }
    }

    Process {
        id: chat
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: { win.reply = this.text.trim(); win.busy = false }
        }
        onExited: win.busy = false
    }

    function send() {
        if (busy || promptBox.text.trim() === "") return
        busy = true
        reply = ""
        chat.command = ["python3",
                        Quickshell.env("HOME") + "/dots/config/quickshell/rise/scripts/openrouter",
                        "chat", selected]
        chat.running = true
        chat.write(promptBox.text)
        chat.stdinEnabled = false
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.7 * win.reveal)
        MouseArea { anchors.fill: parent; onClicked: root.openRouterVisible = false }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 940
        height: 620
        radius: root.pillRadius
        color: win.island
        border.color: root.pillBorder
        border.width: root.pillBorderW
        opacity: win.reveal
        scale: 0.97 + 0.03 * win.reveal
        focus: root.openRouterVisible

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) { root.openRouterVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Row {
                width: parent.width
                spacing: 10

                UiText {
                    text: "OpenRouter"
                    font.family: root.mono
                    font.pixelSize: 15
                    font.bold: true
                    color: root.seal
                }
                UiText {
                    text: win.credit
                    font.family: root.mono
                    font.pixelSize: 12
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                }
                UiText {
                    text: win.models.length > 0 ? "· " + win.models.length + " models" : "· loading…"
                    font.family: root.mono
                    font.pixelSize: 12
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
                }
            }

            Row {
                width: parent.width
                height: 300
                spacing: 12

                Column {
                    width: 380
                    height: parent.height
                    spacing: 6

                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 6
                        color: root.bg
                        border.color: root.pillBorder
                        border.width: 1

                        TextInput {
                            id: search
                            anchors.fill: parent
                            anchors.margins: 7
                            font.family: root.mono
                            font.pixelSize: 12
                            color: root.ink
                            clip: true
                            onTextChanged: win.filter = text
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "filter models…"
                                visible: search.text === ""
                                font.family: root.mono
                                font.pixelSize: 12
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                            }
                        }
                    }

                    ListView {
                        width: parent.width
                        height: parent.height - 34
                        clip: true
                        model: win.shown
                        spacing: 2

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 34
                            radius: 5
                            color: modelData.id === win.selected
                                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)
                                : "transparent"

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 8

                                UiText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: parent.parent.modelData.id
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    color: parent.parent.modelData.id === win.selected ? root.seal : root.ink
                                }
                                UiText {
                                    text: parent.parent.modelData.free
                                        ? "free · " + parent.parent.modelData.context + " ctx"
                                        : "$" + parent.parent.modelData["in"] + "/$"
                                          + parent.parent.modelData["out"] + " per M · "
                                          + parent.parent.modelData.context + " ctx"
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.selected = parent.modelData.id
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 392
                    height: parent.height
                    radius: 6
                    color: root.bg
                    border.color: root.pillBorder
                    border.width: 1

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 10
                        contentHeight: replyText.implicitHeight
                        clip: true

                        UiText {
                            id: replyText
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: win.busy ? "…" : (win.reply === "" ? "response appears here" : win.reply)
                            font.family: root.mono
                            font.pixelSize: 12
                            color: win.reply === "" && !win.busy
                                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                                : root.ink
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 120
                radius: 6
                color: root.bg
                border.color: root.pillBorder
                border.width: 1

                TextEdit {
                    id: promptBox
                    anchors.fill: parent
                    anchors.margins: 9
                    font.family: root.mono
                    font.pixelSize: 12
                    color: root.ink
                    wrapMode: TextEdit.Wrap
                    clip: true

                    Keys.onPressed: function (event) {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && (event.modifiers & Qt.ControlModifier)) {
                            win.send(); event.accepted = true
                        }
                    }

                    UiText {
                        anchors.top: parent.top
                        text: "prompt — ctrl+enter to send"
                        visible: promptBox.text === ""
                        font.family: root.mono
                        font.pixelSize: 12
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                    }
                }
            }

            Row {
                spacing: 10

                UiText {
                    text: "→ " + win.selected
                    font.family: root.mono
                    font.pixelSize: 11
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                }
            }
        }
    }
}
