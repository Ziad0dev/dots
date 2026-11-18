pragma ComponentBehavior: Bound
// After lucid's At a Glance widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import qs.ext.colors
import qs.ext.modules.lock
import qs.ext.services as Services

// The day in three lines: the date, the next thing in today's calendar notes,
// and what's playing. Nothing it shows needs a fetch of its own.
WidgetFrame {
    id: root

    readonly property date now: Services.Time.date
    readonly property var notes: Services.CalendarNotes.notesFor(Services.CalendarNotes.dateKey(now))
    // the next timed note still to come, else the first untimed one
    readonly property var next: {
        const hhmm = now.toLocaleTimeString(Qt.locale("C"), "HH:mm");
        const timed = notes.filter(n => n.time && n.time >= hhmm).sort((a, b) => a.time < b.time ? -1 : 1);
        return timed[0] ?? notes.find(n => !n.time) ?? null;
    }
    readonly property bool playing: Services.Media.isPlaying

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: ""
    seal: "瞥"

    Text {
        text: root.now.toLocaleDateString(Qt.locale(), "dddd d MMMM")
        font.family: root.st.display
        font.pixelSize: 24
        color: root.ink
    }

    Repeater {
        model: [
            { icon: "event", text: root.next ? (root.next.time ? root.next.time + "  " : "") + root.next.text : "Nothing else today", on: true },
            { icon: "music_note", text: Services.Media.title + (Services.Media.artist ? " · " + Services.Media.artist : ""), on: root.playing }
        ]
        Row {
            required property var modelData
            visible: modelData.on
            spacing: 8
            Glyph {
                text: parent.modelData.icon
                font.pixelSize: 17
                color: root.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 300
                elide: Text.ElideRight
                text: parent.modelData.text
                font.family: root.st.font
                font.pixelSize: 14
                color: root.ink
            }
        }
    }
}
