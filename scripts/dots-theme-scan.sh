shopt -s nullglob

CACHE="$HOME/.cache/quickshell-theme-picker"
SWATCH="$HOME/.cache/quickshell-theme-swatches"
THUMBS="$HOME/.cache/quickshell-img-thumbs"
HASHCACHE="$HOME/.cache/quickshell-img-thumb-hashes.tsv"
mkdir -p "$CACHE" "$SWATCH" "$THUMBS"
touch "$HASHCACHE"

hash_for() {
    local s="$1" r m key h tmp
    r=$(readlink -f "$s" 2>/dev/null || printf '%s' "$s")
    m=$(stat -Lc '%s:%Y:%Z' "$s" 2>/dev/null) || return 1
    key="$r|$m"
    h=$(awk -F '\t' -v k="$key" '$1 == k { v = $2 } END { print v }' "$HASHCACHE" 2>/dev/null)
    if [ -z "$h" ]; then
        h=$(sha256sum "$s" 2>/dev/null | cut -d' ' -f1)
        [ -n "$h" ] || return 1
        tmp="$HASHCACHE.$$"
        {
            awk -F '\t' -v k="$key" '$1 != k' "$HASHCACHE" 2>/dev/null
            printf '%s\t%s\n' "$key" "$h"
        } >"$tmp" && mv -f "$tmp" "$HASHCACHE"
    fi
    printf '%s' "$h"
}

thumb_for() {
    local k
    k=$(hash_for "$1") || return 1
    printf '%s/%s-512.jpg' "$THUMBS" "$k"
}

pick_color() {
    local f="$1" k v
    shift
    for k in "$@"; do
        v=$(sed -nE "s/^[[:space:]]*(export[[:space:]]+)?${k}[[:space:]]*=[[:space:]]*\"?(#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?)\"?[[:space:]]*\$/\\2/p" "$f" | head -n1)
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    done
    return 0
}

swatch_for() {
    local name="$1" pal="$2" out row bg k v
    out="$SWATCH/$name.png"
    command -v magick >/dev/null 2>&1 || return 1
    if [ -f "$out" ] && [ "$out" -nt "$pal" ]; then
        printf '%s' "$out"
        return 0
    fi
    bg=$(pick_color "$pal" background bg color00 base)
    [ -n "$bg" ] || bg="#161616"
    local args=()
    for k in color1 color2 color3 color4 color5 color6; do
        v=$(pick_color "$pal" "$k" "${k/color/colour}")
        if [ -n "$v" ]; then
            args+=('(' -size 80x160 "xc:$v" ')')
        fi
    done
    row="$SWATCH/.row-$name.png"
    if [ "${#args[@]}" -gt 0 ]; then
        magick "${args[@]}" +append "$row" >/dev/null 2>&1 || return 1
        magick -size 512x288 "xc:$bg" "$row" -gravity center -composite "$out" >/dev/null 2>&1 || return 1
        rm -f "$row"
    else
        magick -size 512x288 "xc:$bg" "$out" >/dev/null 2>&1 || return 1
    fi
    printf '%s' "$out"
}

scan_root() {
    local d name pal prev pin ext link cur old thumb bgs
    for d in "$1"/*; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        pal="$d/theme.sh"
        [ -f "$pal" ] || pal="$d/colors.sh"
        [ -f "$pal" ] || continue

        prev=""
        for c in "$d"/preview.png "$d"/preview.jpg "$d"/preview.jpeg "$d"/preview.webp; do
            if [ -f "$c" ]; then
                prev="$c"
                break
            fi
        done

        if [ -z "$prev" ]; then
            bgs=("$d"/backgrounds/*.jpg "$d"/backgrounds/*.jpeg "$d"/backgrounds/*.png "$d"/backgrounds/*.webp)
            prev="${bgs[0]-}"
        fi

        if [ -z "$prev" ]; then
            pin=$(sed -nE 's/^[[:space:]]*(export[[:space:]]+)?wallpaper[[:space:]]*=[[:space:]]*"?([^"]+)"?[[:space:]]*$/\2/p' "$pal" | head -n1 || true)
            pin="${pin/#\~/$HOME}"
            if [ -n "$pin" ] && [ -f "$pin" ]; then
                prev="$pin"
            fi
        fi

        if [ -z "$prev" ]; then
            prev=$(swatch_for "$name" "$pal") || prev=""
        fi
        [ -n "$prev" ] || continue

        ext="${prev##*.}"
        link="$CACHE/$name.$ext"
        for old in "$CACHE/$name".*; do
            [ "$old" = "$link" ] || rm -f "$old"
        done
        cur=$(readlink "$link" 2>/dev/null || true)
        [ "$cur" = "$prev" ] || ln -sfn "$prev" "$link"

        thumb=$(thumb_for "$link") || continue
        printf '%s\t%s\t%s\n' "$link" "$thumb" "$d"
    done
}

for r in "$@"; do
    if [ -d "$r" ]; then
        scan_root "$r"
    fi
done | sort -u
