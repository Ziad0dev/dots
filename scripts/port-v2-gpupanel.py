#!/usr/bin/env python3
"""Wire GpuPanel into the rise bar.

Prerequisites: port-v2-telemetry.py and port-v2-caret.py.

Three edits:
  BarSlot.qml     publish a "gpu" caret anchor for group G12
  VariantRoot.qml instantiate GpuPanel
  GpuWidget.qml   drop the duplicate nvidia-smi sampler, read Theme telemetry,
                  left-click opens the panel, right-click keeps nvtop

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

FILE_EDITS = {
    "BarSlot.qml": [
        ("gpu:          island.groupX", "gpu caret anchor",
         '                cpu:          island.groupX("G5",  0.5),',
         "after-line", '                gpu:          island.groupX("G12", 0.5),'),
    ],
    "VariantRoot.qml": [
        ("GpuPanel {", "GpuPanel mount",
         "    CpuPanel { root: theme }",
         "after-line", "    GpuPanel { root: theme }"),
    ],
    "modules/GpuWidget.qml": [
        ("root.gpuPercent", "read Theme telemetry",
         '''    property int percent: 0
    property int memUsedMiB: 0
    property int memTotalMiB: 0
    property int tempC: 0
    property bool ok: false''',
         "replace",
         '''    readonly property int percent: root.gpuPercent
    readonly property int memUsedMiB: root.gpuMemoryUsedMiB
    readonly property int memTotalMiB: root.gpuMemoryTotalMiB
    readonly property int tempC: root.gpuTemperatureC
    readonly property bool ok: root.gpuAvailable'''),
        ("// sampler removed", "drop duplicate sampler",
         '''    Process {
        id: query
        command: ["nvidia-smi",
                  "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu",
                  "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(this.text || "").trim().split("\\n")[0].split(",")
                if (parts.length < 4) { rootMod.ok = false; return }
                var u = parseInt(parts[0]), mu = parseInt(parts[1])
                var mt = parseInt(parts[2]), t = parseInt(parts[3])
                if (isNaN(u) || isNaN(mu) || isNaN(mt)) { rootMod.ok = false; return }
                rootMod.percent = Math.max(0, Math.min(100, u))
                rootMod.memUsedMiB = mu
                rootMod.memTotalMiB = mt
                rootMod.tempC = isNaN(t) ? 0 : t
                rootMod.ok = true
            }
        }
    }

    Timer {
        interval: root.modGpu ? 6000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }

''',
         "replace", "    // sampler removed: Theme.qml owns gpu telemetry\n\n"),
        ("root.gpuVisible = !root.gpuVisible", "left-click opens the panel",
         '''        onClicked: function (e) {
            tip.hide()
            gpuTui.running = false
            gpuTui.running = true
        }''',
         "replace",
         '''        onClicked: function (e) {
            tip.hide()
            if (e.button === Qt.RightButton) {
                gpuTui.running = false
                gpuTui.running = true
                return
            }
            root.gpuVisible = !root.gpuVisible
        }'''),
    ],
}


def _load_checker():
    import importlib.util
    here = Path(__file__).resolve().parent
    for cand in (here / "port-v2-telemetry.py", Path("scripts/port-v2-telemetry.py")):
        if cand.is_file():
            spec = importlib.util.spec_from_file_location("_chk", cand)
            mod = importlib.util.module_from_spec(spec)
            argv, sys.argv = sys.argv, ["_chk"]
            try:
                spec.loader.exec_module(mod)
            finally:
                sys.argv = argv
            return mod
    sys.exit("port-v2-telemetry.py must sit next to this script (it supplies the brace checker)")


def main():
    chk = _load_checker()
    if not RISE.is_dir():
        sys.exit("not a directory: %s (run from the repo root, or pass the rise dir)" % RISE)

    for rel, edits in FILE_EDITS.items():
        path = RISE / rel
        if not path.is_file():
            sys.exit("not found: %s" % path)
        src = path.read_text()
        bad = chk.balance(src, "input " + rel)
        if bad:
            sys.exit("refusing to patch, input unbalanced:\n  " + "\n  ".join(bad))

        applied, skipped = [], []
        for guard, label, anchor, mode, payload in edits:
            if guard in src:
                skipped.append(label)
                continue
            count = src.count(anchor)
            if count != 1:
                sys.exit("%s: anchor for %r matched %d times, expected 1:\n%s"
                         % (rel, label, count, anchor[:160]))
            if mode == "replace":
                src = src.replace(anchor, payload)
            else:
                end = src.index(anchor) + len(anchor)
                if mode == "after-line":
                    end = src.index("\n", end)
                    if not payload.startswith("\n"):
                        payload = "\n" + payload
                src = src[:end] + payload + src[end:]
            applied.append(label)

        problems = chk.balance(src, "result " + rel)
        if problems:
            sys.exit("%s: patched output unbalanced, NOT writing:\n  %s"
                     % (rel, "\n  ".join(problems)))

        if applied:
            shutil.copy2(path, str(path) + ".bak")
            path.write_text(src)
        print(rel)
        for name in applied:
            print("  +", name)
        for name in skipped:
            print("  =", name, "(already present)")


if __name__ == "__main__":
    main()
