pragma ComponentBehavior: Bound
// After lucid's notes widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import Quickshell
import QtCore
import qs.ext.colors
import qs.ext.services as Services

// A sticky note: click into it and type. Saved as you go (a second after the
// last key) to ~/.local/state/dots/shell/ext/desk_note.conf.
WidgetFrame {
    id: root

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("note", themeId)
    seal: "記"

    Settings {
        id: store
        location: "file://" + Quickshell.env("HOME") + "/.local/state/dots/shell/ext/desk_note.conf"
        category: "note"
        property string text: ""
    }

    Timer {
        id: saveLater
        interval: 1000
        onTriggered: store.text = edit.text
    }

    Rectangle {
        width: 300
        height: Math.max(120, edit.contentHeight + 16)
        radius: 8
        color: Colors.withAlpha(root.ink, edit.activeFocus ? 0.08 : 0.04)
        border.width: edit.activeFocus ? 1 : 0
        border.color: Colors.withAlpha(root.accent, 0.6)

        TextEdit {
            id: edit
            anchors.fill: parent
            anchors.margins: 8
            text: store.text
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            font.family: root.st.font
            font.pixelSize: 15
            color: root.ink
            selectionColor: Colors.withAlpha(root.accent, 0.4)
            onTextChanged: saveLater.restart()
            // the store loads after the first frame: take its text then
            Connections {
                target: store
                function onTextChanged() {
                    if (!edit.activeFocus && edit.text !== store.text)
                        edit.text = store.text;
                }
            }

            Text {
                visible: edit.text === "" && !edit.activeFocus
                text: "Click to write a note"
                font: edit.font
                color: Colors.withAlpha(root.ink, 0.4)
            }
        }
    }
}
