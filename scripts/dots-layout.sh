# dots-layout: per-workspace layouts (Omarchy 4.5's workspace modes), applied
# by config/hypr/lib/workspace_modes.lua.
#
#   dots-layout current [WS]          print tiling|scrolling|floating
#   dots-layout next | back           cycle the focused workspace (SUPER + T)
#   dots-layout set MODE [WS]         MODE: tiling (dwindle), scrolling, floating
#   dots-layout default [MODE]        print or set the layout of workspaces
#                                     without one of their own
#
# Choices are `default=<mode>` and `<ws>=<mode>` lines in
# ~/.local/state/dots/workspace-layouts, which the bar watches.

state="${XDG_STATE_HOME:-$HOME/.local/state}/dots/workspace-layouts"

die() {
    printf 'dots-layout: %s\n' "$1" >&2
    exit 1
}

# what people call it -> Hyprland's name; anything else is refused
mode_of() {
    case "$1" in
        tiling | dwindle) printf dwindle ;;
        scrolling) printf scrolling ;;
        floating) printf floating ;;
        *) return 1 ;;
    esac
}

label() {
    case "$1" in
        dwindle) printf Tiling ;;
        scrolling) printf Scrolling ;;
        *) printf Floating ;;
    esac
}

valid_ws() {
    [[ $1 =~ ^[1-9][0-9]{0,8}$ ]]
}

saved() { # saved KEY -> its mode, or nothing
    [ -f "$state" ] || return 0
    sed -n "s/^$1=\\(dwindle\\|scrolling\\|floating\\)\$/\\1/p" "$state" | tail -n 1
}

# rewrite the state file with KEY set to MODE ("" removes it), atomically
put() {
    local key="$1" mode="$2" tmp
    mkdir -p "$(dirname "$state")"
    tmp=$(mktemp "$state.XXXXXX")
    if [ -f "$state" ]; then
        grep -v -- "^$key=" "$state" >"$tmp" || true
    fi
    if [ -n "$mode" ]; then
        printf '%s=%s\n' "$key" "$mode" >>"$tmp"
    fi
    mv -f -- "$tmp" "$state"
}

default_mode() {
    local m
    m=$(saved default)
    if [ -z "$m" ]; then
        # Hyprland's own layout, if it's one this tool knows (master isn't)
        m=$(mode_of "$(hyprctl getoption general.layout -j 2>/dev/null | jq -r '.str // empty')") || m=""
        [ "$m" != floating ] || m=""
    fi
    printf '%s' "${m:-dwindle}"
}

current() { # current [WS]
    local ws="${1:-}" m
    if [ -z "$ws" ]; then
        ws=$(hyprctl activeworkspace -j | jq -r '.id')
    fi
    if valid_ws "$ws"; then
        m=$(saved "$ws")
        [ -n "$m" ] || m=$(default_mode)
    fi
    printf '%s' "${m:-dwindle}"
}

notify() {
    local idf="${XDG_RUNTIME_DIR:-/tmp}/dots-layout-notification" last id
    last=$(cat "$idf" 2>/dev/null || echo 0)
    [[ $last =~ ^[0-9]+$ ]] || last=0
    # one notification, replaced on each press, not a stack of them
    if id=$(notify-send -p -r "$last" -a "Layout" -t 1500 -- "$1" 2>/dev/null) && [[ $id =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$id" >"$idf"
    fi
}

apply() { # apply WS MODE: values are validated, so the Lua string is safe
    hyprctl eval "dots_workspace_modes.set(\"$1\", \"$2\")" >/dev/null 2>&1
}

set_ws() { # set_ws WS MODE
    local ws="$1" mode="$2"
    valid_ws "$ws" || die "not a workspace: $ws"
    apply "$ws" "$mode" || {
        notify "Layouts need a Hyprland reload first"
        exit 1
    }
    # on the default, the workspace follows it again (a later default reaches it)
    if [ "$mode" = "$(default_mode)" ]; then
        put "$ws" ""
        hyprctl eval "dots_workspace_modes.clear(\"$ws\")" >/dev/null 2>&1 || true
    else
        put "$ws" "$mode"
    fi
    notify "$(label "$mode") on workspace $ws"
}

cmd="${1:-current}"
case "$cmd" in
    current)
        current "${2:-}"
        echo
        ;;
    next | back)
        ws=$(hyprctl activeworkspace -j | jq -r '.id')
        # named and special workspaces keep their own state
        valid_ws "$ws" || exit 1
        cur=$(current "$ws")
        if [ "$cmd" = next ]; then
            case "$cur" in dwindle) new=scrolling ;; scrolling) new=floating ;; *) new=dwindle ;; esac
        else
            case "$cur" in dwindle) new=floating ;; floating) new=scrolling ;; *) new=dwindle ;; esac
        fi
        set_ws "$ws" "$new"
        ;;
    set)
        mode=$(mode_of "${2:-}") || die "usage: dots-layout set tiling|scrolling|floating [WS]"
        ws="${3:-$(hyprctl activeworkspace -j | jq -r '.id')}"
        set_ws "$ws" "$mode"
        ;;
    default)
        if [ -z "${2:-}" ]; then
            default_mode
            echo
            exit 0
        fi
        mode=$(mode_of "$2") || die "usage: dots-layout default [tiling|scrolling|floating]"
        # a workspace with windows keeps the layout it has, so a new default
        # never rearranges work in progress
        while read -r ws; do
            valid_ws "$ws" || continue
            [ -n "$(saved "$ws")" ] && continue
            cur=$(current "$ws")
            if [ "$cur" != "$mode" ]; then
                put "$ws" "$cur"
                # Hyprland too, before the default moves: otherwise the
                # new default would rearrange it right away
                apply "$ws" "$cur" || true
            fi
        done < <(hyprctl workspaces -j | jq -r '.[] | select(.id >= 1 and .windows > 0) | .id')
        put default "$mode"
        hyprctl eval "dots_workspace_modes.set(nil, \"$mode\")" >/dev/null 2>&1 || true
        notify "New workspaces: $(label "$mode")"
        ;;
    *) die "usage: dots-layout {current [WS]|next|back|set MODE [WS]|default [MODE]}" ;;
esac
