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

    // ── AI usage panel state + which tool the bar pill shows ──
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

    property string aiTool: "codex"   // "codex" or "opencode" — icon shown in the bar

    // ── AI usage data (single source of truth) ───────────────────
    // The bar pill (AiWidget) and the AiUsagePanel both render from these —
    // the cache parsing lives ONLY here so the two views can never drift apart.
    // Token strings are bare "X.XXM / Y.YM"; the pill tooltip appends " tokens".

    property bool   aiCxHas: false
    property bool   aiCxFresh: false
    property int    aiCxPct5h: 0
    property int    aiCxPct7d: 0
    property string aiCxPlan: ""
    property string aiCxTokens: ""
    property string aiCxRate: ""
    property int    aiCxReset5hTs: 0
    property int    aiCxReset7dTs: 0
    property int    aiCxToday: 0
    property var    aiCxBuckets: []
    property var    aiCxWindows: []
    property int    aiCxPrimaryPct: 0
    property string aiCxPrimaryLabel: ""
    property int    aiCxPrimaryResetTs: 0
    property int    aiCxQuotaPct: 0
    property string aiCxQuotaLabel: ""
    property string aiCxLimitStatus: ""
    property string aiCxLimitReachedType: ""

    property bool   aiOcHas: false
    property bool   aiOcFresh: false
    property int    aiOcPct5h: 0
    property int    aiOcPct7d: 0
    property string aiOcPlan: ""
    property string aiOcTokens: ""
    property string aiOcRate: ""
    property string aiOcModel: ""
    property int    aiOcToday: 0
    property var    aiOcModels: []
    property int    aiClockTick: 0

    // F15: clamp an external 0..1 utilization to a 0–100 int (a negative/over-range value would
    // otherwise produce wrong text and negative/overwide usage bars)
    function aiPct(v) { return Math.max(0, Math.min(100, Math.round((parseFloat(v) || 0) * 100))) }

    function aiWindowLabel(minutes) {
        if (minutes === 300) return "5h"
        if (minutes === 10080) return "Weekly"
        if (minutes > 0 && minutes % 1440 === 0) return (minutes / 1440) + "d"
        if (minutes > 0 && minutes % 60 === 0) return (minutes / 60) + "h"
        return minutes > 0 ? minutes + "m" : "window"
    }

    function aiResetCodexUsage() {
        aiCxHas = false; aiCxFresh = false
        aiCxPct5h = 0; aiCxPct7d = 0
        aiCxPlan = ""; aiCxTokens = ""; aiCxRate = ""; aiCxToday = 0
        aiCxReset5hTs = 0; aiCxReset7dTs = 0
        aiCxBuckets = []; aiCxWindows = []
        aiCxPrimaryPct = 0; aiCxPrimaryLabel = ""; aiCxPrimaryResetTs = 0
        aiCxQuotaPct = 0; aiCxQuotaLabel = ""
        aiCxLimitStatus = ""; aiCxLimitReachedType = ""
    }

    function aiCodexWindowFromCache(w) {
        w = w || {}
        var minutes = parseInt(w.minutes) || 0
        return {
            kind: String(w.kind || ""),
            minutes: minutes,
            label: String(w.label || theme.aiWindowLabel(minutes)),
            pct: theme.aiPct(w.utilization),
            resetTs: parseInt(w.reset) || 0
        }
    }

    function aiCodexWindowsFromArray(arr) {
        var out = []
        if (!arr || arr.length === undefined) return out
        for (var i = 0; i < arr.length; i++) {
            out.push(theme.aiCodexWindowFromCache(arr[i]))
        }
        return out
    }

    function aiCodexLegacyWindowsFromCache(d) {
        var out = []
        if (!d) return out
        var has5 = d["5h-utilization"] !== undefined && String(d["5h-utilization"]) !== ""
        var has7 = d["7d-utilization"] !== undefined && String(d["7d-utilization"]) !== ""
        if (has5 || parseInt(d["5h-reset"]) > 0)
            out.push({ kind: "primary", minutes: 300, label: "5h", pct: theme.aiPct(d["5h-utilization"]), resetTs: parseInt(d["5h-reset"]) || 0 })
        if (has7 || parseInt(d["7d-reset"]) > 0)
            out.push({ kind: "secondary", minutes: 10080, label: "Weekly", pct: theme.aiPct(d["7d-utilization"]), resetTs: parseInt(d["7d-reset"]) || 0 })
        return out
    }

    function aiCodexBucketsFromCache(d) {
        var buckets = []
        if (d && parseInt(d.schemaVersion) === 3 && d.buckets && d.buckets.length !== undefined) {
            for (var i = 0; i < d.buckets.length; i++) {
                var b = d.buckets[i] || {}
                var windows = theme.aiCodexWindowsFromArray(b.windows)
                if (windows.length === 0) continue
                buckets.push({
                    id: String(b.id || ""),
                    label: String(b.label || b.id || "Codex"),
                    isGeneral: b.isGeneral === true,
                    windows: windows,
                    plan: String(b.plan || ""),
                    rateLimitReachedType: String(b.rateLimitReachedType || "")
                })
            }
        } else if (d && parseInt(d.schemaVersion) === 2 && d.windows && d.windows.length !== undefined) {
            var win2 = theme.aiCodexWindowsFromArray(d.windows)
            if (win2.length > 0)
                buckets.push({ id: "codex", label: "Codex", isGeneral: true, windows: win2, plan: String(d._plan || "") })
        } else {
            var legacy = theme.aiCodexLegacyWindowsFromCache(d)
            if (legacy.length > 0)
                buckets.push({ id: "codex", label: "Codex", isGeneral: true, windows: legacy, plan: String((d && d._plan) || "") })
        }
        return buckets
    }

    function aiCodexGeneralBucket(buckets) {
        for (var i = 0; i < buckets.length; i++) {
            if (buckets[i].isGeneral === true || buckets[i].id === "codex") return buckets[i]
        }
        return { windows: [] }
    }

    function aiPlanLabel(plan) {
        var p = String(plan || "").toLowerCase()
        if (p === "prolite") return "Pro Lite"
        if (p === "pro") return "Pro"
        if (p === "plus") return "Plus"
        if (p === "team" || p === "business") return "Business"
        if (p === "enterprise") return "Enterprise"
        if (p === "edu") return "Edu"
        if (p === "free") return "Free"
        return String(plan || "")
    }

    function aiApplyCodexCache(d, ageOk) {
        var buckets = theme.aiCodexBucketsFromCache(d)
        var general = theme.aiCodexGeneralBucket(buckets)
        var windows = general.windows || []
        theme.aiCxHas = windows.length > 0
        theme.aiCxFresh = ageOk && d._source !== "stale"
        theme.aiCxBuckets = buckets
        theme.aiCxWindows = windows
        theme.aiCxPlan = theme.aiPlanLabel(d._plan || general.plan || "")
        theme.aiCxPct5h = 0; theme.aiCxPct7d = 0
        theme.aiCxReset5hTs = 0; theme.aiCxReset7dTs = 0
        theme.aiCxQuotaPct = 0
        theme.aiCxQuotaLabel = ""
        theme.aiCxLimitStatus = String(d.status || "")
        theme.aiCxLimitReachedType = String(d._limit_reached_type || general.rateLimitReachedType || "")
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i]
            if (i === 0) {
                theme.aiCxPrimaryPct = w.pct
                theme.aiCxPrimaryLabel = w.label
                theme.aiCxPrimaryResetTs = w.resetTs
            }
            if (w.minutes === 300) { theme.aiCxPct5h = w.pct; theme.aiCxReset5hTs = w.resetTs }
            else if (w.minutes === 10080) { theme.aiCxPct7d = w.pct; theme.aiCxReset7dTs = w.resetTs }
            if (w.pct > theme.aiCxQuotaPct) {
                theme.aiCxQuotaPct = w.pct
                theme.aiCxQuotaLabel = String(general.label || "Codex") + " " + String(w.label || "window")
            }
        }
        if (windows.length === 0) {
            theme.aiCxPrimaryPct = 0
            theme.aiCxPrimaryLabel = ""
            theme.aiCxPrimaryResetTs = 0
        }
        var cxRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
        theme.aiCxRate = cxRateH > 0 ? cxRateH + "k tok/h" : ""
        theme.aiCxToday = parseInt(d._today_tokens) || 0
        theme.aiCxTokens = ""
    }

    function aiCodexStatusLabel(status, reachedType) {
        if (status === "rejected")
            return reachedType ? "reached (" + reachedType + ")" : "reached"
        if (status === "allowed_warning") return "warning"
        if (status === "allowed") return "ok (not reached)"
        return "unknown"
    }

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

    Process {
        id: aiReadCodex
        command: ["bash", "-c",
            "f=\"$HOME/.cache/codex-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    theme.aiApplyCodexCache(d, ageOk)
                } catch (e) {
                    theme.aiResetCodexUsage()
                }
            }
        }
    }

    Process {
        id: aiReadOpenCode
        command: ["bash", "-c",
            "f=\"$HOME/.cache/opencode-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    theme.aiOcHas = true
                    theme.aiOcFresh = ageOk && d._source !== "stale"
                    theme.aiOcPct5h = theme.aiPct(d["5h-utilization"])
                    theme.aiOcPct7d = theme.aiPct(d["7d-utilization"])
                    theme.aiOcPlan = d._plan || ""
                    var ocUsed = (d["_tokens_used"] || 0), ocLim = (d["_window_limit"] || 0)
                    theme.aiOcTokens = ocUsed ? (ocUsed / 1e6).toFixed(2) + "M / " + (ocLim / 1e6).toFixed(1) + "M" : ""
                    var ocRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    theme.aiOcRate = ocRateH > 0 ? ocRateH + "k tok/h" : ""
                    theme.aiOcToday = parseInt(d._today_tokens) || 0
                    theme.aiOcModel = d._model || ""
                    theme.aiOcModels = d._models instanceof Array ? d._models : []
                } catch (e) {
                    theme.aiOcHas = false; theme.aiOcFresh = false
                    theme.aiOcPct5h = 0; theme.aiOcPct7d = 0
                    theme.aiOcPlan = ""; theme.aiOcTokens = ""; theme.aiOcRate = ""; theme.aiOcModel = ""
                    theme.aiOcToday = 0; theme.aiOcModels = []
                }
            }
        }
    }

    function refreshAiUsage(selectedOnly) {
        aiClockTick++
        var only = selectedOnly === true
        if (!only || aiTool === "codex") {
            aiReadCodex.running = false;  aiReadCodex.running = true
        }
        if (!only || aiTool === "opencode") {
            aiReadOpenCode.running = false; aiReadOpenCode.running = true
        }
    }

    Timer {
        // 30s normally; 5s while the AI panel is open (responsive when looked at)
        interval: theme.aiUsageVisible ? 5000 : 30000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: theme.refreshAiUsage(theme.aiUsageVisible)
    }
}
