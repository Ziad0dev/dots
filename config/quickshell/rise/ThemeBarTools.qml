import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "modules"

// Part of Theme (see Theme.qml): state for the Omarchy-style bar tools, ported
// in spirit from Omarchy 4.5's shell (basecamp/omarchy, MIT): Tailscale,
// world clock ("Elsewhen"), reminders, a cached-sudo warning and a remote
// session indicator. Same object as `theme`; every property here is read as
// theme.<name> by the widgets and panels.
ThemeTelemetry {
    id: theme

    // outside text (host names, reminder text) shown in the shared tooltip,
    // which auto-detects rich text: escape it so it stays plain
    function plain(s) {
        return String(s === undefined || s === null ? "" : s)
            .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    readonly property string barToolsStateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/dots"

    // ── popout flags (hosted by PopoutMorph) ──
    property bool tailscaleVisible: false
    onTailscaleVisibleChanged: { popupOpened("tailscaleVisible"); if (tailscaleVisible) refreshTailscale() }
    property bool worldClockVisible: false
    onWorldClockVisibleChanged: { popupOpened("worldClockVisible"); if (worldClockVisible) refreshZoneOffsets() }
    property bool reminderVisible: false
    onReminderVisibleChanged: { popupOpened("reminderVisible"); if (reminderVisible) refreshReminders() }
    property bool layoutVisible: false
    onLayoutVisibleChanged: popupOpened("layoutVisible")

    // ── workspace layouts (Omarchy 4.5; scripts/dots-layout.sh applies them
    // through config/hypr/lib/workspace_modes.lua) ──
    // `default=<mode>` and `<ws>=<mode>` lines, written by dots-layout
    property string wsLayoutDefault: "dwindle"
    property var wsLayouts: ({})
    readonly property int wsLayoutWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    readonly property string wsLayoutCurrent: wsLayoutOf(wsLayoutWorkspace)
    readonly property var wsLayoutModes: ["dwindle", "scrolling", "floating"]
    function wsLayoutOf(id) {
        return (id >= 1 && wsLayouts[String(id)]) || wsLayoutDefault
    }
    function wsLayoutLabel(mode) {
        return mode === "scrolling" ? "Scrolling" : mode === "floating" ? "Floating" : "Tiling"
    }
    function wsLayoutIcon(mode) {
        return mode === "scrolling" ? "view_column" : mode === "floating" ? "filter_none" : "view_quilt"
    }
    // the script names tiling by what people call it
    function wsLayoutArg(mode) { return mode === "dwindle" ? "tiling" : mode }
    function setWsLayout(mode) {
        if (wsLayoutWorkspace >= 1)
            Quickshell.execDetached(["dots-layout", "set", wsLayoutArg(mode), String(wsLayoutWorkspace)])
    }
    function setDefaultWsLayout(mode) {
        Quickshell.execDetached(["dots-layout", "default", wsLayoutArg(mode)])
    }
    FileView {
        path: theme.barToolsStateDir + "/workspace-layouts"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var modes = {}, def = "dwindle"
            String(text()).split("\n").forEach(function (line) {
                var m = /^\s*(default|[1-9][0-9]*)\s*=\s*(dwindle|scrolling|floating)\s*$/.exec(line)
                if (!m) return
                if (m[1] === "default") def = m[2]
                else modes[m[1]] = m[2]
            })
            theme.wsLayoutDefault = def
            theme.wsLayouts = modes
        }
        // deleted (every workspace back on the default): the defaults again
        onLoadFailed: { theme.wsLayoutDefault = "dwindle"; theme.wsLayouts = ({}) }
    }

    // ── Tailscale ──
    property var tsStatus: ({})
    property bool tsBusy: false
    property string tsError: ""
    property bool _tsWantUp: true
    readonly property string tsState: String(tsStatus.BackendState || "")
    readonly property bool tsAvailable: tsState !== ""
    readonly property bool tsUp: tsState === "Running"
    readonly property var tsSelf: tsStatus.Self || ({})
    readonly property var tsPeers: {
        var peers = []
        var map = tsStatus.Peer || {}
        for (var k in map) peers.push(map[k])
        peers.sort(function (a, b) {
            if (!!a.Online !== !!b.Online) return a.Online ? -1 : 1
            return String(a.HostName || "").localeCompare(String(b.HostName || ""))
        })
        return peers
    }
    function refreshTailscale() { if (!tsProc.running) tsProc.running = true }
    function setTailscale(up) {
        if (tsToggleProc.running) return
        tsBusy = true
        _tsWantUp = up
        tsError = ""
        // root oneshots the user may start (polkit, modules/media.nix); the
        // user isn't the Tailscale operator, which would allow serve/funnel too
        tsToggleProc.command = ["systemctl", "start", up ? "tailscale-connect.service" : "tailscale-disconnect.service"]
        tsToggleProc.running = true
    }
    // the DNS name without the tailnet's trailing dot
    function tsName(node) { return String((node && node.DNSName) || "").replace(/\.$/, "") }

    Process {
        id: tsProc
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { theme.tsStatus = JSON.parse(this.text) } catch (e) { theme.tsStatus = ({}) }
            }
        }
    }
    Process {
        id: tsToggleProc
        onExited: function (code) {
            theme.tsBusy = false
            // the unit's own error (e.g. tailscale up wanting its old flags) is in its journal
            theme.tsError = code === 0 ? ""
                : "Tailscale " + (theme._tsWantUp ? "up" : "down") + " failed: journalctl -u tailscale-"
                  + (theme._tsWantUp ? "connect" : "disconnect")
            theme.refreshTailscale()
        }
    }
    Timer {
        interval: theme.tailscaleVisible ? 5000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.refreshTailscale()
    }

    // ── world clock ──
    // One IANA zone per line in ~/.local/state/dots/worldclock. Offsets come
    // from `date` (dots-bar-tools tz), so DST follows the system's tzdata.
    readonly property var wcDefaultZones: ["America/Los_Angeles", "America/New_York", "Europe/London", "Asia/Tokyo"]
    property var wcZones: []
    property var wcOffsets: ({})          // zone -> minutes east of UTC
    property string wcAddError: ""
    property var _wcQueue: []             // zones waiting to be validated
    property bool _wcRefreshAgain: false

    FileView {
        id: wcFile
        path: theme.barToolsStateDir + "/worldclock"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var zones = String(text()).split("\n").map(function (s) { return s.trim() })
                .filter(function (s) { return s !== "" && s[0] !== "#" })
            theme.wcZones = zones
            theme.refreshZoneOffsets()
        }
        onLoadFailed: { theme.wcZones = theme.wcDefaultZones; theme.refreshZoneOffsets() }
    }
    function wcSave(zones) {
        wcZones = zones
        wcFile.setText(zones.join("\n") + "\n")
        refreshZoneOffsets()
    }
    function wcAdd(zone) {
        zone = String(zone || "").trim().replace(/ /g, "_")
        if (zone === "" || wcZones.indexOf(zone) >= 0 || _wcQueue.indexOf(zone) >= 0) return
        wcAddError = ""
        _wcQueue = _wcQueue.concat([zone])
        _wcCheckNext()
    }
    function _wcCheckNext() {
        if (wcCheckProc.running || _wcQueue.length === 0) return
        wcCheckProc.command = ["dots-bar-tools", "tz", _wcQueue[0]]
        wcCheckProc.running = true
    }
    function wcRemove(zone) { wcSave(wcZones.filter(function (z) { return z !== zone })) }
    function refreshZoneOffsets() {
        if (wcZones.length === 0) return
        if (wcTzProc.running) { _wcRefreshAgain = true; return }
        wcTzProc.command = ["dots-bar-tools", "tz"].concat(wcZones)
        wcTzProc.running = true
    }
    // "+0530" -> 330
    function _wcMinutes(s) {
        var m = /^([+-])(\d\d)(\d\d)$/.exec(s)
        if (!m) return null
        var v = parseInt(m[2], 10) * 60 + parseInt(m[3], 10)
        return m[1] === "-" ? -v : v
    }
    Process {
        id: wcTzProc
        stdout: StdioCollector {
            onStreamFinished: {
                var next = {}
                String(this.text).split("\n").forEach(function (line) {
                    var p = line.split(" ")
                    var mins = theme._wcMinutes(p[1] || "")
                    if (mins !== null) next[p[0]] = mins
                })
                theme.wcOffsets = next
            }
        }
        onExited: if (theme._wcRefreshAgain) { theme._wcRefreshAgain = false; theme.refreshZoneOffsets() }
    }
    Process {
        id: wcCheckProc
        stdout: StdioCollector {
            onStreamFinished: {
                var zone = theme._wcQueue[0]
                theme._wcQueue = theme._wcQueue.slice(1)
                var p = String(this.text).trim().split(" ")
                if (theme._wcMinutes(p[1] || "") === null)
                    theme.wcAddError = "Unknown zone: " + zone + " (e.g. Asia/Kolkata)"
                else if (theme.wcZones.indexOf(zone) < 0)
                    theme.wcSave(theme.wcZones.concat([zone]))
            }
        }
        onExited: theme._wcCheckNext()
    }
    // DST changes land on the hour (or half hour): refresh just after each
    Timer {
        id: wcHourly
        running: true
        interval: 1800000 - Date.now() % 1800000 + 5000
        onTriggered: {
            theme.refreshZoneOffsets()
            interval = 1800000 - Date.now() % 1800000 + 5000
            restart()
        }
    }

    // ── reminders (transient systemd user timers: they survive a bar restart) ──
    property var reminders: []            // [{unit, next (epoch s), text}]
    function refreshReminders() { if (!remListProc.running) remListProc.running = true }
    // detached, so quick successive clicks each run (a shared Process would
    // drop a request while busy); the list refreshes shortly after
    function addReminder(seconds, text) {
        Quickshell.execDetached(["dots-bar-tools", "remind", "add", String(Math.round(seconds)), String(text || "")])
        remRefreshSoon.restart()
    }
    function cancelReminder(unit) {
        Quickshell.execDetached(["dots-bar-tools", "remind", "cancel", String(unit)])
        remRefreshSoon.restart()
    }
    Timer { id: remRefreshSoon; interval: 700; onTriggered: theme.refreshReminders() }
    Process {
        id: remListProc
        command: ["dots-bar-tools", "remind", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { theme.reminders = JSON.parse(this.text) || [] } catch (e) {}
            }
        }
    }
    Timer {
        // fast enough that a fired reminder leaves the bar promptly
        interval: theme.reminders.length > 0 || theme.reminderVisible ? 10000 : 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.refreshReminders()
    }

    // ── cached sudo ──
    // sudo itself can't be asked without running it (which logs and extends
    // the cache), so follow its PAM lines in the journal: each "session
    // opened … by <user>" means the password is cached for that terminal
    // for timestamp_timeout (sudo's default, 5 min). An approximation: it
    // can't see `sudo -k` in one terminal.
    readonly property int sudoTimeoutMin: 5
    property double sudoLastMs: 0
    property double _sudoForgotMs: 0      // entries before this were cleared by sudo -K
    property double sudoNowMs: Date.now()
    readonly property bool sudoCached: sudoLastMs > 0 && sudoNowMs - sudoLastMs < sudoTimeoutMin * 60000
    readonly property string sudoUser: Quickshell.env("USER") || ""
    function forgetSudo() {
        // -K removes every cached credential of this user; it needs no password
        Quickshell.execDetached(["sudo", "-K"])
        sudoLastMs = 0
        _sudoForgotMs = Date.now()
    }
    Process {
        id: sudoWatch
        command: ["journalctl", "--follow", "--output=json", "--identifier=sudo",
                  "--since=-" + (theme.sudoTimeoutMin + 1) + "min"]
        running: theme.sudoUser !== ""
        stdout: SplitParser {
            onRead: line => {
                var e
                try { e = JSON.parse(line) } catch (err) { return }
                var msg = typeof e.MESSAGE === "string" ? e.MESSAGE : ""
                var m = /session opened for user \S+ by ([^\s(]+)\(uid=\d+\)/.exec(msg)
                if (!m || m[1] !== theme.sudoUser) return
                var ms = Math.floor(parseInt(e.__REALTIME_TIMESTAMP, 10) / 1000)
                if (ms > theme.sudoLastMs && ms > theme._sudoForgotMs) theme.sudoLastMs = ms
                theme.sudoNowMs = Date.now()
            }
        }
        onExited: sudoRewatch.restart()
    }
    Timer { id: sudoRewatch; interval: 30000; onTriggered: sudoWatch.running = true }
    Timer {
        interval: 10000
        running: theme.sudoLastMs > 0
        repeat: true
        onTriggered: theme.sudoNowMs = Date.now()
    }

    // ── remote sessions (SSH and other remote logind sessions) ──
    property var remoteSessions: []       // [{user, host, service}]
    Process {
        id: remoteProc
        command: ["dots-bar-tools", "remote"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                String(this.text).split("\n").forEach(function (line) {
                    var p = line.trim().split(" ")
                    if (p.length >= 3) out.push({ user: p[0], host: p[1], service: p[2] })
                })
                theme.remoteSessions = out
            }
        }
    }
    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!remoteProc.running) remoteProc.running = true
    }
}
