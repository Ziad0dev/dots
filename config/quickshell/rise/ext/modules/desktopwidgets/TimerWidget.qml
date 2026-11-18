pragma ComponentBehavior: Bound
// After lucid's timer widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import Quickshell.Io
import qs.ext.colors
import qs.ext.modules.lock
import qs.ext.services as Services

// A countdown, a pomodoro (work and break in turn) or a stopwatch. The wheel
// over the time sets a countdown's minutes while it is stopped; the end of a
// countdown or of a pomodoro stretch sends a notification.
WidgetFrame {
    id: root

    property string mode: "timer"          // "timer" | "pomodoro" | "stopwatch"
    property int minutes: 10               // the countdown's length
    property bool running: false
    property bool onBreak: false           // pomodoro: in the break
    property int rounds: 0                 // pomodoro: work stretches finished
    property real elapsed: 0               // seconds counted so far
    property real startedAt: 0             // ms, while running
    readonly property int pomodoroWork: 25
    readonly property int pomodoroBreak: 5
    readonly property real total: mode === "timer" ? minutes * 60
                                : mode === "pomodoro" ? (onBreak ? pomodoroBreak : pomodoroWork) * 60
                                : 0

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("timer", themeId)
    seal: "刻"

    function fmt(s) {
        s = Math.floor(s);
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
        const two = (n) => (n < 10 ? "0" : "") + n;
        return (h > 0 ? h + ":" + two(m) : two(m)) + ":" + two(sec);
    }
    function setMode(m) {
        mode = m;
        reset();
    }
    function toggle() {
        if (running) {
            elapsed += (Date.now() - startedAt) / 1000;
            running = false;
        } else {
            startedAt = Date.now();
            running = true;
        }
    }
    function reset() {
        running = false;
        elapsed = 0;
        onBreak = false;
        rounds = 0;
    }
    function notify(text) {
        notifier.command = ["notify-send", "-a", "Timer", "-i", "alarm", text];
        notifier.running = false;
        notifier.running = true;
    }

    Process { id: notifier }

    // ticks only while running; the time comes from the clock, not from
    // counting ticks, so a busy moment can't make it drift
    Timer {
        interval: 250
        running: root.running
        repeat: true
        onTriggered: {
            const now = (Date.now() - root.startedAt) / 1000;
            if (root.mode === "stopwatch" || root.elapsed + now < root.total)
                return;
            if (root.mode === "timer") {
                root.running = false;
                root.elapsed = root.total;
                root.notify("Time's up: " + root.minutes + " min");
            } else {
                // pomodoro: the next stretch starts on its own
                if (!root.onBreak)
                    root.rounds++;
                root.notify(root.onBreak ? "Break over: back to work" : "Work stretch done: take " + root.pomodoroBreak + " min");
                root.onBreak = !root.onBreak;
                root.elapsed = 0;
                root.startedAt = Date.now();
            }
        }
    }
    // shows the running time; the state above only changes on start, pause and the end
    property real tick: 0
    Timer {
        interval: 200
        running: root.running
        repeat: true
        onTriggered: root.tick = (Date.now() - root.startedAt) / 1000
    }
    readonly property real live: running ? elapsed + tick : elapsed
    readonly property real liveShown: mode === "stopwatch" ? live : Math.max(0, total - live)
    onRunningChanged: tick = 0

    // the modes
    Row {
        spacing: 6
        Repeater {
            model: [{ id: "timer", name: "Timer" }, { id: "pomodoro", name: "Pomodoro" }, { id: "stopwatch", name: "Stopwatch" }]
            Rectangle {
                id: pill
                required property var modelData
                readonly property bool on: root.mode === modelData.id
                width: pillText.implicitWidth + 16
                height: 24
                radius: 12
                color: on ? root.accent : Colors.withAlpha(root.ink, pillArea.containsMouse ? 0.14 : 0.07)
                Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: pill.modelData.name
                    font.family: root.st.font
                    font.pixelSize: 12
                    color: pill.on ? Colors.on_primary : root.ink
                }
                MouseArea { id: pillArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setMode(pill.modelData.id) }
            }
        }
    }

    Item {
        width: 230
        height: 76

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(root.liveShown)
            font.family: root.st.mono
            font.pixelSize: 40
            font.weight: Font.Light
            color: root.ink

            // the wheel sets a stopped countdown's minutes
            WheelHandler {
                enabled: root.mode === "timer" && !root.running && root.elapsed === 0
                property real acc: 0
                onWheel: (e) => {
                    acc += e.angleDelta.y;
                    while (Math.abs(acc) >= 120) {
                        root.minutes = Math.max(1, Math.min(180, root.minutes + (acc > 0 ? 1 : -1)));
                        acc -= acc > 0 ? 120 : -120;
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            visible: root.mode === "pomodoro"
            text: (root.onBreak ? "Break" : "Work") + " · " + root.rounds + " done"
            font.family: root.st.font
            font.pixelSize: 12
            color: Colors.withAlpha(root.ink, 0.7)
        }
    }

    // a countdown's quick lengths
    Row {
        visible: root.mode === "timer"
        spacing: 6
        Repeater {
            model: [5, 10, 15, 25, 45, 60]
            Text {
                required property int modelData
                text: modelData + "m"
                font.family: root.st.mono
                font.pixelSize: 12
                color: root.minutes === modelData ? root.accent : Colors.withAlpha(root.ink, presetArea.containsMouse ? 0.9 : 0.55)
                MouseArea {
                    id: presetArea
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.minutes = parent.modelData; root.reset(); }
                }
            }
        }
    }

    Row {
        spacing: 14
        Repeater {
            model: [
                { icon: root.running ? "pause" : "play_arrow", act: "toggle" },
                { icon: "restart_alt", act: "reset" }
            ]
            Glyph {
                id: button
                required property var modelData
                text: modelData.icon
                font.pixelSize: 26
                color: buttonArea.containsMouse ? root.accent : root.ink
                MouseArea {
                    id: buttonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: button.modelData.act === "toggle" ? root.toggle() : root.reset()
                }
            }
        }
    }
}
