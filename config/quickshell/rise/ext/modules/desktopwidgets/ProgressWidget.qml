pragma ComponentBehavior: Bound
// After lucid's progress widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import qs.ext.colors
import qs.ext.services as Services

// How much of the day, the week, the month and the year has gone, as rings.
// Worked out once a minute: nothing on it moves faster than that.
WidgetFrame {
    id: root

    property date now: new Date()
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property var parts: {
        const n = now;
        const day = (n.getHours() * 3600 + n.getMinutes() * 60 + n.getSeconds()) / 86400;
        const week = (((n.getDay() - firstDay + 7) % 7) + day) / 7;
        const inMonth = new Date(n.getFullYear(), n.getMonth() + 1, 0).getDate();
        const month = (n.getDate() - 1 + day) / inMonth;
        const start = new Date(n.getFullYear(), 0, 1);
        const inYear = (new Date(n.getFullYear() + 1, 0, 1) - start) / 86400000;
        const year = ((n - start) / 86400000) / inYear;
        return [
            { name: "Day", value: day },
            { name: "Week", value: week },
            { name: "Month", value: month },
            { name: "Year", value: year }
        ];
    }

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("progress", themeId)
    seal: "時"

    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Row {
        spacing: 14

        Repeater {
            model: root.parts

            Column {
                id: ring
                required property var modelData
                spacing: 4

                Item {
                    width: 62
                    height: 62

                    Canvas {
                        id: arc
                        anchors.fill: parent
                        readonly property real value: ring.modelData.value
                        onValueChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const c = width / 2, r = c - 5;
                            ctx.lineWidth = 6;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = Colors.withAlpha(root.ink, 0.12);
                            ctx.beginPath();
                            ctx.arc(c, c, r, 0, 2 * Math.PI);
                            ctx.stroke();
                            ctx.strokeStyle = root.accent;
                            ctx.beginPath();
                            const end = 2 * Math.PI * Math.max(0.005, value);
                            if (root.st.frame === "tonal") {
                                // the expressive look: the gone part as a wave
                                for (let t = 0; t <= end; t += 0.02) {
                                    const rr = r + 1.8 * Math.sin(t * 14), a = t - Math.PI / 2;
                                    t === 0 ? ctx.moveTo(c + rr * Math.cos(a), c + rr * Math.sin(a)) : ctx.lineTo(c + rr * Math.cos(a), c + rr * Math.sin(a));
                                }
                            } else {
                                ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + end);
                            }
                            ctx.stroke();
                        }
                        Component.onCompleted: requestPaint()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Math.floor(ring.modelData.value * 100) + "%"
                        font.family: root.st.mono
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: root.ink
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: WidgetStyle.label(ring.modelData.name, root.st)
                    font.family: root.st.font
                    font.pixelSize: 12
                    font.capitalization: WidgetStyle.caps(root.st)
                    color: Colors.withAlpha(root.ink, 0.7)
                }
            }
        }
    }
}
