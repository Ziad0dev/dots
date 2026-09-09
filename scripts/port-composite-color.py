#!/usr/bin/env python3
"""Let the three composite bar groups take per-widget colours.

Status (G3), Center (G8) and Quick tools (G10) are Components defined inline in
BarSlot rather than files in modules/, so the earlier widget-colour pass skipped
them. Each still draws exactly ONE pill around its whole row — the children are
glyphs, not pills — so each needs a single Rectangle rewired to its GID.

Prerequisite: port-v2-widgetcolor.py (supplies the colour model on Theme).

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import re
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

PILL = ("                color: barSlot.root.pill; "
        "border.color: barSlot.root.pillBorder; "
        "border.width: barSlot.root.pillBorderW\n")

COMPOSITES = [("compStatus", "G3"), ("compCenter", "G8"), ("compQuick", "G10")]


def recolour(src):
    """Rewrite each composite's pill in place, keyed by the component it sits in."""
    out = []
    current = None
    changed = 0
    owner = {name: gid for name, gid in COMPOSITES}
    for line in src.splitlines(keepends=True):
        m = re.search(r'id: (comp[A-Za-z]+)', line)
        if m:
            current = m.group(1)
        if line == PILL and current in owner:
            gid = owner[current]
            out.append("                color: barSlot.root.widgetFillColor(\"%s\"); "
                       "border.color: barSlot.root.widgetBorderColor(\"%s\"); "
                       "border.width: barSlot.root.widgetBorderWidth(\"%s\")\n"
                       % (gid, gid, gid))
            changed += 1
            continue
        out.append(line)
    return "".join(out), changed


def main():
    import importlib.util
    here = Path(__file__).resolve().parent
    for cand in (here / "port-v2-telemetry.py", Path("scripts/port-v2-telemetry.py")):
        if cand.is_file():
            spec = importlib.util.spec_from_file_location("_chk", cand)
            chk = importlib.util.module_from_spec(spec)
            argv, sys.argv = sys.argv, ["_chk"]
            try:
                spec.loader.exec_module(chk)
            finally:
                sys.argv = argv
            break
    else:
        sys.exit("port-v2-telemetry.py must sit next to this script")

    bp = RISE / "BarSlot.qml"
    if not bp.is_file():
        sys.exit("not found: %s" % bp)
    src = bp.read_text()
    if "widgetFillColor(\"G3\")" in src:
        print("  = composite pills already recoloured")
        return
    if chk.balance(src, "input BarSlot"):
        sys.exit("BarSlot.qml is already unbalanced")

    out, changed = recolour(src)
    if changed != len(COMPOSITES):
        sys.exit("expected %d composite pills, rewrote %d — BarSlot has drifted"
                 % (len(COMPOSITES), changed))
    if chk.balance(out, "result BarSlot"):
        sys.exit("patched output unbalanced, NOT writing")
    shutil.copy2(bp, str(bp) + ".bak")
    bp.write_text(out)
    print("  + %d composite pills recoloured (G3, G8, G10)" % changed)


if __name__ == "__main__":
    main()
