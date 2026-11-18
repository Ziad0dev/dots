pragma ComponentBehavior: Bound
// After lucid's clock widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import qs.ext.colors

// The expressive clock: a scalloped dial (a Material 3 "cookie") on a tonal
// card, round-ended hands, a dot for each hour, and the day on a chip.
// Repaints once a minute, when `now` changes.
Item {
    id: root

    property date now: new Date()
    readonly property color plate: Colors.withAlpha(Qt.tint(Colors.surface_container_high, Colors.withAlpha(Colors.primary, 0.12)), 0.94)
    readonly property color dial: Qt.tint(Colors.surface_container_highest, Colors.withAlpha(Colors.primary, 0.28))

    implicitWidth: 210
    implicitHeight: 210

    Rectangle {
        anchors.fill: parent
        radius: 36
        color: root.plate
    }

    Canvas {
        id: face
        anchors.fill: parent
        anchors.margins: 14
        readonly property real minutes: root.now.getHours() * 60 + root.now.getMinutes()
        onMinutesChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2, R = c - 2;

            // the cookie: twelve soft scallops around the rim
            ctx.fillStyle = root.dial;
            ctx.beginPath();
            for (let i = 0; i <= 360; i++) {
                const a = i * Math.PI / 180;
                const r = R * (0.93 + 0.07 * Math.cos(12 * a));
                const x = c + r * Math.cos(a), y = c + r * Math.sin(a);
                i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.fill();

            // a dot per hour, the quarters larger
            for (let h = 0; h < 12; h++) {
                const a = h * Math.PI / 6 - Math.PI / 2;
                const r = R * 0.74;
                ctx.fillStyle = Colors.withAlpha(Colors.on_surface, h % 3 === 0 ? 0.85 : 0.4);
                ctx.beginPath();
                ctx.arc(c + r * Math.cos(a), c + r * Math.sin(a), h % 3 === 0 ? 4 : 2.5, 0, 2 * Math.PI);
                ctx.fill();
            }

            const hand = (angle, length, widthPx, colour) => {
                ctx.strokeStyle = colour;
                ctx.lineWidth = widthPx;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(c, c);
                ctx.lineTo(c + length * Math.cos(angle), c + length * Math.sin(angle));
                ctx.stroke();
            };
            const m = minutes % 60, h12 = (minutes / 60) % 12;
            hand(h12 * Math.PI / 6 - Math.PI / 2, R * 0.42, 9, Colors.on_surface);
            hand(m * Math.PI / 30 - Math.PI / 2, R * 0.62, 6, Colors.primary);

            ctx.fillStyle = Colors.primary;
            ctx.beginPath();
            ctx.arc(c, c, 6, 0, 2 * Math.PI);
            ctx.fill();
        }
        Component.onCompleted: requestPaint()
    }

    // the day, on an accent chip under the centre
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 46
        width: day.implicitWidth + 16
        height: 22
        radius: 11
        color: Colors.primary

        Text {
            id: day
            anchors.centerIn: parent
            text: root.now.toLocaleDateString(Qt.locale(), "ddd d")
            font.family: "Google Sans Flex"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Colors.on_primary
        }
    }
}
