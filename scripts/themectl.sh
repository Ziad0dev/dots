DOTS="${DOTS_DIR:-$HOME/dots}"
THEMES="$DOTS/config/themes"
TPL="$THEMES/_templates"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme"
CURRENT="$STATE/current"
AUTO="${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme-auto"

PALETTE_KEYS="background foreground cursor accent selection_foreground selection_background
color0 color1 color2 color3 color4 color5 color6 color7
color8 color9 color10 color11 color12 color13 color14 color15
bg fg
base00 base01 base02 base03 base04 base05 base06 base07
base08 base09 base0A base0B base0C base0D base0E base0F
red green yellow blue magenta cyan pink"

DERIVED_KEYS="dim muted surface accent_dim accent_container"

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

theme_dir() {
    if [ "$1" = auto ]; then
        printf '%s' "$AUTO"
    else
        printf '%s/%s' "$THEMES" "$1"
    fi
}

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
    echo auto
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

    # a missing key would abort every template under set -u and leave the
    # previous theme's files in place, so refuse up front and name them
    local missing
    # shellcheck source=/dev/null
    missing=$(
        . "$pal"
        for k in $PALETTE_KEYS; do [ -n "${!k:-}" ] || printf ' %s' "$k"; done
    )
    [ -z "$missing" ] || die "theme '$name' is missing palette keys:$missing"

    varlist=""
    for k in $PALETTE_KEYS $DERIVED_KEYS; do varlist="$varlist\${$k}\${${k}_hex}\${${k}_rgb}"; done

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
            # shellcheck disable=SC2034,SC2154
            accent_dim=$(mix "$accent" "$background" 25)
            # shellcheck disable=SC2034
            accent_container=$(mix "$accent" "$background" 72)
            for k in $PALETTE_KEYS $DERIVED_KEYS; do
                h="${!k#\#}"
                printf -v "${k}_hex" "%s" "$h"
                if [[ "$h" =~ ^[0-9a-fA-F]{6} ]]; then
                    printf -v "${k}_rgb" "%d %d %d" "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
                else
                    printf -v "${k}_rgb" "%s" "0 0 0"
                fi
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

# ln -sfn into a path that is a real directory creates the link INSIDE it
# instead of replacing it, so clear non-symlink targets first.
relink() {
    [ -L "$2" ] || rm -rf "$2"
    ln -sfn "$1" "$2"
}

# State tree the vendored Quickshell Rise shell reads after denix-rise.sh.
# It wants <root>/theme.name, <root>/theme/colors.sh, <root>/theme/backgrounds
# and <root>/background.
shell_compat() {
    local current="$1" root theme pal wp bg d name
    root="${XDG_STATE_HOME:-$HOME/.local/state}/dots/shell/current"
    theme="$root/theme"
    bg="$HOME/Pictures/wallpapers"
    mkdir -p "$theme"

    pal=$(palette_file "$current") || return 0
    printf '%s\n' "$current" >"$root/theme.name"
    relink "$pal" "$theme/colors.sh"
    relink "$bg" "$theme/backgrounds"

    d=$(theme_dir "$current")
    for name in "$d/preview.png" "$d/preview.jpg"; do
        if [ -f "$name" ]; then
            relink "$name" "$theme/preview.png"
            break
        fi
    done

    if wp=$(theme_wallpaper "$current"); then
        relink "$wp" "$root/background"
    elif wp=$(dots-current-wallpaper 2>/dev/null) && [ -n "$wp" ]; then
        relink "$wp" "$root/background"
    fi
}

sddm_compat() {
    local pal dir="/var/lib/dots-theme"
    [ -w "$dir" ] || return 0
    pal=$(palette_file "$1") || return 0
    # shellcheck source=/dev/null
    (
        . "$pal"
        # the live wallpaper copy is rendered by dots-set-wallpaper
        wp=""
        [ -f "$dir/wallpaper.jpg" ] && wp="file://$dir/wallpaper.jpg"
        # shellcheck disable=SC2154
        printf '{"background":"%s","foreground":"%s","accent":"%s","error":"%s","warn":"%s","wallpaper":"%s"}\n' \
            "$background" "$foreground" "$accent" "$red" "$yellow" "$wp"
    ) >"$dir/sddm.json.tmp" && mv -f "$dir/sddm.json.tmp" "$dir/sddm.json"
}
kvantum_compat() {
    local out dir
    out="$STATE/kvantum.kvconfig"
    [ -f "$out" ] || return 0
    dir="${XDG_CONFIG_HOME:-$HOME/.config}/Kvantum/KvGlass#"
    mkdir -p "$dir"
    relink "$out" "$dir/KvGlass#.kvconfig"
}
gtk_compat() {
    local out d
    out="$STATE/gtk.css"
    [ -f "$out" ] || return 0
    for d in "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0" "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"; do
        mkdir -p "$d"
        cp -f "$out" "$d/gtk.css"
    done
}
vencord_compat() {
    local out dst
    out="$STATE/vencord-quickcss.css"
    dst="${XDG_CONFIG_HOME:-$HOME/.config}/Vencord/settings/quickCss.css"
    [ -f "$out" ] || return 0
    [ -d "${dst%/*}" ] || return 0
    if [ -L "$dst" ]; then
        rm -f "$dst"
    fi
    cp -f "$out" "$dst" || return 0
}
zen_compat() {
    local sites="$DOTS/config/zen/sites" out="$STATE/zen-sites.css" f
    [ -d "$sites" ] || return 0
    for f in "$sites"/*.css; do
        [ -f "$f" ] && cat "$f"
    done >"$out.tmp" && mv -f "$out.tmp" "$out"
}

gen_auto() {
    local wp="${1:-}" json
    if [ -z "$wp" ]; then
        wp=$(dots-current-wallpaper 2>/dev/null) || true
    fi
    if [ -z "$wp" ] || [ ! -f "$wp" ]; then
        die "auto: no wallpaper to sample"
    fi
    json=$(matugen image "$wp" --json hex --dry-run --source-color-index 0 --mode dark 2>/dev/null) ||
        die "auto: matugen failed on $wp"
    mkdir -p "$AUTO"
    jq -r '
        def m($k): .colors[$k].default.color[0:7];
        def b($k): .base16[$k].default.color[0:7];
        [
          ["background", m("surface")], ["foreground", m("on_surface")],
          ["cursor", m("primary")], ["accent", m("primary")],
          ["selection_foreground", m("on_primary_container")], ["selection_background", m("primary_container")],
          ["color0", m("surface_container")], ["color1", m("error")], ["color2", b("base0b")],
          ["color3", b("base0a")], ["color4", b("base0d")], ["color5", b("base0e")], ["color6", b("base0c")],
          ["color7", m("on_surface_variant")], ["color8", m("outline")], ["color9", m("error")],
          ["color10", b("base0b")], ["color11", b("base0a")], ["color12", b("base0d")],
          ["color13", b("base0e")], ["color14", b("base0c")], ["color15", m("on_surface")],
          ["bg", m("surface")], ["fg", m("on_surface")],
          ["base00", m("surface")], ["base01", m("surface_container_low")], ["base02", m("surface_container_high")],
          ["base03", m("outline_variant")], ["base04", m("on_surface_variant")], ["base05", m("on_surface")],
          ["base06", m("on_primary_container")], ["base07", m("inverse_surface")],
          ["base08", b("base08")], ["base09", b("base09")], ["base0A", b("base0a")], ["base0B", b("base0b")],
          ["base0C", b("base0c")], ["base0D", b("base0d")], ["base0E", b("base0e")], ["base0F", b("base0f")],
          ["red", m("error")], ["green", b("base0b")], ["yellow", b("base0a")], ["blue", b("base0d")],
          ["magenta", b("base0e")], ["cyan", b("base0c")], ["pink", m("tertiary")]
        ][] | "\(.[0])=\"\(.[1])\""
    ' <<<"$json" >"$AUTO/colors.sh.tmp"
    if grep -qvE '^[A-Za-z0-9_]+="#[0-9a-fA-F]{6}"$' "$AUTO/colors.sh.tmp" ||
        [ "$(grep -c . "$AUTO/colors.sh.tmp")" -ne 47 ]; then
        rm -f "$AUTO/colors.sh.tmp"
        die "auto: matugen output was missing colours"
    fi
    mv -f "$AUTO/colors.sh.tmp" "$AUTO/colors.sh"
}

reload_apps() {

    pkill -SIGUSR2 ghostty 2>/dev/null || true

    if command -v qs >/dev/null 2>&1; then
        qs -c rise ipc call theme reload >/dev/null 2>&1 || true
    fi


    # flip the GTK theme so running GTK apps re-read gtk.css (via dconf: no
    # GSettings schemas are installed, so gsettings itself can't do this)
    if command -v dconf >/dev/null 2>&1; then
        local key=/org/gnome/desktop/interface/gtk-theme t
        t=$(dconf read "$key" 2>/dev/null)
        if [ -n "$t" ]; then
            dconf write "$key" "''" >/dev/null 2>&1 || true
            dconf write "$key" "$t" >/dev/null 2>&1 || true
        fi
    fi

    # btop re-reads btop.conf and its theme file on SIGUSR2 (checked on 1.4.7)
    pkill -USR2 -x btop >/dev/null 2>&1 || true

    if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
        tmux source-file -q "$STATE/tmux.conf" >/dev/null 2>&1 || true
    fi

    # sway only; quickshell owns notifications under Hyprland
    if systemctl --user is-active --quiet dunst.service 2>/dev/null; then
        systemctl --user start dotsDunstTheme.service >/dev/null 2>&1 || true
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi

    if [ -n "${SWAYSOCK:-}" ] && command -v swaymsg >/dev/null 2>&1; then
        swaymsg reload >/dev/null 2>&1 || true
    fi
    if [ -x "$HOME/.config/sway/status.sh" ] && pgrep i3status-rs >/dev/null 2>&1; then
        if "$HOME/.config/sway/status.sh" build; then
            pkill -USR2 i3status-rs 2>/dev/null || true
        fi
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user try-restart swayosd.service 2>/dev/null || true
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
    if [ "$name" = auto ]; then
        gen_auto "${2:-}"
    fi
    [ -d "$(theme_dir "$name")" ] || die "no such theme: $name"

    render_all "$name"
    mkdir -p "$STATE"
    printf '%s\n' "$name" >"$CURRENT"
    shell_compat "$name"
    sddm_compat "$name"
    kvantum_compat "$name"
    gtk_compat
    vencord_compat
    zen_compat
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
    find -L "$HOME/Pictures/wallpapers" -maxdepth 2 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | sort
}

follow_wallpaper() {
    [ "$(cmd_current)" = auto ] || return 0
    cmd_set auto "$1"
}

cmd_bg() {
    local sub="${1:-}" cur list idx n
    case "$sub" in
        set)
            [ -n "${2:-}" ] || die "usage: themectl bg set <path>"
            dots-set-wallpaper "$2"
            follow_wallpaper "$2"
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
            follow_wallpaper "${list[$idx]}"
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
    set) cmd_set "${2:-}" "${3:-}" ;;
    current) cmd_current ;;
    list) cmd_list ;;
    next) cmd_step 1 ;;
    prev) cmd_step -1 ;;
    reload) cmd_set "$(cmd_current)" ;;
    bg) shift; cmd_bg "$@" ;;
    *) die "usage: themectl {set <name>|set auto [image]|current|list|next|prev|reload|bg [set <path>|next|prev]}" ;;
esac
