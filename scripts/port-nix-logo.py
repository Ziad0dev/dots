#!/usr/bin/env python3
"""Use the real NixOS mark for the launcher's icon mode.

launcherLogoIconGlyph("nix") returned "ac_unit" — the Material Symbols
snowflake — instead of the NixOS lambda. Every other icon in the map is a Nerd
Font glyph rendered in `mono` (JetBrainsMono Nerd Font), so this switches to
nf-linux-nixos (U+F313) and drops the Material Symbols special case.

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

FILE_EDITS = {
    "Theme.qml": [
        ("0xF313", "real NixOS glyph",
         '        if (id === "nix") return "ac_unit"',
         "replace",
         '        if (id === "nix") return String.fromCodePoint(0xF313)'),
        ('return id === "dots" ? "dots" : mono', "drop the Material Symbols case",
         '        return id === "dots" ? "dots" : (id === "nix" ? "Material Symbols Rounded" : mono)',
         "replace",
         '        return id === "dots" ? "dots" : mono'),
        ('if (id === "nix") return 17', "size the NixOS glyph",
         '        if (id === "dragon") return 16\n        return 16',
         "replace",
         '        if (id === "dragon") return 16\n        if (id === "nix") return 17\n        return 16'),
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
