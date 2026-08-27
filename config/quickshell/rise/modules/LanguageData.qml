import QtQuick
import Quickshell.Io

Item {
    id: lang

    readonly property var layouts: [
        { code: "us",  label: "US", full: "English (US)",
          aliases: ["english (us)", "english(us)", "us english", "en-us", "usa"] },
        { code: "se",  label: "SE", full: "Swedish",
          aliases: ["swedish", "svenska", "se"] },
        { code: "ara", label: "AR", full: "Arabic",
          aliases: ["arabic", "العربية", "ara"] },
        { code: "fr",  label: "FR", full: "French",
          aliases: ["french", "français", "francais", "fr"] },
        { code: "de",  label: "DE", full: "German",
          aliases: ["german", "deutsch", "de"] }
    ]

    property int    activeIndex: 0
    readonly property string activeLabel: layouts[activeIndex].label
    readonly property string device: _deviceName

    property string _deviceName: ""
    property int _seq: 0

    function matchLayout(activeRaw) {
        var active = String(activeRaw || "").toLowerCase().trim()
        if (!active) return -1
        for (var i = 0; i < layouts.length; i++) {
            if (active.indexOf(layouts[i].full.toLowerCase()) !== -1) return i
        }
        for (var i = 0; i < layouts.length; i++) {
            var aliases = layouts[i].aliases || []
            for (var j = 0; j < aliases.length; j++) {
                if (active.indexOf(aliases[j]) !== -1) return i
            }
        }
        for (var i = 0; i < layouts.length; i++) {
            if (active === layouts[i].code.toLowerCase()) return i
        }
        return -1
    }

    function refresh() {
        devicesProc.seq = ++lang._seq
        devicesProc.running = false
        devicesProc.running = true
    }

    function switchTo(index) {
        if (index < 0 || index >= layouts.length || !lang._deviceName) return
        switchProc.command = ["hyprctl", "switchxkblayout", lang._deviceName, String(index)]
        switchProc.running = false
        switchProc.running = true
    }

    function cycle(step) {
        if (!lang._deviceName) return
        switchProc.command = ["hyprctl", "switchxkblayout", lang._deviceName, step > 0 ? "next" : "prev"]
        switchProc.running = false
        switchProc.running = true
    }

    Process {
        id: devicesProc
        property int seq: 0
        command: ["hyprctl", "devices", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var seq = devicesProc.seq
                if (seq !== lang._seq) return
                try {
                    var j = JSON.parse(text)
                    var kbs = j.keyboards || []
                    var kb = kbs.find(k => k.main) || kbs[0]
                    if (!kb) return
                    lang._deviceName = kb.name || ""
                    var idx = lang.matchLayout(kb.active_keymap)
                    if (idx !== -1) lang.activeIndex = idx
                } catch (e) {}
            }
        }
    }

    Process {
        id: switchProc
        command: []
        onExited: lang.refresh()
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: lang.refresh()
    }
}
