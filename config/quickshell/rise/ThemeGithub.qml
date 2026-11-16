import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "modules"
import "Palette.js" as Palette

// Part of Theme (see Theme.qml): GitHub inbox: shared parse of scripts/github-inbox for pill + panel.
// Same object as `theme` — split into an inheritance chain only for size;
// every property/function here is still read as theme.<name>.
ThemeTelemetry {
    id: theme

    // ── GitHub inbox ──
    // One shared parse of the script's JSON, read by the bar pill and the panel
    // so the two views can never drift apart (same contract as the ai* block).
    // Resolved from this file's own location, so the repo works from any checkout
    // path (dots.repoPath) rather than a hardcoded ~/dots.
    readonly property string ghScriptPath:
        Qt.resolvedUrl("scripts/github-inbox").toString().replace(/^file:\/\//, "")
    readonly property string ghCachePath: Quickshell.env("HOME") + "/.cache/dots-github-inbox.json"
    readonly property string ghSeenPath: Quickshell.env("HOME") + "/.cache/quickshell_github_seen"

    property var    ghFeed: ({})
    property var    ghSeen: ({})
    property double ghFetchedMs: 0

    readonly property string ghUser: String(ghFeed.user || "")
    readonly property string ghError: String(ghFeed.error || "")
    readonly property var ghPrs: ghFeed.prs || []
    readonly property var ghReviews: ghFeed.reviews || []
    readonly property var ghIssues: ghFeed.issues || []
    readonly property var ghMentions: ghFeed.mentions || []
    readonly property var ghNotifications: ghFeed.notifications || []
    readonly property var ghClosed: ghFeed.closed || []
    readonly property int ghWorkCount: ghPrs.length + ghReviews.length + ghIssues.length
    readonly property int ghNotifCount: ghNotifications.length
    readonly property int ghUnreadMentions: {
        var n = 0
        for (var i = 0; i < ghMentions.length; i++) if (ghMentionUnread(ghMentions[i])) n++
        return n
    }

    // GitHub has no per-mention read state, so it lives here: url -> updatedAt at
    // the moment it was opened. New activity on the thread re-dots it.
    function ghMentionUnread(m) {
        if (!m || m.notifUnread !== true) return false
        var seenAt = ghSeen[String(m.url || "")]
        return !seenAt || String(m.updatedAt || "") > String(seenAt)
    }

    function ghMarkSeen(item) {
        if (!item) return
        var next = {}
        for (var i = 0; i < ghMentions.length; i++) {
            var url = String(ghMentions[i].url || "")
            if (ghSeen[url]) next[url] = ghSeen[url]
        }
        next[String(item.url || "")] = String(item.updatedAt || "")
        ghSeen = next
        ghSeenSaveProc.command = ["bash", "-c", "cat > \"$1\"", "_", ghSeenPath]
        ghSeenSaveProc.running = false
        ghSeenSaveProc.running = true
        ghSeenSaveProc.write(JSON.stringify(next))
        ghMarkThreadRead(item.threadId)
    }

    function ghMarkThreadRead(threadId) {
        if (!threadId) return
        ghMarkProc.command = [ghScriptPath, "--mark-read", String(threadId)]
        ghMarkProc.running = false
        ghMarkProc.running = true
    }

    // Drop the row now and mark the thread read in the background — waiting for
    // the next refresh would leave a read notification sitting in the panel.
    function ghDismissNotification(item) {
        if (!item) return
        var remaining = []
        for (var i = 0; i < ghNotifications.length; i++)
            if (ghNotifications[i] !== item) remaining.push(ghNotifications[i])
        var next = {}
        for (var k in ghFeed) next[k] = ghFeed[k]
        next.notifications = remaining
        ghFeed = next
        ghMarkThreadRead(item.threadId)
    }

    // Rows are click-to-open and the script already drops anything that is not
    // github.com; re-check here so a stale cache cannot outlive that filter.
    function ghOpen(item) {
        var url = String((item && item.url) || "")
        if (url.indexOf("https://github.com/") !== 0) return
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect",
                                 "--", "xdg-open", url])
        githubVisible = false
    }

    function ghFetchedAgo() {
        if (ghFetchedMs <= 0) return ""
        var s = Math.max(0, Math.round((Date.now() - ghFetchedMs) / 1000))
        if (s < 90) return s + "s ago"
        var m = Math.round(s / 60)
        if (m < 90) return m + "m ago"
        return Math.round(m / 60) + "h ago"
    }

    function refreshGithub(force) {
        if (force === true) ghFetchProc.command = ["bash", "-c",
            "rm -f \"$1\"; exec \"$2\"", "_", ghCachePath, ghScriptPath]
        else ghFetchProc.command = [ghScriptPath]
        ghFetchProc.running = false
        ghFetchProc.running = true
    }

    Process { id: ghMarkProc }
    Process { id: ghSeenSaveProc }

    Process {
        id: ghFetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim()
                if (!t) return
                try {
                    var parsed = JSON.parse(t)
                    if (parsed && typeof parsed === "object") {
                        theme.ghFeed = parsed
                        theme.ghFetchedMs = Date.now()
                    }
                } catch (e) {
                    theme.ghFeed = { error: "unreadable response from github-inbox" }
                }
            }
        }
    }

    Process {
        id: ghSeenLoadProc
        command: ["cat", theme.ghSeenPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim()
                if (!t) return
                try {
                    var parsed = JSON.parse(t)
                    if (parsed && typeof parsed === "object") theme.ghSeen = parsed
                } catch (e) { }
            }
        }
    }

    Timer {
        // 5min normally; 60s while the panel is open. The script keeps its own
        // 60s disk cache, so extra ticks collapse instead of hitting the API.
        interval: theme.githubVisible ? 60000 : 300000
        running: theme.modGithub || theme.githubVisible
        repeat: true; triggeredOnStart: true
        onTriggered: theme.refreshGithub()
    }
}
