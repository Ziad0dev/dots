#!/usr/bin/env bash
# Remove the V2 bar variant and pin the shell to V1. Idempotent.
#   bash scripts/dots-drop-v2.sh [~/dots]
set -uo pipefail

DOTS="${1:-$HOME/dots}"
cd "$DOTS" || { echo "dots-drop-v2: no such dir: $DOTS" >&2; exit 1; }

RISE=config/quickshell/rise
n=0
did() { printf '  \033[32mfixed\033[0m %s\n' "$1"; n=$((n + 1)); }
skip() { printf '  \033[90mskip \033[0m %s\n' "$1"; }
sec() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

sec "variants tree"
if [ -d "$RISE/variants" ]; then
    lines=$(find "$RISE/variants" -name '*.qml' -exec cat {} + | wc -l)
    git rm -rq --ignore-unmatch "$RISE/variants" 2>/dev/null
    rm -rf "$RISE/variants"
    did "removed $RISE/variants ($lines lines of QML)"
else
    skip "$RISE/variants already gone"
fi

sec "dead V2Bundle imports"
# Neither file has a single V2Bundle.* reference — the alias existed only to
# make Quickshell's filesystem scanner register the bundle's types.
for f in "$RISE/shell.qml" "$RISE/VariantRoot.qml"; do
    if grep -q 'variants/V2' "$f"; then
        python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"(// Quickshell's virtual filesystem scanner.*?\n)?"
           r"(// [^\n]*\n)*?import \"(\.\./)?variants/V2\" as V2Bundle\n", "", s, count=1, flags=re.S)
s = re.sub(r"\n *v2Source: Qt\.resolvedUrl\(\"variants/V2/VariantRoot\.qml\"\)", "", s, count=1)
open(p, "w").write(s)
PY
        did "$f: dropped the unused V2Bundle import"
    else
        skip "$f: no V2 import"
    fi
done

sec "VariantHost"
f="$RISE/core/VariantHost.qml"
if grep -q 'v2Source' "$f"; then
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('    required property url v2Source\n', '', 1)
s = s.replace(
    '        return String(value || "").trim().toLowerCase() === "v2" ? "v2" : "v1"',
    '        return "v1"', 1)
s = s.replace(
    '        return normalize(variant) === "v2" ? v2Source : v1Source',
    '        return v1Source', 1)
s = s.replace(
    '''        var fallback = previousVariant !== ""
            ? previousVariant
            : (broken === "v1" ? "v2" : "v1")''',
    '        var fallback = previousVariant !== "" ? previousVariant : "v1"', 1)
open(p, "w").write(s)
PY
    did "$f: single source, normalize() pinned to v1, no v2 rollback target"
else
    skip "$f: already single-variant"
fi

sec "StateService"
f="$RISE/core/StateService.qml"
if grep -q '=== "v2"' "$f"; then
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace(
    '        return candidate === "v2" ? "v2" : "v1"',
    '        return "v1"', 1)
s = s.replace(
    '''        if (current === "v1" || current === "v2")
            committedVariant = current
        else if (legacy === "v1" || legacy === "v2")
            committedVariant = legacy
        else
            committedVariant = "v1"''',
    '        committedVariant = "v1"', 1)
open(p, "w").write(s)
PY
    did "$f: a stale active-variant file can no longer select the removed tree"
else
    skip "$f: already pinned to v1"
fi

sec "dead locals left by the rewrites"
f="$RISE/core/StateService.qml"
if grep -q 'var candidate = String(value' "$f"; then
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = '        var candidate = String(value || "").trim().toLowerCase()\n'
b = ('        var current = String(activeVariantFile.text() || "").trim().toLowerCase()\n'
     '        var legacy = String(legacyVersionFile.text() || "").trim().toLowerCase()\n\n')
s = s.replace(a, '', 1).replace(b, '', 1)
open(p, "w").write(s)
PY
    did "$f: removed locals orphaned by the v1 pin"
else
    skip "$f: no orphaned locals"
fi

sec "verify"
if grep -rq 'variants/V2\|v2Source' "$RISE" 2>/dev/null; then
    printf '  \033[31mWARN\033[0m leftover V2 references:\n'
    grep -rn 'variants/V2\|v2Source' "$RISE" | sed 's/^/       /'
else
    printf '  \033[32mok\033[0m   no V2 references remain\n'
fi
for q in "$RISE/shell.qml" "$RISE/VariantRoot.qml" "$RISE/core/VariantHost.qml" "$RISE/core/StateService.qml"; do
    o=$(tr -cd '{' <"$q" | wc -c); c=$(tr -cd '}' <"$q" | wc -c)
    [ "$o" = "$c" ] || printf '  \033[31mWARN\033[0m %s brace mismatch (%s/%s)\n' "$q" "$o" "$c"
done

printf '\n\033[1mdots-drop-v2: %d change(s)\033[0m\n' "$n"
[ "$n" -gt 0 ] && echo "next: git add -A && nh os switch && systemctl --user restart quickshell"
exit 0
