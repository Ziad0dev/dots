# dots-appearance: GTK/Kvantum theme, icons, cursor and fonts for the whole
# desktop, from one place (rise's Themes panel → App style, or this CLI).
#
#   dots-appearance state            JSON: current theme, its look, your
#                                    choices and what's in effect
#   dots-appearance lists            JSON: installed GTK/Kvantum/icon/cursor
#                                    themes and font families (icon previews)
#   dots-appearance set KEY [VALUE]  choose (no VALUE: follow the theme again)
#   dots-appearance reset            follow the theme for everything
#   dots-appearance apply [--quiet]  push what's in effect to the apps
#
# KEY: gtk kvantum icons cursor cursor_size font font_size mono mono_size
#
# `lists` also carries .picks: a short list per key (PICKS below, installed
# ones only), shown as Quick picks in App style.
#
# Each value is your choice, else the colour theme's (config/themes/<name>/
# look.conf, same keys), else the default below. Fonts with no value anywhere
# are left to the system (NixOS fonts.fontconfig.defaultFonts).
#
# Where it goes: GTK through dconf (the settings portal makes it live; the
# GTK theme reaches GTK 3 and plain GTK 4 apps, libadwaita ones only take
# themectl's gtk.css colours), Qt through qt5ct/qt6ct.conf and Kvantum's
# kvantum.kvconfig (new windows), fontconfig's sans-serif and
# monospace (new windows), Hyprland's cursor (live) and ghostty (live).

KEYS="gtk kvantum icons cursor cursor_size font font_size mono mono_size"
# KvGlass# is the copy themectl recolours to the current theme
declare -A DEF=(
    [gtk]=adw-gtk3-dark [kvantum]="KvGlass#"
    [icons]=candy-icons [cursor]=Bibata-Modern-Classic [cursor_size]=24
    [font]="" [font_size]=11 [mono]="" [mono_size]=""
)

# quick picks per key, best first: chosen for legibility (fonts) and for
# going with the colour themes (the rest). `lists` keeps the installed ones.
declare -A PICKS=(
    [font]="Inter Variable|Atkinson Hyperlegible Next|Lexend|IBM Plex Sans|Source Sans 3|Noto Sans"
    [mono]="JetBrainsMono Nerd Font|Iosevka Nerd Font|SauceCodePro Nerd Font|BlexMono Nerd Font|CommitMono Nerd Font|Atkinson Hyperlegible Mono|Hack Nerd Font"
    [icons]="candy-icons|Papirus-Dark|Tela-circle-dark|Colloid-Dark|Papirus-Light|Tela-circle-light"
    [cursor]="Bibata-Modern-Classic|Bibata-Modern-Ice|phinger-cursors-dark|phinger-cursors-light|Sweet-cursors|catppuccin-mocha-dark-cursors"
    [gtk]="adw-gtk3-dark|adw-gtk3|Sweet-Dark-v40|catppuccin-mocha-blue-standard|Nordic|Dracula"
    [kvantum]="KvGlass#|Sweet|Nordic|Dracula|catppuccin-mocha-blue"
)

CFG=${XDG_CONFIG_HOME:-$HOME/.config}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/dots/appearance
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/dots-appearance
CHOICE=$STATE/choice.json
THEME_STATE=${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme
THEMES=${DOTS_DIR:-$HOME/dots}/config/themes
DCONF=/org/gnome/desktop/interface

# SIGUSR2 reloads ghostty's config, but kills one that hasn't installed its
# handler yet (just launched, e.g. by autostart): skip the young ones
reload_ghostty() {
    local pid age comm
    while read -r pid age comm; do
        case "$comm" in
            *ghostty*) if [ "$age" -ge 3 ]; then kill -USR2 "$pid" 2>/dev/null || true; fi ;;
        esac
    done < <(ps -u "$(id -u)" -o pid=,etimes=,comm=)
}

die() {
    printf 'dots-appearance: %s\n' "$1" >&2
    exit 1
}

valid_key() { [[ " $KEYS " == *" $1 "* ]] || die "unknown key '$1' (one of: $KEYS)"; }

theme_name() { head -n1 "$THEME_STATE/current" 2>/dev/null || true; }

# the colour theme's look.conf as a JSON object
theme_look() {
    local f k v out='{}'
    f="$THEMES/$(theme_name)/look.conf"
    [ -f "$f" ] || { printf '{}'; return; }
    while IFS='=' read -r k v; do
        k=${k//[[:space:]]/}
        [[ -z $k || $k == \#* ]] && continue
        [[ " $KEYS " == *" $k "* ]] || continue
        v=${v#"${v%%[![:space:]]*}"}
        v=${v%"${v##*[![:space:]]}"}
        v=${v#\"}
        v=${v%\"}
        out=$(jq -c --arg k "$k" --arg v "$v" '.[$k] = $v' <<<"$out")
    done <"$f"
    printf '%s' "$out"
}

choice() { if [ -s "$CHOICE" ]; then jq -c 'if type == "object" then . else {} end' "$CHOICE" 2>/dev/null || printf '{}'; else printf '{}'; fi; }

# light or dark, as themectl worked it out from the theme's background
scheme() {
    sed -n 's/^ *--dots-color-scheme: *\([a-z]*\);.*/\1/p' "$THEME_STATE/zen-palette.css" 2>/dev/null | head -n1
}

defaults() {
    local k v out='{}'
    for k in $KEYS; do
        v=${DEF[$k]}
        # a light theme with no GTK theme of its own gets light adw-gtk3
        [ "$k" = gtk ] && [ "$(scheme)" = light ] && v=adw-gtk3
        out=$(jq -c --arg k "$k" --arg v "$v" '.[$k] = $v' <<<"$out")
    done
    printf '%s' "$out"
}

cmd_state() {
    jq -nc --arg theme "$(theme_name)" --argjson look "$(theme_look)" \
        --argjson choice "$(choice)" --argjson def "$(defaults)" '
        { theme: $theme, look: $look, choice: $choice, defaults: $def,
          effective: ($def + ($look | with_entries(select(.value != "")))
                           + ($choice | with_entries(select(.value != "")))) }'
}

eff() { cmd_state | jq -r --arg k "$1" '.effective[$k] // ""'; }

# ── lists ────────────────────────────────────────────────────────────────────
icon_dirs() {
    local d IFS=:
    for d in "$HOME/.icons" "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/run/current-system/sw/share}; do
        [ "$d" = "$HOME/.icons" ] && printf '%s\n' "$d" || printf '%s\n' "$d/icons"
    done
}

# name<TAB>dir for every theme with an index.theme, first dir wins
themes_found() {
    local d t n
    declare -A seen
    while IFS= read -r d; do
        [ -d "$d" ] || continue
        for t in "$d"/*/; do
            t=${t%/}
            n=${t##*/}
            [ -f "$t/index.theme" ] || [ -d "$t/cursors" ] || continue
            [ -n "${seen[$n]:-}" ] && continue
            seen[$n]=1
            printf '%s\t%s\n' "$n" "$t"
        done
    done < <(icon_dirs)
}

# a few icons from a theme, for its card: cached per theme dir + mtime
previews() {
    local dir=$1 key out n f
    key=$(printf '%s:%s' "$dir" "$(stat -Lc %Y "$dir" 2>/dev/null)" | md5sum | cut -c1-16)
    out=$CACHE/$key.json
    if [ ! -s "$out" ]; then
        mkdir -p "$CACHE"
        local -a want=(folder user-home utilities-terminal web-browser preferences-system multimedia-video-player text-x-generic)
        # a thin theme (Papirus-Dark-teal: folders only) shows the rest from
        # the first theme it inherits, found next to it
        local found parent search=("$dir")
        parent=$(sed -n 's/^Inherits=\([^,]*\).*/\1/p' "$dir/index.theme" 2>/dev/null | head -n1)
        [ -n "$parent" ] && [ -d "${dir%/*}/$parent" ] && search+=("${dir%/*}/$parent")
        found=$(find -L "${search[@]}" -type f \( -name '*.svg' -o -name '*.png' \) 2>/dev/null |
            grep -E "/($(IFS='|'; echo "${want[*]}"))\.(svg|png)$" |
            awk -v own="$dir/" '{ s = ($0 ~ /scalable|\/48|@2x|\/64/) ? 0 : 1; if (index($0, own) != 1) s += 2; print s "\t" $0 }' |
            sort -t$'\t' -k1,1n | cut -f2-)
        local list=()
        for n in "${want[@]}"; do
            f=$(grep -m1 -E "/$n\.(svg|png)$" <<<"$found" || true)
            [ -n "$f" ] && list+=("$f")
        done
        printf '%s\n' "${list[@]}" | jq -R . | jq -sc 'map(select(. != ""))' >"$out"
    fi
    cat "$out"
}

# GTK themes (a gtk-3.0 dir under share/themes) and Kvantum themes
# (share/Kvantum and ~/.config/Kvantum), first dir wins
gtk_themes() {
    local d IFS=:
    for d in "$HOME/.themes" "${XDG_DATA_HOME:-$HOME/.local/share}/themes" ${XDG_DATA_DIRS:-/run/current-system/sw/share}; do
        [[ $d == */themes ]] || d=$d/themes
        find -L "$d" -mindepth 2 -maxdepth 2 -name gtk-3.0 -type d -printf '%h\n' 2>/dev/null
    done | awk -F/ '!seen[$NF]++ { print $NF }' | sort -f | jq -R . | jq -sc .
}

kvantum_themes() {
    local d IFS=:
    for d in "$CFG/Kvantum" ${XDG_DATA_DIRS:-/run/current-system/sw/share}; do
        [[ $d == */Kvantum ]] || d=$d/Kvantum
        find -L "$d" -mindepth 2 -maxdepth 2 -name '*.kvconfig' -printf '%h\n' 2>/dev/null
    done | awk -F/ '!seen[$NF]++ { print $NF }' | sort -f | jq -R . | jq -sc .
}

cmd_lists() {
    local icons='[]' cursors='[]' n t
    while IFS=$'\t' read -r n t; do
        if [ -d "$t/cursors" ]; then
            cursors=$(jq -c --arg n "$n" '. + [$n]' <<<"$cursors")
        fi
        [ -f "$t/index.theme" ] || continue
        case $n in default | hicolor | locolor) continue ;; esac
        # an icon theme lists icon Directories; a cursor-only theme doesn't
        grep -qE '^Directories=.+' "$t/index.theme" || continue
        local label
        label=$(sed -n 's/^Name=//p' "$t/index.theme" | head -n1)
        icons=$(jq -c --arg n "$n" --arg l "${label:-$n}" --argjson p "$(previews "$t")" \
            '. + [{ id: $n, name: $l, previews: $p }]' <<<"$icons")
    done < <(themes_found | sort -f)
    # text fonts only: no icon/symbol fonts, and Noto's per-script families
    # (Noto Sans Bengali, …) stay behind fontconfig's fallback
    local fonts monos
    local junk='Material|Icons|Emoji|Symbols|SignWriting|Unifont|Font Awesome|^Noto (Sans|Serif|Kufi|Naskh|Nastaliq|Rashi|Music|Znamenny|Traditional|Fangsong) (?!Mono$|Display$|CJK)'
    fonts=$(fc-list --format '%{family[0]}\n' 2>/dev/null | grep -v '^$' | grep -vP "$junk" | sort -fu | jq -R . | jq -sc .)
    monos=$( { fc-list ':spacing=100' --format '%{family[0]}\n'; fc-list ':spacing=90' --format '%{family[0]}\n'; } 2>/dev/null |
        grep -v '^$' | grep -vP "$junk" | sort -fu | jq -R . | jq -sc .)
    local picks='{}' k
    for k in "${!PICKS[@]}"; do
        picks=$(jq -c --arg k "$k" --arg v "${PICKS[$k]}" '.[$k] = ($v | split("|"))' <<<"$picks")
    done
    jq -nc --argjson gtk "$(gtk_themes)" --argjson kvantum "$(kvantum_themes)" \
        --argjson icons "$icons" --argjson cursors "$cursors" --argjson fonts "$fonts" --argjson monos "$monos" \
        --argjson picks "$picks" '
        { gtk: $gtk, kvantum: $kvantum, icons: $icons, cursors: ($cursors | sort_by(ascii_downcase)), fonts: $fonts, monos: $monos }
        | . as $l
        # quick picks that are installed, in order
        | .picks = {
            font: [$picks.font[] | select(. as $f | $l.fonts | index($f))],
            mono: [$picks.mono[] | select(. as $f | $l.monos | index($f))],
            icons: [$picks.icons[] | select(. as $f | $l.icons | map(.id) | index($f))],
            cursor: [$picks.cursor[] | select(. as $f | $l.cursors | index($f))],
            gtk: [$picks.gtk[] | select(. as $f | $l.gtk | index($f))],
            kvantum: [$picks.kvantum[] | select(. as $f | $l.kvantum | index($f))]
          }'
}

# ── apply ────────────────────────────────────────────────────────────────────
gv() { printf "'%s'" "${1//\'/\\\'}"; }   # a GVariant string

# home-manager used to own these as store links; replace with a real file
writable() { [ -L "$1" ] && rm -f "$1"; mkdir -p "$(dirname "$1")"; }

xml() { local s=${1//&/&amp;}; s=${s//</&lt;}; printf '%s' "${s//>/&gt;}"; }

qtct() {
    local v=$1 file="$CFG/qt${1}ct/qt${1}ct.conf" icons=$2 font=$3 fsize=$4 mono=$5 tail
    [ "$v" = 5 ] && tail="-1,5,50,0,0,0,0,0" || tail="-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    writable "$file"
    {
        printf '[Appearance]\nicon_theme=%s\nstyle=kvantum\n' "$icons"
        if [ -n "$font" ] || [ -n "$mono" ]; then
            printf '\n[Fonts]\n'
            [ -n "$mono" ] && printf 'fixed="%s,%s,%s"\n' "$mono" "$fsize" "$tail"
            [ -n "$font" ] && printf 'general="%s,%s,%s"\n' "$font" "$fsize" "$tail"
        fi
    } >"$file.tmp" && mv -f "$file.tmp" "$file"
}

cmd_apply() {
    local quiet=${1:-} s gtk kvantum icons cursor csize font fsize mono msize
    s=$(cmd_state)
    gtk=$(jq -r '.effective.gtk' <<<"$s")
    kvantum=$(jq -r '.effective.kvantum' <<<"$s")
    icons=$(jq -r '.effective.icons' <<<"$s")
    cursor=$(jq -r '.effective.cursor' <<<"$s")
    csize=$(jq -r '.effective.cursor_size' <<<"$s")
    font=$(jq -r '.effective.font' <<<"$s")
    fsize=$(jq -r '.effective.font_size' <<<"$s")
    mono=$(jq -r '.effective.mono' <<<"$s")
    msize=$(jq -r '.effective.mono_size' <<<"$s")
    [[ $csize =~ ^[0-9]+$ ]] || csize=${DEF[cursor_size]}
    [[ $fsize =~ ^[0-9]+$ ]] || fsize=${DEF[font_size]}
    [[ $msize =~ ^[0-9]+$ ]] || msize=

    # GTK, live through the settings portal
    if command -v dconf >/dev/null 2>&1; then
        dconf write "$DCONF/gtk-theme" "$(gv "$gtk")"
        dconf write "$DCONF/icon-theme" "$(gv "$icons")"
        dconf write "$DCONF/cursor-theme" "$(gv "$cursor")"
        dconf write "$DCONF/cursor-size" "$csize"
        if [ -n "$font" ]; then dconf write "$DCONF/font-name" "$(gv "$font $fsize")"; else dconf reset "$DCONF/font-name"; fi
        if [ -n "$mono" ]; then dconf write "$DCONF/monospace-font-name" "$(gv "$mono $fsize")"; else dconf reset "$DCONF/monospace-font-name"; fi
    fi

    # GTK's settings.ini: what apps read without the settings portal (XWayland,
    # anything up before it), and the only place GTK 3 takes its light/dark
    # preference from. GTK 4 gets no theme name (libadwaita warns about it).
    local dark=1 v ini
    [ "$(scheme)" = light ] && dark=0
    for v in 3 4; do
        ini="$CFG/gtk-$v.0/settings.ini"
        writable "$ini"
        {
            printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$dark"
            [ "$v" = 3 ] && printf 'gtk-theme-name=%s\n' "$gtk"
            printf 'gtk-icon-theme-name=%s\ngtk-cursor-theme-name=%s\ngtk-cursor-theme-size=%s\n' "$icons" "$cursor" "$csize"
            [ -n "$font" ] && printf 'gtk-font-name=%s %s\n' "$font" "$fsize"
            true
        } >"$ini.tmp" && mv -f "$ini.tmp" "$ini"
    done

    # Qt (qtct + Kvantum): read when an app starts
    qtct 5 "$icons" "$font" "$fsize" "$mono"
    qtct 6 "$icons" "$font" "$fsize" "$mono"
    local kv="$CFG/Kvantum/kvantum.kvconfig"
    writable "$kv"
    printf '[General]\ntheme=%s\n' "$kvantum" >"$kv.tmp" && mv -f "$kv.tmp" "$kv"

    # fontconfig: what "sans-serif"/"monospace" mean for everything else.
    # Loaded from 50-user.conf, before NixOS's defaults; <prefer> inserts right
    # before the generic name, so these stay ahead of them.
    local fc="$CFG/fontconfig/conf.d/70-dots-appearance.conf"
    if [ -n "$font" ] || [ -n "$mono" ]; then
        writable "$fc"
        {
            printf '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">\n<!-- written by dots-appearance -->\n<fontconfig>\n'
            [ -n "$font" ] && printf '  <alias binding="strong"><family>sans-serif</family><prefer><family>%s</family></prefer></alias>\n' "$(xml "$font")"
            [ -n "$mono" ] && printf '  <alias binding="strong"><family>monospace</family><prefer><family>%s</family></prefer></alias>\n' "$(xml "$mono")"
            printf '</fontconfig>\n'
        } >"$fc.tmp" && mv -f "$fc.tmp" "$fc"
    else
        rm -f "$fc"
    fi

    # ghostty (config-file = ?~/.local/state/dots/appearance/ghostty), live on SIGUSR2.
    # Signal only on a change: a ghostty still starting up (autostart) has no
    # USR2 handler yet and the signal kills it.
    mkdir -p "$STATE"
    {
        [ -n "$mono" ] && printf 'font-family = "%s"\n' "$mono"
        [ -n "$msize" ] && printf 'font-size = %s\n' "$msize"
        true
    } >"$STATE/ghostty.tmp"
    if cmp -s "$STATE/ghostty.tmp" "$STATE/ghostty"; then
        rm -f "$STATE/ghostty.tmp"
    else
        mv -f "$STATE/ghostty.tmp" "$STATE/ghostty"
        reload_ghostty
    fi

    # the cursor: live in Hyprland, and inherited by what it starts next
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl setcursor "$cursor" "$csize" >/dev/null 2>&1 || true
    fi

    [ -n "$quiet" ] || printf '%s\n' "$s" | jq -c '.effective'
}

cmd_set() {
    local k=$1 v=${2:-} c
    valid_key "$k"
    case $k in
    *_size) [ -z "$v" ] || [[ $v =~ ^[0-9]{1,3}$ ]] || die "$k must be a number" ;;
    *) [[ $v != *$'\n'* && $v != *'"'* ]] || die "invalid value" ;;
    esac
    mkdir -p "$STATE"
    c=$(choice)
    if [ -n "$v" ]; then
        c=$(jq -c --arg k "$k" --arg v "$v" '.[$k] = $v' <<<"$c")
    else
        c=$(jq -c --arg k "$k" 'del(.[$k])' <<<"$c")
    fi
    printf '%s\n' "$c" >"$CHOICE.tmp" && mv -f "$CHOICE.tmp" "$CHOICE"
    cmd_apply --quiet
    cmd_state
}

case ${1:-} in
state) cmd_state ;;
lists) cmd_lists ;;
set) shift; cmd_set "$@" ;;
reset) rm -f "$CHOICE"; cmd_apply --quiet; cmd_state ;;
apply) cmd_apply "${2:-}" ;;
*) die "usage: dots-appearance state|lists|set KEY [VALUE]|reset|apply [--quiet]" ;;
esac
