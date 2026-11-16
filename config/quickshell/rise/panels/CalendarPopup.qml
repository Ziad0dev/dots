import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import qs.ext.services as Ext

PanelWindow {
    id: calPopup
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-calendar"

    readonly property int barBottom: 35
    readonly property int gap: 8

    // ── day notes (ext CalendarNotes, from dhrruvsharma/shell) ──
    // The selected day can be in any month: selOffset is its month's offset.
    property int selOffset: 0
    Timer { id: noteFocus; interval: 120; onTriggered: noteInput.forceActiveFocus() }
    function dayKey(offset, day) {
        const now = new Date()
        return Ext.CalendarNotes.dateKey(new Date(now.getFullYear(), now.getMonth() + offset, day))
    }
    readonly property string selKey: root.selectedDay > 0 ? dayKey(selOffset, root.selectedDay) : ""
    readonly property var selNotes: {
        Ext.CalendarNotes.notesByDate
        return selKey ? Ext.CalendarNotes.notesFor(selKey) : []
    }
    readonly property string selLabel: {
        if (!selKey) return ""
        const p = selKey.split("-")
        const d = new Date(+p[0], +p[1] - 1, +p[2])
        return d.toLocaleDateString(Qt.locale(), "dddd d MMMM")
    }
    Connections {
        target: calPopup.root
        function onCalendarVisibleChanged() {
            if (!calPopup.root.calendarVisible) return
            calPopup.selOffset = 0
            noteInput.text = ""
            // the bar popout opens it without picking a day: today
            if (calPopup.root.selectedDay <= 0) calPopup.root.selectedDay = (new Date()).getDate()
            if (!calPopup.root.popout.hoverMode) noteFocus.restart()
        }
    }

    property real reveal: root.calendarVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: "effects" }
    }
    visible: reveal > 0.001
        || (root.popout.last === "calendarVisible" && root.popout.shown)
    WlrLayershell.keyboardFocus: root.calendarVisible && !root.popout.hoverMode
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        readonly property bool hover: calPopup.root.popout.hoverMode
        readonly property int gap: calPopup.root.popout.gap
        x: hover ? popClip.x : 0
        y: hover ? popClip.y - (calPopup.root.popout.barOnTop ? gap : 0) : 0
        width: hover ? popClip.width : calPopup.width
        height: hover ? popClip.height + gap : calPopup.height
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarVisible = false
    }

    PopoutClip {
        id: popClip
        root: calPopup.root
        flag: "calendarVisible"
        card: card
        Rectangle {
            id: card
            width: 280
            height: col.implicitHeight + 24
            radius: reveal > 0.001 ? root.pillRadius : 0
            color: "transparent"
            border.color: root.pillBorder
            border.width: 0

            x: popClip.cardX
            y: popClip.cardY
            opacity: calPopup.reveal
            focus: root.calendarVisible

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.calendarVisible = false;
                    event.accepted = true;
                }
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: col
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // ── header: month name + navigation chevrons ──
                Item {
                    width: parent.width
                    height: 24

                    // ‹ previous month
                    Rectangle {
                        id: prevBtn
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: root.tileRadius
                        color: "transparent"
                        UiText {
                            anchors.centerIn: parent
                            text: "‹"   // ‹
                            color: prevMa.containsMouse ? root.seal : root.sumi
                            font.family: root.mono; font.pixelSize: 16
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.calendarMonthOffset--
                        }
                    }

                    // month + year — click to jump back to today
                    UiText {
                        anchors.centerIn: parent
                        text: root.calendarMonthName + "  " + root.calendarYear
                        color: monthMa.containsMouse && root.calendarMonthOffset !== 0 ? root.seal : root.ink
                        font.family: root.mono
                        font.pixelSize: 12
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                        MouseArea {
                            id: monthMa
                            anchors.fill: parent; anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: root.calendarMonthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.calendarMonthOffset = 0
                        }
                    }

                    // › next month
                    Rectangle {
                        id: nextBtn
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: root.tileRadius
                        color: "transparent"
                        UiText {
                            anchors.centerIn: parent
                            text: "›"   // ›
                            color: nextMa.containsMouse ? root.seal : root.sumi
                            font.family: root.mono; font.pixelSize: 16
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.calendarMonthOffset++
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.sep }

                // ── weekday headers ──
                Row {
                    width: parent.width
                    Repeater {
                        model: ["MO","TU","WE","TH","FR","SA","SU"]
                        delegate: Item {
                            required property string modelData
                            required property int index
                            width: parent.width / 7
                            height: 20
                            UiText {
                                anchors.centerIn: parent
                                text: modelData
                                color: index >= 5 ? root.seal : root.inkDeep
                                opacity: index >= 5 ? 0.85 : 0.7
                                font.family: root.mono
                                font.pixelSize: 10
                                font.letterSpacing: 2
                            }
                        }
                    }
                }

                // ── day grid ──
                Grid {
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 0
                    width: parent.width
                    Repeater {
                        model: root.calendarCells
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: parent.width / 7
                            height: 28

                            readonly property int dayOfWeek: index % 7
                            readonly property bool isCurrentMonth: modelData.day !== 0
                            readonly property bool isToday: modelData.today
                            readonly property bool isSelected: isCurrentMonth && root.selectedDay === modelData.day && root.calendarMonthOffset === calPopup.selOffset
                            readonly property int noteCount: {
                                Ext.CalendarNotes.notesByDate
                                return isCurrentMonth ? Ext.CalendarNotes.countFor(calPopup.dayKey(root.calendarMonthOffset, modelData.day)) : 0
                            }

                            readonly property color textColor: {
                                if (isToday) return root.seal.hsvValue < 0.5 ? root.ink : root.paper;
                                if (!isCurrentMonth) return root.inkDeep;
                                return dayOfWeek >= 5 ? root.seal : root.ink;
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 24; height: 24; radius: 12
                                color: root.seal
                                visible: isToday
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 24; height: 24; radius: 12
                                border.color: root.seal; border.width: 1
                                color: "transparent"
                                visible: isSelected && !isToday
                            }

                            UiText {
                                anchors.centerIn: parent
                                text: modelData.day === 0 ? "" : modelData.day
                                color: textColor
                                opacity: isCurrentMonth ? 1.0 : 0.35
                                font.family: root.mono
                                font.pixelSize: 12
                                font.weight: isToday ? Font.Medium : Font.Light
                            }

                            // a day with notes
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -1
                                width: 4; height: 4; radius: 2
                                color: isToday ? root.ink : root.seal
                                visible: noteCount > 0
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: isCurrentMonth
                                enabled: isCurrentMonth
                                cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    calPopup.selOffset = root.calendarMonthOffset
                                    root.selectedDay = modelData.day
                                }
                            }
                        }
                    }
                }

                // ── notes for the selected day ──
                Rectangle { width: parent.width; height: 1; color: root.sep; visible: calPopup.selKey !== "" }

                Item {
                    width: parent.width
                    height: 16
                    visible: calPopup.selKey !== ""
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: calPopup.selLabel
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: calPopup.selNotes.length > 0 ? calPopup.selNotes.length + (calPopup.selNotes.length === 1 ? " note" : " notes") : ""
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }

                Repeater {
                    model: calPopup.selNotes
                    delegate: Item {
                        id: noteRow
                        required property var modelData
                        width: col.width
                        height: Math.max(20, noteText.implicitHeight + 4)
                        UiText {
                            id: noteText
                            anchors { left: parent.left; right: repeatBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: "⸸ " + noteRow.modelData.text
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                        UiText {
                            id: repeatBtn
                            anchors { right: delBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: "↻"
                            color: noteRow.modelData.repeat === "yearly" ? root.seal : repMa.containsMouse ? root.ink : root.sumi
                            font.pixelSize: 12
                            MouseArea {
                                id: repMa
                                anchors.fill: parent; anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ext.CalendarNotes.toggleRepeat(noteRow.modelData.id)
                            }
                        }
                        UiText {
                            id: delBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: "✕"
                            color: delMa.containsMouse ? root.seal : root.sumi
                            font.pixelSize: 10
                            MouseArea {
                                id: delMa
                                anchors.fill: parent; anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ext.CalendarNotes.remove(noteRow.modelData.id)
                            }
                        }
                    }
                }

                // add a note (Enter; Shift+Enter: every year on this day)
                Rectangle {
                    width: parent.width
                    height: 26
                    radius: root.tileRadius
                    visible: calPopup.selKey !== "" && !root.popout.hoverMode
                    color: root.fillIdle
                    border.width: 1
                    border.color: noteInput.activeFocus ? root.seal : root.sep
                    TextInput {
                        id: noteInput
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 11
                        selectByMouse: true
                        selectionColor: root.seal
                        clip: true
                        Keys.onReturnPressed: function (e) {
                            Ext.CalendarNotes.add(calPopup.selKey, text, (e.modifiers & Qt.ShiftModifier) !== 0)
                            text = ""
                        }
                        Keys.onEnterPressed: function (e) {
                            Ext.CalendarNotes.add(calPopup.selKey, text, (e.modifiers & Qt.ShiftModifier) !== 0)
                            text = ""
                        }
                        Keys.onEscapePressed: root.calendarVisible = false
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: noteInput.text === ""
                            text: "add a note · ⇧⏎ yearly"
                            color: root.sumi
                            font: noteInput.font
                        }
                    }
                }
            }
        }
    }
}
