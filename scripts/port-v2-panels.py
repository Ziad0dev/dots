#!/usr/bin/env python3
"""Mount StorageWidget, CpuTemperatureWidget, StoragePanel and ThermalsPanel.

Prerequisites: port-v2-telemetry.py, port-v2-caret.py, port-v2-gpupanel.py,
and the four new .qml files copied into modules/ and panels/ first.

Adds bar groups G16 (thermal) and G17 (storage) to the right region, widens the
rightSplits arrays from 6 to 8 gaps to match, publishes both caret anchors, and
instantiates the two panels in VariantRoot.

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

SIX = "[false, false, false, false, false, false]"
EIGHT = "[false, false, false, false, false, false, false, false]"
SIX_T = "[true, true, true, true, true, true]"
EIGHT_T = "[true, true, true, true, true, true, true, true]"

FILE_EDITS = {
    "BarSlot.qml": [
        ("compCpuTemp", "widget components",
         "    Component { id: compGpu;        GpuWidget          { root: barSlot.root } }",
         "after-line",
         "    Component { id: compCpuTemp;    CpuTemperatureWidget { root: barSlot.root } }\n"
         "    Component { id: compStorage;    StorageWidget        { root: barSlot.root } }"),
        ('"G16"', "registry entries",
         '        "G12": compGpu, "G13": compMounts, "G14": compPower, "G15": compBluetooth',
         "replace",
         '        "G12": compGpu, "G13": compMounts, "G14": compPower, "G15": compBluetooth,\n'
         '        "G16": compCpuTemp, "G17": compStorage'),
        ('gid: "G16"', "right region model",
         '            ListElement { gid: "G15" }',
         "replace",
         '            ListElement { gid: "G15" }\n'
         '            ListElement { gid: "G16" } ListElement { gid: "G17" }'),
        ("rightSplits    = " + EIGHT_T, "split array (all on)",
         "            island.rightSplits    = " + SIX_T,
         "replace",
         "            island.rightSplits    = " + EIGHT_T),
        ("rightSplits    = " + EIGHT, "split array (all off)",
         "            island.rightSplits    = " + SIX,
         "replace",
         "            island.rightSplits    = " + EIGHT),
        ("property var rightSplits: " + EIGHT, "split array default",
         "        property var rightSplits: " + SIX + "   // gaps in rightModel",
         "replace",
         "        property var rightSplits: " + EIGHT + "   // gaps in rightModel"),
        ("thermal:      island.groupX", "caret anchors",
         '                gpu:          island.groupX("G12", 0.5),',
         "after-line",
         '                thermal:      island.groupX("G16", 0.5),\n'
         '                storage:      island.groupX("G17", 0.5),'),
    ],
    "VariantRoot.qml": [
        ("ThermalsPanel {", "panel mounts",
         "    GpuPanel { root: theme }",
         "after-line",
         "    ThermalsPanel { root: theme }\n    StoragePanel { root: theme }"),
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
