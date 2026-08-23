#!/usr/bin/env bash
# Post-V2-removal sweep. Idempotent.
#   bash scripts/dots-cleanup3.sh [~/dots]
set -uo pipefail

DOTS="${1:-$HOME/dots}"
cd "$DOTS" || { echo "dots-cleanup3: no such dir: $DOTS" >&2; exit 1; }

RISE=config/quickshell/rise
n=0
did() { printf '  \033[32mfixed\033[0m %s\n' "$1"; n=$((n + 1)); }
skip() { printf '  \033[90mskip \033[0m %s\n' "$1"; }
sec() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

sec "denix-rise.sh: stale V2 targets"
f=scripts/denix-rise.sh
# shellcheck disable=SC2016
if grep -q 'variants/V2' "$f"; then
    sed -i 's| "\$RISE/variants/V2/[A-Za-z/]*\.qml"||g' "$f"
    did "$f: dropped the V2 entries from 6 rewrite loops"
else
    skip "$f: no V2 targets"
fi

# ArchUpdaterWidget.qml was deleted when FilesWidget replaced it, and the
# dots-files shim this block inserts was removed too. Doubly dead.
if grep -q 'ArchUpdaterWidget' "$f"; then
    python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"# ── packages widget -> file manager ─+\n(#[^\n]*\n)*"
           r"for f in \"\$RISE/modules/ArchUpdaterWidget\.qml\".*?\nPYEOF\ndone\n\n",
           "", s, count=1, flags=re.S)
open(p, "w").write(s)
PY
    did "$f: removed the dead ArchUpdaterWidget -> dots-files block"
else
    skip "$f: no ArchUpdater block"
fi

# bob3.png backs the reachable "hyprland" launcher-logo option, but this line
# deletes it on every re-vendor — which would silently re-break that option.
if grep -q 'assets/bob3.png' "$f"; then
    # shellcheck disable=SC2016
    sed -i 's| "\$RISE/assets/bob3\.png"||' "$f"
    did "$f: stopped deleting bob3.png (the hyprland logo option needs it)"
else
    skip "$f: bob3.png already preserved"
fi

sec "dots-finalize.sh: stale V2 targets"
f=scripts/dots-finalize.sh
if grep -q 'variants/V2' "$f"; then
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('    for d in "$RISE/modules" "$RISE/variants/V2/modules"; do',
              '    for d in "$RISE/modules"; do', 1)
s = s.replace('    png="$RISE/variants/V2/assets/nixos-logo.png"\n    [ -f "$png" ] || png="$RISE/assets/nixos-logo.png"\n',
              '    png="$RISE/assets/nixos-logo.png"\n', 1)
open(p, "w").write(s)
PY
    did "$f: single module dir, single logo path"
else
    skip "$f: no V2 targets"
fi

sec "omacom-text.png"
# My error in cleanup2: I copied this into rise/assets to satisfy
# LauncherWidget's omacomTextLogo branch. But denix-rise rewrites
# launcherLogoTextOptions to ["nixos","hyprland","arch"], so launcherLogoText
# can never be "omacom" and the branch is unreachable. bob3.png was the real
# fix; this one was not.
if [ -f "$RISE/assets/omacom-text.png" ]; then
    git rm -q --ignore-unmatch "$RISE/assets/omacom-text.png" 2>/dev/null
    rm -f "$RISE/assets/omacom-text.png"
    did "removed $RISE/assets/omacom-text.png (omacom is not a selectable option)"
else
    skip "omacom-text.png already gone"
fi

sec "spent one-shots"
for s in dots-cleanup2 dots-drop-v2; do
    if [ -f "scripts/$s.sh" ]; then
        git rm -q --ignore-unmatch "scripts/$s.sh" 2>/dev/null
        rm -f "scripts/$s.sh"
        did "removed scripts/$s.sh (applied; reports 0 changes)"
    else
        skip "scripts/$s.sh already gone"
    fi
done

sec "SC2066 after the loop collapse"
for t in scripts/denix-rise.sh scripts/dots-finalize.sh; do
    # shellcheck disable=SC2016
    if grep -qE '^ *for [a-z]+ in "\$RISE/[^"]*"; do$' "$t" && ! grep -q SC2066 "$t"; then
        python3 - "$t" <<'PY'
import re, sys
p = sys.argv[1]
add = "# shellcheck disable=SC2066  # single-element list since the V2 tree was removed"
out = []
for ln in open(p).read().split("\n"):
    st = ln.lstrip()
    if re.match(r'^for [a-z]+ in "\$RISE/[^"]*"; do$', st) and (not out or "SC2066" not in out[-1]):
        out.append(" " * (len(ln) - len(st)) + add)
    out.append(ln)
open(p, "w").write("\n".join(out))
PY
        did "$t: shellcheck directives for the now-single-element loops"
    else
        skip "$t: SC2066 handled"
    fi
done

sec "verify"
# shellcheck disable=SC2016
if grep -rq 'variants/V2' scripts/ config/ --exclude=dots-cleanup3.sh 2>/dev/null; then
    printf '  \033[31mWARN\033[0m V2 references remain:\n'
    grep -rn 'variants/V2' scripts/ config/ --exclude=dots-cleanup3.sh | sed 's/^/       /'
else
    printf '  \033[32mok\033[0m   no V2 references anywhere\n'
fi
for s in scripts/*.sh scripts/git-hooks/*; do
    bash -n "$s" 2>/dev/null || printf '  \033[31mWARN\033[0m %s: syntax error\n' "$s"
done

printf '\n\033[1mdots-cleanup3: %d change(s)\033[0m\n' "$n"
[ "$n" -gt 0 ] && echo "next: git add -A && nh os switch"
exit 0
