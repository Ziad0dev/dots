// Ported from dhrruvsharma/shell (quickshell/services/Cava.qml), GPL-3.0-or-later.
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property bool running: false
    property var values: []
    property int barsCount: 32
    property var _parseBuffer: new Array(barsCount)
    property bool _silent: false
    property var config: ({
        "general": {
            "bars": barsCount,
            "framerate": 20,
            "autosens": 1,
            "sensitivity": 100,
            "lower_cutoff_freq": 50,
            "higher_cutoff_freq": 10000
        },
        "output": {
            "method": "raw",
            "data_format": "ascii",
            "ascii_max_range": 100,
            "bit_format": "8bit",
            "channels": "mono",
            "mono_option": "average"
        },
        "smoothing": {
            "monstercat": 1,
            "noise_reduction": 70
        }
    })

    // the config as cava's ini text
    readonly property string configText: {
        let t = "";
        for (const k in config) {
            const obj = config[k];
            if (typeof obj !== "object") {
                t += k + "=" + obj + "\n";
                continue;
            }
            t += "[" + k + "]\n";
            for (const k2 in obj)
                t += k2 + "=" + obj[k2] + "\n";
        }
        return t;
    }

    Process {
        id: process

        running: root.running
        // rise: the config goes in as a file (like rise's own cava runs), not
        // written to stdin after start: cava could read an empty stdin first,
        // fall back to terminal output with no terminal, and segfault
        // (init_terminal_noncurses), dozens of times a session
        command: ["bash", "-c", "exec cava -p <(printf '%s' \"$1\")", "cava", root.configText]
        // cava links libGL for its SDL output. With the session's
        // __GLX_VENDOR_LIBRARY_NAME=nvidia that pulled the whole NVIDIA GL
        // driver (~100 MB resident, 3x the anonymous memory) into a process
        // that only ever prints numbers.
        environment: ({ "__GLX_VENDOR_LIBRARY_NAME": null })
        onStarted: values = Array(barsCount).fill(0)
        onExited: values = Array(barsCount).fill(0)

        stdout: SplitParser {
            onRead: (data) => {
                const buffer = root._parseBuffer;
                let idx = 0;
                let num = 0;
                let silent = true;
                for (let i = 0, len = data.length - 1; i < len; i++) {
                    const c = data.charCodeAt(i);
                    if (c === 59) {
                        if (num !== 0)
                            silent = false;
                        buffer[idx++] = num * 0.01;
                        num = 0;
                    } else if (c >= 48 && c <= 57) {
                        num = num * 10 + (c - 48);
                    }
                }
                if (num > 0 || idx < root.barsCount) {
                    if (num !== 0)
                        silent = false;
                    buffer[idx++] = num * 0.01;
                }

                // cava keeps emitting all-zero frames when nothing plays; only
                // publish the first one, so consumers stop repainting in silence.
                if (silent && root._silent)
                    return;
                root._silent = silent;
                root.values = buffer.slice(0, idx);
            }
        }

    }

}