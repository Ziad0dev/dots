pragma ComponentBehavior: Bound
// After lucid's calendar widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import qs.ext.colors
import qs.ext.modules.lock
import qs.ext.services as Services

// The month on the desktop: today ringed in the accent, a dot under every day
// with a calendar note (services/CalendarNotes, the bar calendar's notes), and
// today's notes underneath. The arrows or the wheel turn the month; the title
// brings it back to this one.
WidgetFrame {
    id: root

    property int monthOffset: 0
    readonly property date today: Services.Time.date
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    // weeks start on the locale's first day (Monday where the week does)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property int lead: (shown.getDay() - firstDay + 7) % 7
    readonly property var todayNotes: Services.CalendarNotes.notesFor(Services.CalendarNotes.dateKey(today))

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("calendar", themeId)
    seal: "暦"

    function cellDate(i) {
        return new Date(shown.getFullYear(), shown.getMonth(), 1 - lead + i);
    }

    Item {
        width: 7 * 34
        height: header.height

        Glyph {
            id: prev
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_left"
            font.pixelSize: 20
            color: prevArea.containsMouse ? root.accent : Colors.withAlpha(root.ink, 0.6)
            MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.monthOffset-- }
        }

        Text {
            id: header
            anchors.centerIn: parent
            text: WidgetStyle.label(root.shown.toLocaleDateString(Qt.locale(), "MMMM yyyy"), root.st)
            font.family: root.st.display
            font.pixelSize: 17
            font.capitalization: WidgetStyle.caps(root.st)
            color: root.ink
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.monthOffset = 0 }
        }

        Glyph {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_right"
            font.pixelSize: 20
            color: nextArea.containsMouse ? root.accent : Colors.withAlpha(root.ink, 0.6)
            MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.monthOffset++ }
        }
    }

    Grid {
        columns: 7
        columnSpacing: 0
        rowSpacing: 2

        // weekday initials, from the locale's first day
        Repeater {
            model: 7
            Text {
                required property int index
                width: 34
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                font.family: root.st.mono
                font.pixelSize: 11
                color: Colors.withAlpha(root.ink, 0.5)
            }
        }

        Repeater {
            model: 42
            Item {
                id: cell
                required property int index
                readonly property date day: root.cellDate(index)
                readonly property bool inMonth: day.getMonth() === root.shown.getMonth()
                readonly property bool isToday: day.toDateString() === root.today.toDateString()
                readonly property int notes: Services.CalendarNotes.countFor(Services.CalendarNotes.dateKey(day))
                width: 34
                height: 28

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    color: cell.isToday ? root.accent : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    font.family: root.st.mono
                    font.pixelSize: 13
                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                    color: cell.isToday ? Colors.on_primary : Colors.withAlpha(root.ink, cell.inMonth ? 0.92 : 0.3)
                }

                // a note on this day
                Rectangle {
                    visible: cell.notes > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 4
                    height: 4
                    radius: 2
                    color: cell.isToday ? Colors.on_primary : root.accent
                }
            }
        }
    }

    // the wheel turns the month (a touchpad's small scrolls add up to a notch)
    WheelHandler {
        property real acc: 0
        onWheel: (e) => {
            acc += e.angleDelta.y;
            while (Math.abs(acc) >= 120) {
                root.monthOffset += acc > 0 ? -1 : 1;
                acc -= acc > 0 ? 120 : -120;
            }
        }
    }

    // today's notes: the agenda
    Column {
        width: 7 * 34
        spacing: 3

        Text {
            text: root.todayNotes.length ? "Today" : "Nothing noted for today"
            font.family: root.st.font
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Colors.withAlpha(root.ink, 0.7)
        }

        Repeater {
            model: root.todayNotes.slice(0, 4)
            Text {
                required property var modelData
                width: 7 * 34
                elide: Text.ElideRight
                text: (modelData.time ? modelData.time + "  " : "• ") + modelData.text
                font.family: root.st.font
                font.pixelSize: 13
                color: root.ink
            }
        }
    }
}
