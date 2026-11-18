pragma ComponentBehavior: Bound
// After lucid's network widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import Quickshell.Io
import qs.ext.colors
import qs.ext.modules.lock
import qs.ext.services as Services

// Download and upload speed, summed over the physical interfaces in
// /proc/net/dev every two seconds, with the last minute as a line each.
WidgetFrame {
    id: root

    property real lastRx: -1
    property real lastTx: -1
    property real lastAt: 0
    property real down: 0              // bytes per second
    property real up: 0
    property var downHist: []
    property var upHist: []

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("network", themeId)
    seal: "网"

    function rate(b) {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"];
        let i = 0;
        while (b >= 1000 && i < units.length - 1) { b /= 1000; i++; }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + " " + units[i];
    }
    function sample(text) {
        let rx = 0, tx = 0;
        for (const line of String(text).split("\n").slice(2)) {
            const m = line.trim().match(/^([^:]+):\s*(.*)$/);
            if (!m) continue;
            // only real interfaces: not loopback, bridges, VPN or container links
            if (/^(lo|docker|br-|veth|virbr|tailscale|wg|tun|podman)/.test(m[1])) continue;
            const f = m[2].trim().split(/\s+/);
            rx += Number(f[0]);
            tx += Number(f[8]);
        }
        const now = Date.now();
        if (lastRx >= 0 && now > lastAt) {
            const s = (now - lastAt) / 1000;
            down = Math.max(0, (rx - lastRx) / s);
            up = Math.max(0, (tx - lastTx) / s);
            downHist = downHist.slice(-29).concat([down]);
            upHist = upHist.slice(-29).concat([up]);
            graph.requestPaint();
        }
        lastRx = rx; lastTx = tx; lastAt = now;
    }

    FileView {
        id: dev
        path: "/proc/net/dev"
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { dev.reload(); root.sample(dev.text()); }
    }

    Row {
        spacing: 22
        Repeater {
            model: [{ icon: "download", v: root.down }, { icon: "upload", v: root.up }]
            Row {
                required property var modelData
                spacing: 6
                Glyph {
                    text: parent.modelData.icon
                    font.pixelSize: 18
                    color: root.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.rate(parent.modelData.v)
                    font.family: root.st.mono
                    font.pixelSize: 15
                    color: root.ink
                }
            }
        }
    }

    Canvas {
        id: graph
        width: 260
        height: 44
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const top = Math.max(1, ...root.downHist, ...root.upHist);
            const line = (hist, colour) => {
                if (hist.length < 2) return;
                ctx.strokeStyle = colour;
                ctx.lineWidth = 1.6;
                ctx.beginPath();
                hist.forEach((v, i) => {
                    const x = width - (hist.length - 1 - i) * (width / 29), y = height - 2 - v / top * (height - 4);
                    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                });
                ctx.stroke();
            };
            line(root.downHist, root.accent);
            line(root.upHist, Colors.withAlpha(root.ink, 0.5));
        }
    }
}
