import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "modules"
import "Palette.js" as Palette

// Part of Theme (see Theme.qml): AI usage: panel state + the single source of usage data.
// Same object as `theme` — split into an inheritance chain only for size;
// every property/function here is still read as theme.<name>.
ThemeGithub {
    id: theme

    // ── AI usage panel state ──
    property bool   aiUsageVisible: false
    onAiUsageVisibleChanged: {
        popupOpened("aiUsageVisible")
        if (aiUsageVisible) refreshAiUsage()
    }
    property bool   githubVisible: false
    onGithubVisibleChanged: {
        popupOpened("githubVisible")
        if (githubVisible) refreshGithub()
    }

    // ── AI usage data (single source of truth) ───────────────────
    // The bar pill (AiWidget) and the AiUsagePanel both render from these —
    // the cache parsing lives ONLY here so the two views can never drift apart.
    // Token strings are bare "X.XXM / Y.YM"; the pill tooltip appends " tokens".

    property bool   aiClHas: false
    property int    aiClPct5h: 0
    property int    aiClPct7d: 0
    property bool   aiClBlocked: false
    property string aiClTokens: ""
    property string aiClRate: ""
    property int    aiClReset5hTs: 0
    property int    aiClReset7dTs: 0
    property int    aiClToday: 0

    property int    aiClockTick: 0

    // F15: clamp an external 0..1 utilization to a 0–100 int (a negative/over-range value would
    // otherwise produce wrong text and negative/overwide usage bars)
    function aiPct(v) { return Math.max(0, Math.min(100, Math.round((parseFloat(v) || 0) * 100))) }

    function aiFmtReset(ts) {
        aiClockTick
        var now = Date.now() / 1000
        if (!(ts > now)) return ""
        var mins = Math.round((ts - now) / 60)
        if (mins < 60) return mins + "m"
        var h = Math.floor(mins / 60), m = mins % 60
        if (h < 24) return h + "h " + m + "m"
        var d = Math.floor(h / 24); return d + "d " + (h % 24) + "h"
    }

    function aiPad2(n) { return n < 10 ? "0" + n : "" + n }

    function aiFmtResetClock(ts) {
        aiClockTick
        if (!(ts > Date.now() / 1000)) return ""
        var d = new Date(ts * 1000)
        var now = new Date()
        var day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        var resetDay0 = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
        var dayDelta = Math.round((resetDay0 - day0) / 86400000)
        var time = aiPad2(d.getHours()) + ":" + aiPad2(d.getMinutes())
        if (dayDelta <= 0) return time
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[d.getDay()] + " " + time
    }

    function aiFmtResetDetail(ts) {
        var rel = aiFmtReset(ts)
        var clock = aiFmtResetClock(ts)
        return rel && clock ? rel + " • " + clock : (rel || clock)
    }

    // Fresh = written by a successful fetch in the last 15 min. The script marks a
    // failed fetch "stale" and keeps the old _written_at, so age keeps counting.
    property string aiClSource: ""
    property int    aiClWrittenAt: 0
    readonly property bool aiClFresh: {
        aiClockTick
        return aiClHas && aiClSource !== "stale"
            && aiClWrittenAt > 0 && (Date.now() / 1000 - aiClWrittenAt) < 900
    }

    function aiClReset() {
        aiClHas = false; aiClSource = ""; aiClWrittenAt = 0
        aiClPct5h = 0; aiClPct7d = 0
        aiClBlocked = false; aiClTokens = ""; aiClRate = ""
        aiClReset5hTs = 0; aiClReset7dTs = 0; aiClToday = 0
    }

    // dots-ai-usage.timer rewrites this file (write-then-rename) every 10 min;
    // the watch picks that up, so nothing has to poll it
    FileView {
        id: aiClaudeFile
        path: Quickshell.env("HOME") + "/.cache/claude-usage.json"
        watchChanges: true
        printErrors: false
        onFileChanged: aiClaudeFile.reload()
        onLoadFailed: theme.aiClReset()
        onLoaded: {
            try {
                var d = JSON.parse(aiClaudeFile.text().trim())
                theme.aiClHas = true
                theme.aiClSource = String(d._source || "")
                theme.aiClWrittenAt = parseInt(d._written_at) || 0
                theme.aiClPct5h = theme.aiPct(d["5h-utilization"])
                theme.aiClPct7d = theme.aiPct(d["7d-utilization"])
                theme.aiClBlocked = d.status === "rejected" || d.status === "blocked"
                theme.aiClReset5hTs = parseInt(d["5h-reset"]) || 0
                theme.aiClReset7dTs = parseInt(d["7d-reset"]) || 0
                var used = (d["_tokens_used"] || 0), lim = (d["_window_limit"] || 0)
                theme.aiClTokens = used ? (used / 1e6).toFixed(2) + "M / " + (lim / 1e6).toFixed(1) + "M" : ""
                var rateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                theme.aiClRate = rateH > 0 ? rateH + "k tok/h" : ""
                theme.aiClToday = parseInt(d._today_tokens) || 0
            } catch (e) {
                theme.aiClReset()
            }
        }
    }

    function refreshAiUsage() {
        aiClockTick++
        aiClaudeFile.reload()
    }

    Timer {
        // no process spawn: ticks the reset countdowns / freshness and re-reads the
        // file in case a watch event was missed
        interval: 60000
        running: true; repeat: true
        onTriggered: theme.refreshAiUsage()
    }
}
