import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: win
    required property var root

    visible: root.launcherVisible
    screen: root.activePopupScreen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-launcher"
    WlrLayershell.keyboardFocus: root.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }

    property int sel: 0
    property string query: ""

    readonly property var entries: {
        var all = []
        var vals = DesktopEntries.applications.values
        for (var i = 0; i < vals.length; i++) if (vals[i].name) all.push(vals[i])
        all.sort(function (a, b) { return a.name.localeCompare(b.name) })

        var q = query.trim().toLowerCase()
        if (q === "") return all

        var scored = []
        for (var j = 0; j < all.length; j++) {
            var d = all[j]
            var name = (d.name || "").toLowerCase()
            var gen = (d.genericName || "").toLowerCase()
            var com = (d.comment || "").toLowerCase()
            var kw = (d.keywords || []).join(" ").toLowerCase()
            var cat = (d.categories || []).join(" ").toLowerCase()
            var s = -1
            if (name.indexOf(q) === 0) s = 0
            else if (name.indexOf(q) >= 0) s = 1
            else if (gen.indexOf(q) >= 0) s = 2
            else if (kw.indexOf(q) >= 0) s = 3
            else if (com.indexOf(q) >= 0 || cat.indexOf(q) >= 0) s = 4
            if (s >= 0) scored.push({ e: d, s: s })
        }
        scored.sort(function (a, b) {
            if (a.s !== b.s) return a.s - b.s
            return a.e.name.localeCompare(b.e.name)
        })
        var out = []
        for (var k = 0; k < scored.length; k++) out.push(scored[k].e)
        return out
    }

    onEntriesChanged: sel = 0

    function close() {
        root.launcherVisible = false
        query = ""
        sel = 0
    }

    function launch() {
        if (sel < 0 || sel >= entries.length) return
        entries[sel].execute()
        close()
    }

    function move(d) {
        var n = entries.length
        if (n === 0) return
        sel = (sel + d + n) % n
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(720, win.width - 80)
        height: Math.min(560, win.height - 120)
        radius: 14
        color: root.paper
        border.width: 1
        border.color: root.sep

        MouseArea { anchors.fill: parent }

        Rectangle {
            id: field
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            height: 44
            radius: 9
            color: root.frameWeak
            border.width: 1
            border.color: root.sep

            Text {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                text: "\u2315"
                font.family: root.mono
                font.pixelSize: 17
                color: root.sumiHi
            }

            TextInput {
                id: input
                anchors {
                    left: parent.left; leftMargin: 40
                    right: parent.right; rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                color: root.ink
                font.family: root.mono
                font.pixelSize: 15
                selectByMouse: true
                selectionColor: root.seal
                clip: true
                onTextChanged: win.query = text

                Text {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: "search applications"
                    font: input.font
                    color: root.sumiHi
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onPressed: function (e) {
                    if (e.key === Qt.Key_Escape) { win.close(); e.accepted = true }
                    else if (e.key === Qt.Key_Down || (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier))) { win.move(1); e.accepted = true }
                    else if (e.key === Qt.Key_Up || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))) { win.move(-1); e.accepted = true }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.launch(); e.accepted = true }
                    else if (e.key === Qt.Key_PageDown) { win.move(8); e.accepted = true }
                    else if (e.key === Qt.Key_PageUp) { win.move(-8); e.accepted = true }
                }
            }
        }

        ListView {
            id: list
            anchors {
                top: field.bottom; topMargin: 8
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 8; rightMargin: 8; bottomMargin: 10
            }
            clip: true
            model: win.entries
            currentIndex: win.sel
            highlightMoveDuration: 90
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                required property int index
                required property var modelData
                width: list.width
                height: 52
                radius: 8
                color: index === win.sel ? root.frameWeak : "transparent"

                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 3
                    height: parent.height - 18
                    radius: 2
                    color: root.seal
                    visible: index === win.sel
                }

                IconImage {
                    id: ico
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    implicitSize: 30
                    source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                    visible: source !== ""
                }

                Column {
                    anchors {
                        left: parent.left; leftMargin: 58
                        right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        width: parent.width
                        text: modelData.name || ""
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.comment || modelData.genericName || ""
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.sel = index
                    onClicked: { win.sel = index; win.launch() }
                }
            }
        }

        Text {
            anchors.centerIn: list
            visible: win.entries.length === 0
            text: "no matches"
            color: root.sumiHi
            font.family: root.mono
            font.pixelSize: 13
        }
    }

    onVisibleChanged: {
        if (visible) {
            input.text = ""
            input.forceActiveFocus()
            sel = 0
        }
    }
}
