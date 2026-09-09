#!/usr/bin/env python3
"""Remove Arch/Omarchy leftovers that are dead or broken on NixOS.

Findings this fixes:
  1. launcherLogoTextOptions offers "arch", but hasArchAssets is hard-coded
     false and assets/arch-header-*.png do not exist — selecting it renders a
     blank launcher pill.
  2. LauncherWidget references assets/omacom-text.png (Omarchy wordmark), also
     absent; the omacom branch is unreachable but the dead paths remain.
  3. Theme spawns ~/.local/bin/qs-arch-security-gate.sh, which no longer exists
     (the qs-arch-* scripts were deleted). Its trigger watches archUpdates,
     which nothing ever assigns, so the block is unreachable — the gate is
     neutered here rather than excised, since archVisible is still wired into
     popup bookkeeping.

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

FILE_EDITS = {
    "Theme.qml": [
        ('["nixos", "hyprland"]', "drop the arch logo option",
         'readonly property var launcherLogoTextOptions: ["nixos", "hyprland", "arch"]',
         "replace",
         'readonly property var launcherLogoTextOptions: ["nixos", "hyprland"]'),
        ('// "dots", "hyprland", or "nixos"', "correct the logo comment",
         'property string launcherLogoText: "nixos"  // "dots", "hyprland", "arch", or "omacom"',
         "replace",
         'property string launcherLogoText: "nixos"  // "dots", "hyprland", or "nixos"'),
        ('qs-arch-security-gate.sh is gone', "neuter the missing arch security gate",
         'command: ["bash", Quickshell.env("HOME") + "/.local/bin/qs-arch-security-gate.sh"]',
         "replace",
         'command: ["true"]   // qs-arch-security-gate.sh is gone; pacman-only'),
    ],
    "modules/LauncherWidget.qml": [
        ('omacomTextLogo: false', "drop the omacom wordmark branch",
         '    readonly property bool omacomTextLogo: !logoIconMode && root.launcherLogoText === "omacom"',
         "replace",
         '    readonly property bool omacomTextLogo: false   // assets/omacom-text.png does not exist'),
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
