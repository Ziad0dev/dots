DOTS="${DOTS_DIR:-$HOME/dots}"
THEMES="$DOTS/config/themes"
TPL="$THEMES/_templates"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme"
CURRENT="$STATE/current"

PALETTE_KEYS="background foreground cursor accent selection_foreground selection_background
color0 color1 color2 color3 color4 color5 color6 color7
color8 color9 color10 color11 color12 color13 color14 color15
bg fg
base00 base01 base02 base03 base04 base05 base06 base07
base08 base09 base0A base0B base0C base0D base0E base0F
red green yellow blue magenta cyan pink"

DERIVED_KEYS="dim muted surface"

mix() {
    local a="${1#\#}" b="${2#\#}" w="$3" i ca cb r out="#"
    for i in 0 2 4; do
        ca=$((16#${a:$i:2}))
        cb=$((16#${b:$i:2}))
        r=$(((ca * (100 - w) + cb * w) / 100))
        out="$out$(printf '%02x' "$r")"
    done
    printf '%s' "$out"
}

die() {
    printf 'themectl: %s\n' "$1" >&2
    exit 1
}

theme_dir() { printf '%s/%s' "$THEMES" "$1"; }

palette_file() {
    local d
    d=$(theme_dir "$1")
    if [ -f "$d/colors.sh" ]; then
        printf '%s/colors.sh' "$d"
    elif [ -f "$d/theme.sh" ]; then
        printf '%s/theme.sh' "$d"
    else
        return 1
    fi
}

cmd_list() {
    local d
    for d in "$THEMES"/*/; do
        d="${d%/}"
        [ "$(basename "$d")" = "_templates" ] && continue
        palette_file "$(basename "$d")" >/dev/null 2>&1 || continue
        basename "$d"
    done | sort
}

cmd_current() {
    if [ -f "$CURRENT" ]; then
        cat "$CURRENT"
    else
        cmd_list | head -n1
    fi
}

render_all() {
    local name="$1" pal t out varlist k
    pal=$(palette_file "$name") || die "no colors.sh or theme.sh in theme '$name'"

    varlist=""
    for k in $PALETTE_KEYS $DERIVED_KEYS; do varlist="$varlist\${$k}\${${k}_hex}"; done

    mkdir -p "$STATE"
    for t in "$TPL"/*.in; do
        [ -f "$t" ] || continue
        out="$STATE/$(basename "${t%.in}")"
        # shellcheck source=/dev/null
        (
            set -a
            . "$pal"
            # shellcheck disable=SC2154,SC2034  # palette vars come from the sourced colors.sh
            dim=$(mix "$foreground" "$background" 35)
            # shellcheck disable=SC2034
            muted=$(mix "$foreground" "$background" 60)
            # shellcheck disable=SC2034
            surface=$(mix "$background" "$foreground" 8)
            for k in $PALETTE_KEYS $DERIVED_KEYS; do
                printf -v "${k}_hex" "%s" "${!k#\#}"
            done
            set +a
            envsubst "$varlist" <"$t"
        ) >"$out.tmp" && mv -f "$out.tmp" "$out"

        if grep -qE '\$\{[A-Za-z_]' "$out"; then
            printf 'themectl: warning: unsubstituted tokens remain in %s\n' "$out" >&2
            grep -noE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "$out" | head -n5 >&2
        fi
    done
}

# Build the ~/.config/omarchy tree the vendored Quickshell Rise shell reads.
# colors.sh is already a valid colors.toml for its parser, so it is symlinked
# rather than converted. The shell scans ~/.config/omarchy/themes/* for themes
# and reads backgrounds from <theme>/backgrounds.
# ln -sfn into a path that is a real directory creates the link INSIDE it
# instead of replacing it, so clear non-symlink targets first.
relink() {
    [ -L "$2" ] || rm -rf "$2"
    ln -sfn "$1" "$2"
}

omarchy_compat() {
    local current="$1" oroot troot d name pal prev wp bg
    oroot="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
    troot="$oroot/themes"
    bg="$HOME/Pictures/wallpapers"
    mkdir -p "$troot" "$oroot/backgrounds"

    for d in "$THEMES"/*/; do
        d="${d%/}"
        name=$(basename "$d")
        [ "$name" = "_templates" ] && continue
        pal=$(palette_file "$name") || continue

        mkdir -p "$troot/$name"
        relink "$pal" "$troot/$name/colors.toml"
        relink "$bg" "$troot/$name/backgrounds"
        relink "$bg" "$oroot/backgrounds/$name"

        for prev in "$d/preview.png" "$d/preview.jpg"; do
            if [ -f "$prev" ]; then
                relink "$prev" "$troot/$name/preview.png"
                break
            fi
        done
    done

    mkdir -p "$oroot/current"
    printf '%s\n' "$current" >"$oroot/current/theme.name"
    relink "$troot/$current" "$oroot/current/theme"

    if wp=$(theme_wallpaper "$current"); then
        relink "$wp" "$oroot/current/background"
    elif wp=$(dots-current-wallpaper 2>/dev/null) && [ -n "$wp" ]; then
        relink "$wp" "$oroot/current/background"
    fi
}

reload_apps() {
    pkill -SIGUSR2 waybar 2>/dev/null || true
    pkill -SIGUSR2 ghostty 2>/dev/null || true

    if command -v qs >/dev/null 2>&1; then
        qs -c picker ipc call picker reload >/dev/null 2>&1 || true
    fi

    if command -v dunstctl >/dev/null 2>&1; then
        dunstctl reload "$HOME/.config/dunst/dunstrc" "$STATE/dunstrc" 2>/dev/null || true
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
}

theme_wallpaper() {
    local d f
    d=$(theme_dir "$1")
    for f in "$d"/wallpaper.jpg "$d"/wallpaper.jpeg "$d"/wallpaper.png "$d"/wallpaper.webp; do
        if [ -f "$f" ]; then
            printf '%s' "$f"
            return 0
        fi
    done
    return 1
}

cmd_set() {
    local name="$1" wp
    [ -n "$name" ] || die "usage: themectl set <name>"
    [ -d "$(theme_dir "$name")" ] || die "no such theme: $name"

    render_all "$name"
    mkdir -p "$STATE"
    printf '%s\n' "$name" >"$CURRENT"
    omarchy_compat "$name"
    reload_apps

    if wp=$(theme_wallpaper "$name"); then
        if command -v dots-set-wallpaper >/dev/null 2>&1; then
            dots-set-wallpaper "$wp" || true
        fi
    fi
}

cmd_step() {
    local delta="$1" cur idx n list
    mapfile -t list < <(cmd_list)
    n="${#list[@]}"
    [ "$n" -gt 0 ] || die "no themes found in $THEMES"
    cur=$(cmd_current)
    idx=0
    for i in "${!list[@]}"; do
        if [ "${list[$i]}" = "$cur" ]; then
            idx="$i"
            break
        fi
    done
    idx=$(((idx + delta + n) % n))
    cmd_set "${list[$idx]}"
}

wallpapers() {
    find -L "$HOME/Pictures/wallpapers" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | sort
}

cmd_bg() {
    local sub="${1:-}" cur list idx n
    case "$sub" in
        set)
            [ -n "${2:-}" ] || die "usage: themectl bg set <path>"
            dots-set-wallpaper "$2"
            ;;
        next | prev)
            mapfile -t list < <(wallpapers)
            n="${#list[@]}"
            [ "$n" -gt 0 ] || die "no wallpapers found"
            cur=$(dots-current-wallpaper 2>/dev/null || true)
            idx=0
            for i in "${!list[@]}"; do
                if [ "${list[$i]}" = "$cur" ]; then
                    idx="$i"
                    break
                fi
            done
            if [ "$sub" = "next" ]; then idx=$(((idx + 1) % n)); else idx=$(((idx - 1 + n) % n)); fi
            dots-set-wallpaper "${list[$idx]}"
            ;;
        "")
            dots-current-wallpaper
            ;;
        *)
            die "usage: themectl bg [set <path>|next|prev]"
            ;;
    esac
}

case "${1:-}" in
    set) cmd_set "${2:-}" ;;
    current) cmd_current ;;
    list) cmd_list ;;
    next) cmd_step 1 ;;
    prev) cmd_step -1 ;;
    reload) cmd_set "$(cmd_current)" ;;
    bg) shift; cmd_bg "$@" ;;
    *) die "usage: themectl {set <name>|current|list|next|prev|reload|bg [set <path>|next|prev]}" ;;
esac
