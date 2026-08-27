import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: lang

    readonly property string scriptDir: Quickshell.env("HOME") + "/.config/quickshell/rise/scripts"

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
        fetchProc.running = false
        fetchProc.running = true
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
        id: fetchProc
        running: true
        command: [lang.scriptDir + "/qs-kb-fetch"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(text || "").split("\n")
                lang._deviceName = (lines[0] || "").trim()
                var idx = lang.matchLayout(lines[1])
                if (idx !== -1) lang.activeIndex = idx
                waitProc.running = false
                waitProc.running = true
            }
        }
    }

    Process {
        id: waitProc
        command: [lang.scriptDir + "/qs-kb-wait"]
        onExited: lang.refresh()
    }

    Process {
        id: switchProc
        command: []
        onExited: lang.refresh()
    }
}
