pragma ComponentBehavior: Bound
// After lucid's to-do widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import Quickshell
import QtCore
import qs.ext.colors
import qs.ext.modules.lock
import qs.ext.services as Services

// A checklist: type a task and press Enter, tick it off, clear the ticked
// ones. Saved to ~/.local/state/dots/shell/ext/desk_todo.conf.
WidgetFrame {
    id: root

    property var items: []          // [{ text, done }]

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("todo", themeId)
    seal: "務"

    Settings {
        id: store
        location: "file://" + Quickshell.env("HOME") + "/.local/state/dots/shell/ext/desk_todo.conf"
        category: "todo"
        property string data: "[]"
        onDataChanged: {
            try {
                root.items = JSON.parse(data) || [];
            } catch (e) {
                root.items = [];
            }
        }
    }

    function save(list) {
        items = list;
        store.data = JSON.stringify(list);
    }
    function add(text) {
        text = text.trim();
        if (text !== "")
            save(items.concat([{ text: text, done: false }]));
    }
    function toggle(i) {
        const next = items.slice();
        next[i] = { text: next[i].text, done: !next[i].done };
        save(next);
    }
    function clearDone() {
        save(items.filter(t => !t.done));
    }

    Repeater {
        model: root.items
        Row {
            id: task
            required property var modelData
            required property int index
            spacing: 8
            Glyph {
                text: task.modelData.done ? "check_box" : "check_box_outline_blank"
                font.pixelSize: 19
                color: task.modelData.done ? root.accent : Colors.withAlpha(root.ink, 0.7)
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle(task.index) }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 250
                elide: Text.ElideRight
                text: task.modelData.text
                font.family: root.st.font
                font.pixelSize: 14
                font.strikeout: task.modelData.done
                color: Colors.withAlpha(root.ink, task.modelData.done ? 0.45 : 1)
            }
        }
    }

    Rectangle {
        width: 280
        height: 30
        radius: 8
        color: Colors.withAlpha(root.ink, field.activeFocus ? 0.08 : 0.04)
        TextInput {
            id: field
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: root.st.font
            font.pixelSize: 14
            color: root.ink
            clip: true
            onAccepted: { root.add(text); text = ""; }
            Text {
                visible: field.text === "" && !field.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                text: "Add a task…"
                font: field.font
                color: Colors.withAlpha(root.ink, 0.4)
            }
        }
    }

    Text {
        visible: root.items.some(t => t.done)
        text: "Clear done"
        font.family: root.st.font
        font.pixelSize: 12
        color: clearArea.containsMouse ? root.accent : Colors.withAlpha(root.ink, 0.55)
        MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearDone() }
    }
}
