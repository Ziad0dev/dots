#!/usr/bin/env bash
set -uo pipefail

REPO="https://github.com/HANCORE-linux/quickshell-dots.git"
DOTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$DOTS/config/quickshell/rise"
REVFILE="$VENDOR/.upstream-rev"
UPSTREAM_SUBDIR="versions/V1/variants/V2"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rise-upstream"

die() { echo "rise-upstream: $*" >&2; exit 1; }

[ -f "$REVFILE" ] || die "no $REVFILE — run '$0 pin <rev-or-tag>' first"
PINNED="$(grep -v '^#' "$REVFILE" | tr -d '[:space:]')"

sync_cache() {
    if [ ! -d "$CACHE" ]; then
        git clone --quiet --filter=blob:none --no-checkout "$REPO" "$CACHE" \
            || die "clone failed"
    fi
    git -C "$CACHE" fetch --quiet --tags origin || die "fetch failed"
}

resolve() { git -C "$CACHE" rev-parse --quiet --verify "$1^{commit}"; }

vendored_files() {
    git -C "$CACHE" ls-tree -r --name-only "$PINNED" -- "$UPSTREAM_SUBDIR" \
        | sed "s|^$UPSTREAM_SUBDIR/||"
}

cmd_status() {
    sync_cache
    local head
    head="$(resolve origin/HEAD || resolve origin/main)"
    echo "pinned:   $PINNED  ($(git -C "$CACHE" log -1 --format='%ad %s' --date=short "$PINNED"))"
    echo "upstream: $head  ($(git -C "$CACHE" log -1 --format='%ad %s' --date=short "$head"))"
    local behind
    behind="$(git -C "$CACHE" rev-list --count "$PINNED..$head" -- "$UPSTREAM_SUBDIR")"
    echo "behind:   $behind commit(s) touching $UPSTREAM_SUBDIR"
    [ "$behind" -gt 0 ] && git -C "$CACHE" log --oneline "$PINNED..$head" -- "$UPSTREAM_SUBDIR" | sed 's/^/    /'

    echo
    echo "vendored files vs pinned upstream:"
    local same=0 diff=0 gone=0
    while read -r f; do
        [ -n "$f" ] || continue
        if [ ! -e "$VENDOR/$f" ]; then
            echo "    absent   $f"; gone=$((gone + 1)); continue
        fi
        if git -C "$CACHE" show "$PINNED:$UPSTREAM_SUBDIR/$f" 2>/dev/null \
             | diff -q - "$VENDOR/$f" >/dev/null 2>&1; then
            same=$((same + 1))
        else
            echo "    modified $f"; diff=$((diff + 1))
        fi
    done < <(vendored_files)
    echo "    ($same identical, $diff modified, $gone not vendored)"
}

cmd_diff() {
    sync_cache
    local target="${1:-}"
    while read -r f; do
        [ -n "$f" ] || continue
        [ -n "$target" ] && [ "$f" != "$target" ] && continue
        [ -e "$VENDOR/$f" ] || continue
        git -C "$CACHE" show "$PINNED:$UPSTREAM_SUBDIR/$f" 2>/dev/null \
            | diff -u --label "upstream/$f" --label "rise/$f" - "$VENDOR/$f"
    done < <(vendored_files)
}

cmd_ahead() {
    sync_cache
    local head rev
    head="$(resolve origin/HEAD || resolve origin/main)"
    rev="${1:-$head}"
    git -C "$CACHE" diff --stat "$PINNED" "$rev" -- "$UPSTREAM_SUBDIR"
}

cmd_pin() {
    [ $# -eq 1 ] || die "usage: $0 pin <rev-or-tag>"
    sync_cache
    local rev
    rev="$(resolve "$1")" || die "cannot resolve $1"
    printf '%s\n' "$rev" > "$REVFILE"
    echo "rise-upstream: pinned to $rev ($1)"
}

case "${1:-status}" in
    status) cmd_status ;;
    diff)   shift; cmd_diff "$@" ;;
    ahead)  shift; cmd_ahead "$@" ;;
    pin)    shift; cmd_pin "$@" ;;
    *)      die "usage: $0 {status|diff [file]|ahead [rev]|pin <rev>}" ;;
esac
