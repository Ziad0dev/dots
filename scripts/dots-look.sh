HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dots/hypr"

die() {
    printf 'dots-look: %s\n' "$1" >&2
    exit 1
}

get() { [ -f "$STATE/$1" ] && head -n1 "$STATE/$1" || true; }

put() {
    mkdir -p "$STATE"
    if [ -n "$2" ]; then
        printf '%s\n' "$2" >"$STATE/$1"
    else
        rm -f "$STATE/$1"
    fi
}

apply() {
    local out
    if out=$(hyprctl eval "$1" 2>&1) && ! grep -qiE 'unknown|error|invalid' <<<"$out"; then
        return 0
    fi
    hyprctl reload >/dev/null
}

names() { find "$1" -maxdepth 1 -name "*.$2" -printf '%f\n' | sed "s/\.$2\$//" | sort; }

pick() {
    local prompt="$1" cur="$2"
    shift 2
    printf '%s\n' "$@" | sed "s/^$cur\$/$cur  (current)/" |
        fuzzel --dmenu --prompt "$prompt " | sed 's/  (current)$//'
}

valid() { [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]] || die "invalid name '$1'"; }

notify() { notify-send -a dots-look -t 1500 -h string:x-canonical-private-synchronous:dots-look "$1" "$2" || true; }

cmd_anim() {
    local name="${1:-}" list cur
    mapfile -t list < <(names "$HYPR/animations" lua)
    case "$name" in
        list) printf '%s\n' "${list[@]}"; return ;;
        "") cur=$(get animation); echo "${cur:-snap}"; return ;;
        pick)
            cur=$(get animation)
            name=$(pick animation "${cur:-snap}" "${list[@]}")
            [ -n "$name" ] || exit 0
            ;;
    esac
    valid "$name"
    [ -f "$HYPR/animations/$name.lua" ] || die "no animation preset '$name'"
    if [ "$name" = snap ]; then put animation ""; else put animation "$name"; fi
    hyprctl reload >/dev/null
    notify "Animations" "$name"
}

cmd_shader() {
    local name="${1:-}" list cur
    mapfile -t list < <(names "$HYPR/shaders" glsl)
    case "$name" in
        list) printf '%s\n' off "${list[@]}"; return ;;
        "") cur=$(get shader); echo "${cur:-off}"; return ;;
        pick)
            cur=$(get shader)
            name=$(pick shader "${cur:-off}" off "${list[@]}")
            [ -n "$name" ] || exit 0
            ;;
    esac
    if [ "$name" = off ]; then
        put shader ""
        apply 'hl.config({ decoration = { screen_shader = "" } })'
    else
        valid "$name"
        [ -f "$HYPR/shaders/$name.glsl" ] || die "no shader '$name'"
        put shader "$name"
        apply "hl.config({ decoration = { screen_shader = \"$HYPR/shaders/$name.glsl\" } })"
    fi
    notify "Shader" "$name"
}

cmd_blur() {
    local want="${1:-toggle}"
    if [ "$want" = toggle ]; then
        if [ "$(get blur)" = off ]; then want=on; else want=off; fi
    fi
    case "$want" in
        on) put blur ""; apply 'hl.config({ decoration = { blur = { enabled = true } } })' ;;
        off) put blur off; apply 'hl.config({ decoration = { blur = { enabled = false } } })' ;;
        status)
            if [ "$(get blur)" = off ]; then echo off; else echo on; fi
            return
            ;;
        *) die "usage: dots-look blur [on|off|toggle|status]" ;;
    esac
    notify "Blur" "$want"
}

case "${1:-}" in
    anim) shift; cmd_anim "$@" ;;
    shader) shift; cmd_shader "$@" ;;
    blur) shift; cmd_blur "$@" ;;
    *) die "usage: dots-look {anim [pick|list|<name>] | shader [pick|list|off|<name>] | blur [on|off|toggle|status]}" ;;
esac
