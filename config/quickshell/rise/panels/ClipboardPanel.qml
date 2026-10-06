import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// cliphist browser, styled after AppLauncher. Enter/click copies the entry
// back to the clipboard, Delete removes it, the wipe button (pressed twice)
// clears the history. Images get thumbnails decoded into $XDG_RUNTIME_DIR.
PanelWindow {
    id: win
    required property var root

    visible: root.clipboardVisible
    screen: root.activePopupScreen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-clipboard"
    WlrLayershell.keyboardFocus: root.clipboardVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }

    property var items: []          // [{line, id, text, image, ext}]
    property int sel: 0
    property string query: ""
    property bool loading: false
    property bool confirmWipe: false
    property int thumbTick: 0       // bumps when thumbnails land, to reload Images

    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-clip"
    readonly property var imageRe: /^\[\[ binary data .* (png|jpe?g|gif|webp|bmp) (\d+x\d+) \]\]$/

    readonly property color island: Qt.rgba(
        root.paper.r + (root.ink.r - root.paper.r) * 0.07,
        root.paper.g + (root.ink.g - root.paper.g) * 0.07,
        root.paper.b + (root.ink.b - root.paper.b) * 0.07, 1.0)

    readonly property var shown: {
        var q = query.trim().toLowerCase()
        if (q === "") return items
        return items.filter(function(it) { return it.text.toLowerCase().indexOf(q) >= 0 })
    }
    onShownChanged: sel = Math.min(sel, Math.max(0, shown.length - 1))

    function close() {
        root.clipboardVisible = false
        confirmWipe = false
    }

    function reload() {
        loading = true
        listProc.running = false
        listProc.running = true
    }

    function parse(text) {
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            var tab = line.indexOf("\t")
            if (tab <= 0) continue
            var preview = line.slice(tab + 1)
            var m = preview.match(imageRe)
            out.push({
                line: line,
                id: line.slice(0, tab),
                text: m ? "image · " + m[1] + " · " + m[2] : preview,
                image: m !== null,
                ext: m ? (m[1] === "jpg" ? "jpeg" : m[1]) : ""
            })
        }
        return out
    }

    function thumbPath(it) { return thumbDir + "/" + it.id + "." + it.ext }

    function copy(it) {
        if (!it) return
        actionProc.command = ["bash", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "_", it.line]
        actionProc.running = false
        actionProc.running = true
        close()
    }

    function remove(it) {
        if (!it) return
        actionProc.command = ["bash", "-c", "printf '%s\\n' \"$1\" | cliphist delete; rm -f \"$2\"", "_", it.line,
                              it.image ? thumbPath(it) : ""]
        actionProc.running = false
        actionProc.running = true
        items = items.filter(function(x) { return x.id !== it.id })
    }

    function wipe() {
        if (!confirmWipe) {
            confirmWipe = true
            wipeConfirmTimer.restart()
            return
        }
        confirmWipe = false
        actionProc.command = ["bash", "-c", "cliphist wipe; rm -rf \"$1\"", "_", thumbDir]
        actionProc.running = false
        actionProc.running = true
        items = []
    }

    function move(d) {
        var n = shown.length
        if (n === 0) return
        sel = (sel + d + n) % n
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.items = win.parse(this.text)
                win.loading = false
                win.sel = 0
                thumbProc.running = false
                thumbProc.running = true
            }
        }
    }

    // decode the newest image entries that don't have a thumbnail yet
    Process {
        id: thumbProc
        command: ["bash", "-c",
            "dir=$1; shift; mkdir -p \"$dir\" && chmod 700 \"$dir\"; " +
            "while [ $# -ge 3 ]; do [ -s \"$dir/$2.$3\" ] || printf '%s\\n' \"$1\" | cliphist decode > \"$dir/$2.$3\"; shift 3; done",
            "_", win.thumbDir].concat(win.thumbArgs())
        onExited: win.thumbTick++
    }
    function thumbArgs() {
        var args = []
        var n = 0
        for (var i = 0; i < items.length && n < 40; i++) {
            if (!items[i].image) continue
            args.push(items[i].line, items[i].id, items[i].ext)
            n++
        }
        return args
    }

    Process { id: actionProc; command: ["true"] }
    Timer { id: wipeConfirmTimer; interval: 3000; onTriggered: win.confirmWipe = false }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(720, win.width - 80)
        height: Math.min(560, win.height - 120)
        radius: 12
        color: root.paper
        border.width: 1
        border.color: root.sep

        MouseArea { anchors.fill: parent }

        Rectangle {
            id: field
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            height: 42
            radius: 6
            color: win.island
            border.width: 1
            border.color: root.sep

            IconText {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: ""   // content_paste
                font.pixelSize: 18
                color: root.sumiHi
            }

            TextInput {
                id: input
                anchors {
                    left: parent.left; leftMargin: 40
                    right: wipeButton.left; rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                color: root.ink
                font.family: root.mono
                font.pixelSize: 14
                selectByMouse: true
                selectionColor: root.seal
                clip: true
                onTextChanged: win.query = text

                Text {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: win.loading ? "loading clipboard history…" : "search clipboard · " + win.items.length + " entries"
                    font: input.font
                    color: root.sumiHi
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onPressed: function (e) {
                    var it = win.shown[win.sel]
                    if (e.key === Qt.Key_Escape) { win.close(); e.accepted = true }
                    else if (e.key === Qt.Key_Down || (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier))) { win.move(1); e.accepted = true }
                    else if (e.key === Qt.Key_Up || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))) { win.move(-1); e.accepted = true }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.copy(it); e.accepted = true }
                    else if (e.key === Qt.Key_Delete) { win.remove(it); e.accepted = true }
                    else if (e.key === Qt.Key_PageDown) { win.move(8); e.accepted = true }
                    else if (e.key === Qt.Key_PageUp) { win.move(-8); e.accepted = true }
                }
            }

            Rectangle {
                id: wipeButton
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: wipeLabel.implicitWidth + 18
                height: 26
                radius: root.tileRadius
                visible: win.items.length > 0
                color: win.confirmWipe ? Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.18)
                     : wipeMa.containsMouse ? root.fillHover : "transparent"
                border.color: win.confirmWipe || wipeMa.containsMouse ? root.sealRaw : root.sep
                border.width: 1
                UiText {
                    id: wipeLabel
                    anchors.centerIn: parent
                    text: win.confirmWipe ? "confirm wipe" : "wipe"
                    color: win.confirmWipe ? root.sealRaw : root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 10
                }
                MouseArea {
                    id: wipeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.wipe()
                }
            }
        }

        ListView {
            id: list
            anchors {
                top: field.bottom; topMargin: 8
                left: parent.left; right: parent.right; bottom: hint.top
                leftMargin: 8; rightMargin: 8; bottomMargin: 6
            }
            clip: true
            model: win.shown
            currentIndex: win.sel
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                width: list.width
                height: modelData.image ? 76 : 40
                radius: 6
                color: index === win.sel ? win.island : "transparent"
                Behavior on color { CAnim { ms: 120 } }

                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 3
                    height: parent.height - 16
                    radius: 2
                    color: root.seal
                    visible: index === win.sel
                }

                Rectangle {
                    id: thumbBox
                    visible: modelData.image
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    width: 96
                    height: 60
                    radius: 4
                    color: root.fillIdle
                    clip: true
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 192
                        source: modelData.image ? "file://" + win.thumbPath(modelData) + "?" + win.thumbTick : ""
                    }
                }

                Text {
                    anchors {
                        left: modelData.image ? thumbBox.right : parent.left
                        leftMargin: 14
                        right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: modelData.text
                    textFormat: Text.PlainText
                    color: modelData.image ? root.sumiHi : root.ink
                    font.family: root.mono
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onEntered: win.sel = index
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.MiddleButton) win.remove(modelData)
                        else win.copy(modelData)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: list
            visible: !win.loading && win.shown.length === 0
            text: win.items.length === 0 ? "clipboard history is empty" : "no matches"
            color: root.sumiHi
            font.family: root.mono
            font.pixelSize: 12
        }

        UiText {
            id: hint
            anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
            text: "enter copy · del / middle-click remove · esc close"
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
            font.family: root.mono
            font.pixelSize: 10
        }
    }

    onVisibleChanged: {
        if (visible) {
            input.text = ""
            input.forceActiveFocus()
            sel = 0
            reload()
        }
    }
}
