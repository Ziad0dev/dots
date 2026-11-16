REPO="${DOTS_WALLPAPERS_REPO:-https://github.com/dusklinux/images}"
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dots/dusky-images"
WP="$HOME/Pictures/wallpapers"

die() {
    printf 'dots-wallpapers: %s\n' "$1" >&2
    exit 1
}

sets_for() {
    case "${1:-dark}" in
        dark) echo dark ;;
        light) echo light ;;
        all) echo dark light ;;
        *) die "usage: dots-wallpapers sync [dark|light|all]" ;;
    esac
}

verify() {
    local f magic bad=0
    while IFS= read -r -d '' f; do
        magic=$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')
        case "$magic" in
            ffd8ff* | 89504e47) ;;
            *)
                rm -f "$f"
                bad=$((bad + 1))
                ;;
        esac
    done < <(find "$DIR" -path "$DIR/.git" -prune -o -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0)
    if [ "$bad" -gt 0 ]; then
        printf 'dots-wallpapers: removed %s files that were not really JPEG/PNG\n' "$bad" >&2
    fi
}

link_sets() {
    local s
    mkdir -p "$WP"
    for s in dark light; do
        if [[ " $* " == *" $s "* ]]; then
            ln -sfn "$DIR/$s" "$WP/dusky-$s"
        elif [ -L "$WP/dusky-$s" ]; then
            rm -f "$WP/dusky-$s"
        fi
    done
}

cmd_sync() {
    local sets
    read -r -a sets <<<"$(sets_for "${1:-}")"
    if [ ! -d "$DIR/.git" ]; then
        mkdir -p "${DIR%/*}"
        git clone --depth 1 --filter=blob:none --sparse --quiet "$REPO" "$DIR"
    fi
    git -C "$DIR" sparse-checkout set "${sets[@]}"
    git -C "$DIR" fetch --depth 1 --quiet origin main
    if git -C "$DIR" ls-tree -r FETCH_HEAD | awk '$1 == "120000" { found = 1 } END { exit !found }'; then
        die "upstream now contains symlinks; refusing to check it out"
    fi
    git -C "$DIR" reset --hard --quiet FETCH_HEAD
    verify
    git -C "$DIR" reflog expire --expire=now --all
    git -C "$DIR" gc --prune=now --quiet
    link_sets "${sets[@]}"
    cmd_status
}

cmd_status() {
    local s n
    [ -d "$DIR/.git" ] || { echo "not synced"; return; }
    for s in dark light; do
        if [ -L "$WP/dusky-$s" ]; then
            n=$(find -L "$WP/dusky-$s" -maxdepth 1 -type f | wc -l)
            printf '%s: %s images in %s\n' "$s" "$n" "$WP/dusky-$s"
        fi
    done
    printf 'on disk: %s\n' "$(du -sh "$DIR" | cut -f1)"
}

cmd_remove() {
    rm -f "$WP/dusky-dark" "$WP/dusky-light"
    rm -rf "$DIR"
    echo removed
}

case "${1:-}" in
    sync) cmd_sync "${2:-}" ;;
    status | "") cmd_status ;;
    remove) cmd_remove ;;
    *) die "usage: dots-wallpapers {sync [dark|light|all]|status|remove}" ;;
esac
