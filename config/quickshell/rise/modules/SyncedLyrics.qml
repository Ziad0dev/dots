import QtQuick
import Quickshell.Io

// Time-synced lyrics from LRCLIB (lrclib.net, open, no account). Only fetches
// while `active` (the media panel is open); answers — including "none" (404) —
// are cached in ~/.cache/dots-lyrics, network errors are not, so they retry.
// Tries the exact /api/get first, then /api/search. Hidden when no synced
// lyrics exist for the track.
Item {
    id: lyr

    required property var root
    property bool active: false
    property string title: ""
    property string artist: ""
    property string album: ""
    property real length: 0          // seconds
    property real position: 0        // seconds
    property int visibleLines: 5
    property real lead: 0.25         // seconds: show a line slightly before it's sung

    property var lines: []           // [{ t: seconds, text }]
    readonly property bool hasLyrics: lines.length > 0
    readonly property string trackKey: artist + "\u001f" + title + "\u001f" + album + "\u001f" + Math.round(length)
    property string loadedKey: ""

    readonly property int current: {
        var t = position + lead, lo = 0, hi = lines.length - 1, best = -1
        while (lo <= hi) {
            var mid = (lo + hi) >> 1
            if (lines[mid].t <= t) { best = mid; lo = mid + 1 } else hi = mid - 1
        }
        return best
    }

    readonly property int lineH: 20
    implicitHeight: hasLyrics ? visibleLines * lineH : 0
    Behavior on implicitHeight { Anim { kind: "size"; ms: 300 } }
    visible: hasLyrics
    clip: true

    function parseLrc(text) {
        var out = [], rows = String(text || "").split("\n")
        var stamp = /\[(\d+):(\d+(?:\.\d+)?)\]/g
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i], words = row.replace(/\[[^\]]*\]/g, "").trim(), m
            stamp.lastIndex = 0
            while ((m = stamp.exec(row)) !== null)
                out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: words })
        }
        out.sort(function (a, b) { return a.t - b.t })
        return out
    }

    function pickSynced(json) {
        var d = null
        try { d = JSON.parse(json) } catch (e) { return "" }
        if (Array.isArray(d)) {
            for (var i = 0; i < d.length; i++) if (d[i] && d[i].syncedLyrics) return d[i].syncedLyrics
            return ""
        }
        return d && d.syncedLyrics ? d.syncedLyrics : ""
    }

    function maybeFetch() {
        if (!active || title === "" || trackKey === loadedKey) return
        loadedKey = trackKey
        lines = []
        fetchProc.running = false
        fetchProc.command = ["bash", "-c", fetchScript, "_", artist, title, album, String(Math.round(length))]
        fetchProc.running = true
    }
    onActiveChanged: maybeFetch()
    onTrackKeyChanged: maybeFetch()

    // $1 artist  $2 title  $3 album  $4 duration (s). Prints the cached JSON.
    readonly property string fetchScript:
        "d=\"${XDG_CACHE_HOME:-$HOME/.cache}/dots-lyrics\"; mkdir -p \"$d\"; " +
        "f=\"$d/$(printf '%s|%s|%s|%s' \"$1\" \"$2\" \"$3\" \"$4\" | md5sum | cut -d' ' -f1).json\"; " +
        "ua='dots-rise (https://github.com/Ziad0dev/dots)'; " +
        "get() { curl -sS -m 8 -A \"$ua\" -o \"$f.tmp\" -w '%{http_code}' -G \"$@\"; }; " +
        "if [ ! -e \"$f\" ]; then " +
        "  args=(--data-urlencode \"artist_name=$1\" --data-urlencode \"track_name=$2\"); " +
        "  [ -n \"$3\" ] && args+=(--data-urlencode \"album_name=$3\"); " +
        "  [ \"$4\" -gt 0 ] 2>/dev/null && args+=(--data-urlencode \"duration=$4\"); " +
        "  code=$(get https://lrclib.net/api/get \"${args[@]}\"); " +
        "  if [ \"$code\" = 404 ]; then " +
        "    code=$(get https://lrclib.net/api/search --data-urlencode \"artist_name=$1\" --data-urlencode \"track_name=$2\"); fi; " +
        "  case \"$code\" in 200) mv \"$f.tmp\" \"$f\" ;; 404) printf '{}' > \"$f\"; rm -f \"$f.tmp\" ;; *) rm -f \"$f.tmp\" ;; esac; " +
        "fi; " +
        "[ -e \"$f\" ] && cat \"$f\""

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: lyr.lines = lyr.parseLrc(lyr.pickSynced(this.text))
        }
        // nothing printed (network error): allow a retry on the next open
        onExited: function (code) { if (lyr.lines.length === 0 && code !== 0) lyr.loadedKey = "" }
    }

    Column {
        id: list
        width: parent.width
        // keep the current line in the middle row
        y: (lyr.visibleLines >> 1) * lyr.lineH - Math.max(0, lyr.current) * lyr.lineH
        Behavior on y { Anim { kind: "spatial" } }

        Repeater {
            model: lyr.lines
            delegate: Text {
                required property var modelData
                required property int index
                readonly property int dist: Math.abs(index - lyr.current)
                width: list.width
                height: lyr.lineH
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: modelData.text === "" ? "♪" : modelData.text
                color: index === lyr.current ? lyr.root.ink : lyr.root.sumi
                opacity: index === lyr.current ? 1 : Math.max(0.15, 0.6 - 0.18 * dist)
                font.family: lyr.root.mono
                font.pixelSize: index === lyr.current ? 12 : 11
                font.weight: index === lyr.current ? Font.Medium : Font.Normal
                Behavior on opacity { Anim { kind: "effects"; ms: 220 } }
                Behavior on color { CAnim { ms: 220 } }
            }
        }
    }
}
