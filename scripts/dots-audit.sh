DOTS="${1:-$HOME/dots}"
cd "$DOTS" || { echo "dots-audit: no such dir: $DOTS" >&2; exit 1; }

fail=0
sec() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; }
ok() { printf '  \033[32mok\033[0m   %s\n' "$1"; }

sec "omarchy residue"
hits=$(grep -ril omarchy . --exclude-dir=.git 2>/dev/null | grep -vE 'rise/README\.md|rise/\.github/|scripts/denix-rise\.sh|scripts/dots-audit\.sh|scripts/dots-cleanup\.sh' || true)
if [ -z "$hits" ]; then
    ok "no references outside upstream docs"
else
    printf '%s\n' "$hits" | while read -r f; do bad "$f"; done
    fail=1
fi

sec "git hygiene"
staged=$(git diff --cached --name-only | wc -l)
unstaged=$(git diff --name-only | wc -l)
if [ "$staged" -gt 0 ] || [ "$unstaged" -gt 0 ]; then
    ok "$staged staged, $unstaged unstaged (tracked changes are visible to the flake)"
else
    ok "nothing pending"
fi

if ! git config --get core.hooksPath >/dev/null 2>&1; then
    bad "core.hooksPath unset — scripts/git-hooks/pre-commit never runs"
fi

loose=$(git count-objects -v | awk '/^count:/ {print $2}')
if [ "${loose:-0}" -gt 5000 ]; then
    warn "$loose loose objects; run: git gc --prune=now"
fi
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    bad "untracked files present; 'nh os switch' will not see them"
    git ls-files --others --exclude-standard | head -10 | sed 's/^/       /'
fi

sec "nix module wiring"
for f in home/*.nix modules/*.nix; do
    [ -f "$f" ] || continue
    base="./$(basename "$f")"
    case "$f" in home/home.nix) continue ;; esac
    case "$f" in
        modules/*)
            grep -qF "./$f" flake.nix 2>/dev/null \
                || warn "$f is not imported by flake.nix (dead module?)" ;;
        *)
            grep -qF "$base" home/home.nix 2>/dev/null \
                || warn "$f is not imported by home/home.nix (dead module?)" ;;
    esac
done

sec "scripts referenced vs present"
grep -rhoE 'readFile \.\./scripts/[A-Za-z0-9._-]+' home/*.nix 2>/dev/null \
    | sed 's|.*scripts/||' | sort -u >/tmp/.audit-want
find scripts -maxdepth 1 -name '*.sh' -printf '%f\n' 2>/dev/null | sort >/tmp/.audit-have
while read -r s; do
    [ -n "$s" ] || continue
    [ -f "scripts/$s" ] || bad "home/*.nix reads scripts/$s but it does not exist"
done </tmp/.audit-want
while read -r s; do
    [ -n "$s" ] || continue
    grep -q "^$s$" /tmp/.audit-want || warn "scripts/$s is not referenced by any nix module"
done </tmp/.audit-have
rm -f /tmp/.audit-want /tmp/.audit-have

sec "shellcheck (writeShellApplication runs this at build time)"
if command -v shellcheck >/dev/null 2>&1; then
    for s in scripts/*.sh; do
        [ -f "$s" ] || continue
        if shellcheck -x -s bash -S style "$s" >/dev/null 2>&1; then
            ok "$s"
        else
            bad "$s"
        fi
    done
else
    warn "shellcheck not installed; add pkgs.shellcheck so this runs before nix does"
fi

sec "QML brace balance"
qbad=0
while read -r q; do
    o=$(tr -cd '{' <"$q" | wc -c)
    c=$(tr -cd '}' <"$q" | wc -c)
    if [ "$o" != "$c" ]; then
        bad "$q ($o open / $c close)"
        qbad=1
    fi
done < <(find config/quickshell -name '*.qml' 2>/dev/null)
[ "$qbad" = 0 ] && ok "all balanced"

sec "QML js imports resolve"
ibad=0
while read -r q; do
    d=$(dirname "$q")
    grep -ohE 'import "[^"]+\.js"' "$q" 2>/dev/null | sed 's|import "||;s|"||' | while read -r rel; do
        [ -f "$d/$rel" ] || echo "$q -> $rel"
    done
done < <(find config/quickshell -name '*.qml' 2>/dev/null) >/tmp/.audit-imp
if [ -s /tmp/.audit-imp ]; then
    while read -r l; do bad "missing import: $l"; done </tmp/.audit-imp
    ibad=1
fi
rm -f /tmp/.audit-imp
[ "$ibad" = 0 ] && ok "all resolve"

sec "dangling links this repo owns"
# Electron apps leave broken SingletonCookie/SingletonLock links by design;
# only links pointing into the nix store or this repo are ours to worry about
dang=$(find -L "$HOME/.config" -maxdepth 2 -type l 2>/dev/null \
    | while read -r l; do
        tgt=$(readlink "$l")
        case "$tgt" in /nix/store/*|"$DOTS"/*) echo "$l -> $tgt" ;; esac
      done | head -10)
if [ -n "$dang" ]; then
    printf '%s\n' "$dang" | while read -r d; do bad "broken: $d"; done
else
    ok "none"
fi

sec "vendored upstream cruft"
for junk in config/quickshell/rise/.github config/quickshell/rise/install.sh \
            config/quickshell/rise/uninstall.sh config/quickshell/rise/tests; do
    [ -e "$junk" ] && warn "shipped but unused: $junk"
done
[ -f config/quickshell/rise/LICENSE ] && ok "upstream LICENSE retained (required by MIT)"

sec "repo size"
printf '  %s total, %s in themes, %s in .git\n' \
    "$(du -sh . 2>/dev/null | cut -f1)" \
    "$(du -sh config/themes 2>/dev/null | cut -f1)" \
    "$(du -sh .git 2>/dev/null | cut -f1)"

sec "flake"
if command -v nix >/dev/null 2>&1; then
    if nix flake check --no-build 2>/dev/null; then ok "flake check passed"; else warn "flake check reported problems"; fi
fi

sec "templates"
if [ -n "${DOTS_AUDIT_SKIP_TEMPLATES:-}" ]; then
    warn "skipped (DOTS_AUDIT_SKIP_TEMPLATES set)"
elif ! command -v nix >/dev/null 2>&1; then
    warn "nix not on PATH"
else
    for t in templates/*/; do
        n=$(basename "$t")
        [ -f "$t/flake.nix" ] || continue
        case "$n" in
            typst) args="" ;;
            *) args="--all-systems" ;;
        esac
        # shellcheck disable=SC2086
        if nix flake check $args "./$t" >/dev/null 2>&1; then
            ok "$n"
        else
            bad "$n does not evaluate"
        fi
    done
fi

printf '\n'
[ "$fail" = 0 ] && echo "dots-audit: clean" || echo "dots-audit: issues found"
exit 0
