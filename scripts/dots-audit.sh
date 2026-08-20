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
if [ -n "$(git status --porcelain)" ]; then
    warn "working tree dirty — the flake only sees tracked files"
    git status --short | head -10 | sed 's/^/       /'
else
    ok "working tree clean"
fi
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    bad "untracked files present; 'nh os switch' will not see them"
    git ls-files --others --exclude-standard | head -10 | sed 's/^/       /'
fi

sec "nix module wiring"
for f in home/*.nix modules/*.nix; do
    [ -f "$f" ] || continue
    base="./$(basename "$f")"
    case "$f" in home/home.nix|modules/*) continue ;; esac
    if ! grep -qF "$base" home/home.nix 2>/dev/null; then
        warn "$f is not imported by home/home.nix (dead module?)"
    fi
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
    warn "shellcheck not installed; skipping"
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

sec "dangling symlinks under ~/.config"
dang=$(find -L "$HOME/.config" -maxdepth 2 -type l 2>/dev/null | head -10)
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
printf '  %s total, %s in themes\n' "$(du -sh . 2>/dev/null | cut -f1)" \
    "$(du -sh config/themes 2>/dev/null | cut -f1)"

sec "flake"
if command -v nix >/dev/null 2>&1; then
    if nix flake check --no-build 2>/dev/null; then ok "flake check passed"; else warn "flake check reported problems"; fi
fi

printf '\n'
[ "$fail" = 0 ] && echo "dots-audit: clean" || echo "dots-audit: issues found"
exit 0
