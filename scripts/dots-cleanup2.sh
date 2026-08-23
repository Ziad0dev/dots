#!/usr/bin/env bash
# Second-pass dead-code sweep. Idempotent; safe to re-run.
#   bash scripts/dots-cleanup2.sh [~/dots]
set -uo pipefail

DOTS="${1:-$HOME/dots}"
cd "$DOTS" || { echo "dots-cleanup2: no such dir: $DOTS" >&2; exit 1; }

n=0
did() { printf '  \033[32mfixed\033[0m %s\n' "$1"; n=$((n + 1)); }
skip() { printf '  \033[90mskip \033[0m %s\n' "$1"; }
sec() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
drop() { git rm -rq --ignore-unmatch "$1" 2>/dev/null; rm -rf "$1"; }

RISE=config/quickshell/rise
V2="$RISE/variants/V2"

# ── orphan helper scripts ────────────────────────────────────────────────
# Both are packaged in home/quickshell-rise.nix but nothing invokes them.
# dots-theme-scan: the carousel panels build their own scan command inline
# (ImageCarouselPanel.qml buildScanCmd) and never shell out to it.
# dots-picker-palette: leftover from the deleted config/quickshell/picker/.
sec "orphan helper scripts"
for s in dots-theme-scan dots-picker-palette; do
    if [ -f "scripts/$s.sh" ]; then
        drop "scripts/$s.sh"
        did "removed scripts/$s.sh (packaged, zero callers)"
    else
        skip "scripts/$s.sh already gone"
    fi
done

f=home/quickshell-rise.nix
if grep -q 'themeScan' "$f"; then
    python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
for name in ("themeScan", "pickerPalette"):
    s = re.sub(r"\n  " + name + r" = pkgs\.writeShellApplication \{.*?\n  \};\n", "\n", s, flags=re.S)
s = s.replace("    themeScan\n", "").replace("    pickerPalette\n", "")
s = s.replace('    "dots-theme-scan"\n', "").replace('    "dots-picker-palette"\n', "")
s = s.replace('    "dots-files"\n', "").replace('    "dots-launch-editor"\n', "")
open(p, "w").write(s)
PY
    did "$f: dropped the themeScan/pickerPalette derivations and their helpers entries"
else
    skip "$f: helpers already pruned"
fi

# ── dead shim branches ───────────────────────────────────────────────────
# FilesWidget.qml spawns ghostty directly (line 31); nothing calls
# dots-launch-editor at all.
sec "dead shims"
f=scripts/dots-compat.sh
if grep -q '^    dots-launch-editor)' "$f"; then
    python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
for name in ("dots-launch-editor", "dots-files"):
    s = re.sub(r"\n    " + name + r"\)\n.*?\n        ;;\n", "\n", s, count=1, flags=re.S)
open(p, "w").write(s)
PY
    did "$f: removed the dots-files / dots-launch-editor branches (no callers)"
else
    skip "$f: dead branches already gone"
fi

# ── unreferenced V2 assets ───────────────────────────────────────────────
sec "unreferenced assets"
for a in bob2.png hdd-mark.svg; do
    if [ -f "$V2/assets/$a" ]; then
        drop "$V2/assets/$a"
        did "removed $V2/assets/$a (zero references)"
    else
        skip "$V2/assets/$a already gone"
    fi
done

# ── V1 launcher logo alternatives point at files only V2 has ─────────────
# rise/modules/LauncherWidget.qml resolves ../assets/{bob3.png,omacom-text.png}
# against rise/assets/, which lacks both — the two non-default logo settings
# render nothing in V1.
sec "V1 asset parity"
for a in bob3.png omacom-text.png; do
    if [ ! -f "$RISE/assets/$a" ] && [ -f "$V2/assets/$a" ]; then
        cp "$V2/assets/$a" "$RISE/assets/$a"
        did "copied $a into $RISE/assets/ (V1 LauncherWidget referenced a missing file)"
    else
        skip "$RISE/assets/$a present"
    fi
done

# ── unused hyprland bezier curves ────────────────────────────────────────
sec "hyprland curves"
f=config/hypr/hyprland.lua
removed=0
for c in wind winIn winOut slow overshot bounce slingshot nice; do
    if grep -q "hl.curve(\"$c\"," "$f" && ! grep -q "bezier = \"$c\"" "$f"; then
        sed -i "/hl\.curve(\"$c\",/d" "$f"
        removed=$((removed + 1))
    fi
done
if [ "$removed" -gt 0 ]; then
    sed -i '/^$/{N;/^\n$/D}' "$f"
    did "$f: removed $removed unused curve(s); only snap and linear are referenced"
else
    skip "$f: no unused curves"
fi

# ── dead audio toggle ────────────────────────────────────────────────────
# disableAcpOnUsb is a hardcoded false, so the mkIf branch can never fire.
sec "modules/audio.nix"
f=modules/audio.nix
if grep -q 'disableAcpOnUsb = false' "$f"; then
    python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\n    wireplumber\.extraConfig = lib\.mkIf disableAcpOnUsb \{.*?\n    \};\n", "\n", s, flags=re.S)
s = re.sub(r"\nlet\n\n  disableAcpOnUsb = false;\nin\n", "\n", s, flags=re.S)
s = s.replace("{\n  config,\n  lib,\n  pkgs,\n  ...\n}:\n", "{ ... }:\n", 1)
open(p, "w").write(s)
PY
    did "$f: dropped the permanently-false disableAcpOnUsb branch"
else
    skip "$f: no dead toggle"
fi

# ── spent one-shot ───────────────────────────────────────────────────────
sec "spent scripts"
if [ -f scripts/dots-fixup.sh ]; then
    drop scripts/dots-fixup.sh
    did "removed scripts/dots-fixup.sh (one-shot, already applied — reports 0 changes)"
else
    skip "dots-fixup.sh already gone"
fi

printf '\n\033[1mdots-cleanup2: %d change(s)\033[0m\n' "$n"
[ "$n" -gt 0 ] && echo "next: git add -A && nh os switch"
exit 0
