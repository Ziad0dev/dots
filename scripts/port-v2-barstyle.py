#!/usr/bin/env python3
"""Make BAR STYLE (full / fit / dock / notch) actually reshape the bar.

Prerequisites: port-v2-telemetry.py, port-v2-caret.py (supply barShellStyle,
v2BarHeight, v2BarBorder, panelRadius).

BarSlot.qml only. The island stops being anchored edge-to-edge and becomes
width-driven, so a compact style shrinks it to content width and centres it,
with a per-style radius. The exclusive zone and mask follow the visible shell.

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

SHELL_PROPS = '''    readonly property bool compactShell: barSlot.root.barShellStyle !== "full"
    readonly property int shellOuterMargin: 5
    readonly property int shellRadius: barSlot.root.barShellStyle === "dock"
        ? 8
        : barSlot.root.barShellStyle === "notch" ? 0 : barSlot.root.panelRadius
    readonly property real fitNaturalWidth:
        leftRowItem.implicitWidth + centerRowItem.implicitWidth + rightRowItem.implicitWidth
        + 6 * island.rowMargin
    readonly property real shellTargetWidth: compactShell
        ? Math.max(80, Math.min(barSlot.width - 2 * shellOuterMargin, fitNaturalWidth))
        : barSlot.width - 2 * shellOuterMargin
'''

ISLAND_GEOM = '''        anchors.verticalCenter: undefined
        width: barSlot.shellTargetWidth
        x: Math.round((parent.width - width) / 2)
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on x     { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
'''

FILE_EDITS = {
    "BarSlot.qml": [
        ("compactShell", "shell style properties",
         '    readonly property string screenName: barSlot.screen ? barSlot.screen.name : ""',
         "after-line", SHELL_PROPS.rstrip("\n")),
        ("shellTargetWidth\n", "island geometry",
         '''        anchors {
            left: parent.left; leftMargin: 5
            right: parent.right; rightMargin: 5
        }''',
         "replace", ISLAND_GEOM.rstrip("\n")),
        ("compactShell ? barSlot.shellRadius : barSlot.root.islandRadius", "edit frame radius follows style",
         "            radius: barSlot.root.islandRadius + 2",
         "replace",
         "            radius: (barSlot.compactShell ? barSlot.shellRadius : barSlot.root.islandRadius) + 2"),
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
