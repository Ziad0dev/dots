pragma Singleton
pragma ComponentBehavior: Bound
// Ported from dhrruvsharma/shell (quickshell/services/DesktopWidgets.qml), GPL-3.0-or-later.
import Quickshell
import Quickshell.Io
import QtQuick

// Desktop widgets (modules/desktopwidgets): which are on and where they sit.
// A position is stored as a fraction of the free space on the screen
// (0 = left/top edge, 1 = right/bottom edge), so widgets stay on screen and
// keep their place across resolutions. The visualizer keeps its own settings
// (services/CavaWidget.qml); here it is only listed and switched.
//
// Settings: ~/.config/quickshell/desktopwidgets.json.
Singleton {
    id: root

    // rise: the screen the widgets (and the visualizer) live on: rise's bar
    // monitor (ExtRoot sets screenName from theme.barMonitor), else the first.
    property string screenName: ""
    readonly property var screen: Quickshell.screens.find(s => s.name === screenName) ?? Quickshell.screens[0] ?? null

    readonly property var widgets: [
        { id: "clock", name: "Clock", icon: "schedule", description: "The theme's own clock face", x: 0.03, y: 0.08 },
        { id: "music", name: "Music player", icon: "music_note", description: "Now playing, with controls", x: 0.97, y: 0.08 },
        { id: "sysmon", name: "System monitor", icon: "monitoring", description: "CPU, memory, temperature and disk", x: 0.97, y: 0.52 },
        { id: "quote", name: "Quote", icon: "format_quote", description: "A line from the grimoire's quotes every ten minutes", x: 0.97, y: 0.98 }, // rise: bottom-left is the desk clock's
        { id: "cava", name: "Visualizer", icon: "graphic_eq", description: "Cava spectrum of what's playing" }
    ]

    readonly property var defaults: ({ clock: true, music: true, sysmon: true, quote: true })

    function info(id) {
        return widgets.find(w => w.id === id);
    }

    function enabled(id) {
        if (id === "cava")
            return CavaWidget.enabled;
        const v = adapter.on[id];
        return v === undefined ? (defaults[id] ?? false) : v;
    }

    function setEnabled(id, on) {
        if (id === "cava") {
            CavaWidget.enabled = on;
            CavaWidget.save();
            return;
        }
        const next = Object.assign({}, adapter.on);
        next[id] = on;
        adapter.on = next;
    }

    function toggle(id) {
        setEnabled(id, !enabled(id));
    }

    // { x, y } fractions.
    function pos(id) {
        const p = adapter.positions[id];
        const w = info(id);
        return p ? p : { x: w ? w.x : 0, y: w ? w.y : 0 };
    }

    function setPos(id, x, y) {
        const next = Object.assign({}, adapter.positions);
        next[id] = { x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y)) };
        adapter.positions = next;
    }

    function resetPositions() {
        adapter.positions = ({});
        CavaWidget.posX = 40;
        CavaWidget.posY = 880;
        CavaWidget.save();
    }

    // ── Quotes (the quote widget), read only while it's on ──────────────────
    property string joke: ""

    function refreshJoke() {
        jokeProc.running = true;
    }

    Timer {
        interval: 10 * 60 * 1000
        running: root.enabled("quote")
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshJoke()
    }

    // rise: a line from rise's own quotes.txt (occult and gothic, "text |
    // author"), not a dad joke from icanhazdadjoke.com.
    Process {
        id: jokeProc
        command: ["sh", "-c", "grep -v '^#' \"$1\" | grep . | shuf -n 1", "sh", Quickshell.shellPath("quotes.txt")]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t)
                    return;
                const bar = t.lastIndexOf("|");
                root.joke = bar > 0 ? t.substring(0, bar).trim() + "\n— " + t.substring(bar + 1).trim() : t;
            }
        }
    }

    // ── Settings ─────────────────────────────────────────────────────────────
    Timer {
        id: writeTimer
        interval: 150
        onTriggered: settingsFile.writeAdapter()
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.local/state/dots/shell/ext/desktopwidgets.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeTimer.restart()

        adapter: JsonAdapter {
            id: adapter
            property var on: ({})
            property var positions: ({})
        }
    }
}
