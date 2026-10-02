import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The shell's notification daemon (replaces dunst). Owns org.freedesktop.Notifications,
// keeps a persisted history for the notification panel and a popup queue for
// NotificationPopups. Do-not-disturb stays where it was: theme.notifSilenced,
// read from ~/.local/state/dots/notifications.json.
//
// Entries are plain objects {key, appName, appIcon, image, summary, body, urgency,
// time} plus `notif`, the live Notification while the sender still knows about
// it (actions only work then). Live notifications stay tracked while they are
// in the history, so the panel can still fire their actions.
Item {
    id: service
    required property var theme

    readonly property int historyCap: 50
    readonly property int defaultTimeoutMs: 6000

    property var history: []            // newest first
    property var popups: []             // keys currently shown as popups
    readonly property int count: history.length

    signal received(var entry)

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: function(notif) {
            notif.tracked = true
            var entry = {
                key: Date.now() + ":" + notif.id,
                notif: notif,
                appName: notif.appName,
                appIcon: notif.appIcon,
                image: notif.image,
                summary: notif.summary,
                body: notif.body,
                urgency: notif.urgency,
                time: Date.now()
            }
            notif.closed.connect(function() { service.detach(entry.key) })

            if (notif.transient) {
                // transient: popup only, never kept
                service.showPopup(entry)
                return
            }
            var next = [entry].concat(service.history)
            while (next.length > service.historyCap) {
                var dropped = next.pop()
                if (dropped.notif) dropped.notif.dismiss()
            }
            service.history = next
            service.showPopup(entry)
            service.received(entry)
            service.save()
        }
    }

    // ── lookup / mutation ──
    property var transients: ({})        // key -> entry for transient popups

    function find(key) {
        for (var i = 0; i < history.length; i++)
            if (history[i].key === key) return history[i]
        return transients[key] || null
    }

    // the sender closed it (or it was dismissed): keep the text, drop the object
    function detach(key) {
        var e = find(key)
        if (e && e.notif) {
            snapshot(e)
            e.notif = null
            history = history.slice()
        }
        hidePopup(key)
        save()
    }

    function snapshot(e) {
        if (!e.notif) return
        e.appName = e.notif.appName
        e.appIcon = e.notif.appIcon
        e.summary = e.notif.summary
        e.body = e.notif.body
        e.urgency = e.notif.urgency
        // image:// urls die with the object; app icons are names and survive
        e.image = ""
    }

    function dismiss(key) {
        var e = find(key)
        history = history.filter(function(x) { return x.key !== key })
        hidePopup(key)
        if (e && e.notif) e.notif.dismiss()
        save()
    }

    function clearAll() {
        var old = history
        history = []
        popups = []
        for (var i = 0; i < old.length; i++)
            if (old[i].notif) old[i].notif.dismiss()
        save()
    }

    function actionsOf(key) {
        var e = find(key)
        return e && e.notif ? e.notif.actions : []
    }

    function invoke(key, identifier) {
        var e = find(key)
        if (!e || !e.notif) return false
        var acts = e.notif.actions
        for (var i = 0; i < acts.length; i++) {
            if (acts[i].identifier === identifier) {
                acts[i].invoke()
                if (!e.notif || !e.notif.resident) dismiss(key)
                return true
            }
        }
        return false
    }

    function invokeDefault(key) {
        return invoke(key, "default")
    }

    // ── popups ──
    function showPopup(entry) {
        var critical = entry.urgency === NotificationUrgency.Critical
        if (theme.notifSilenced && !critical) return
        if (entry.notif && entry.notif.transient) {
            var t = Object.assign({}, transients); t[entry.key] = entry; transients = t
        }
        popups = [entry.key].concat(popups.filter(function(k) { return k !== entry.key }))
    }

    function hidePopup(key) {
        if (popups.indexOf(key) >= 0)
            popups = popups.filter(function(k) { return k !== key })
        if (transients[key]) {
            var t = Object.assign({}, transients); delete t[key]; transients = t
        }
    }

    // ms a popup stays up; 0 = until closed
    function popupTimeout(entry) {
        if (entry.urgency === NotificationUrgency.Critical) return 0
        var t = entry.notif ? entry.notif.expireTimeout : -1   // ms; -1 = server default
        return t > 0 ? t : defaultTimeoutMs
    }

    // ── persistence ──
    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/qs-rise-notifications.json"
    property bool loaded: false
    property string lastSaved: ""

    FileView {
        id: cacheFile
        path: service.cachePath
        printErrors: false
        onLoaded: {
            var restored = []
            try {
                var j = JSON.parse(cacheFile.text())
                if (j.version === 2 && Array.isArray(j.history)) {
                    restored = j.history
                } else if (Array.isArray(j.recent)) {
                    // dunst-era cache: keep what wasn't dismissed
                    var gone = j.dismissed || {}
                    restored = j.recent.filter(function(e) { return !gone[e.key] }).map(function(e) {
                        return { key: "old:" + e.key, appName: e.appName || "", appIcon: "", image: "",
                                 summary: e.summary || "", body: e.body || "", urgency: 1, time: 0 }
                    })
                }
            } catch (e) {}
            // live ones (kept across a reload) come first; drop their stale copies
            var live = {}
            for (var i = 0; i < service.history.length; i++) live[service.history[i].key] = true
            service.history = service.history.concat(restored.filter(function(e) { return !live[e.key] }))
                .slice(0, service.historyCap)
            service.reattach()
            service.loaded = true
        }
        onLoadFailed: {
            service.reattach()
            service.loaded = true
        }
    }

    // keepOnReload hands still-open notifications to the new config without
    // re-emitting them; link them back to their restored entries by id, and
    // close the ones whose entry is gone.
    function reattach() {
        var tracked = server.trackedNotifications.values
        var changed = false
        for (var i = 0; i < tracked.length; i++) {
            var n = tracked[i]
            var hit = null
            for (var j = 0; j < history.length; j++) {
                var e = history[j]
                if (e.notif === n) { hit = e; break }
                if (!e.notif && e.key.endsWith(":" + n.id)) { hit = e; break }
            }
            if (!hit) { n.dismiss(); continue }
            if (hit.notif !== n) {
                hit.notif = n
                n.closed.connect(function(k) { return function() { service.detach(k) } }(hit.key))
                changed = true
            }
        }
        if (changed) history = history.slice()
    }
    Component.onCompleted: cacheFile.reload()

    Timer { id: saveTimer; interval: 400; onTriggered: service.writeCache() }
    function save() { if (loaded) saveTimer.restart() }
    function writeCache() {
        var out = []
        for (var i = 0; i < history.length; i++) {
            var e = history[i]
            var n = e.notif
            out.push({
                key: e.key,
                appName: n ? n.appName : e.appName,
                appIcon: n ? n.appIcon : e.appIcon,
                image: "",
                summary: n ? n.summary : e.summary,
                body: n ? n.body : e.body,
                urgency: n ? n.urgency : e.urgency,
                time: e.time
            })
        }
        var text = JSON.stringify({ version: 2, history: out })
        if (text === lastSaved) return
        lastSaved = text
        cacheFile.setText(text)
    }
}
