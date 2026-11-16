UNIT="dots-mono"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dots"
PREV="$STATE/mono-previous-sink"

notify() { notify-send -a dots-mono -h string:x-canonical-private-synchronous:dots-mono "$@" || true; }

sink_name() {
    wpctl inspect @DEFAULT_AUDIO_SINK@ | sed -n '/node\.name = /{s/.*node\.name = "\(.*\)"/\1/p;q}'
}

node_id() {
    pw-dump | jq -r --arg n "$1" 'first(.[] | select(.info.props["node.name"]? == $n) | .id) // empty'
}

active() { systemctl --user is-active --quiet "$UNIT.service"; }

enable_mono() {
    local real id
    active && { echo on; return; }
    real=$(sink_name)
    [ -n "$real" ] || { notify -u critical "Mono" "no default sink"; exit 1; }
    mkdir -p "$STATE"
    printf '%s\n' "$real" >"$PREV"
    systemd-run --user --unit="$UNIT" --quiet --collect -- \
        pw-loopback \
        --capture-props="media.class=Audio/Sink node.name=dots_mono node.description=Mono audio.position=[MONO]" \
        --playback-props="node.name=dots_mono.out target.object=$real audio.position=[MONO]"
    id=""
    for _ in $(seq 1 25); do
        id=$(node_id dots_mono)
        [ -n "$id" ] && break
        sleep 0.2
    done
    [ -n "$id" ] || { systemctl --user stop "$UNIT.service" || true; notify -u critical "Mono" "loopback did not appear"; exit 1; }
    wpctl set-default "$id"
    notify "Mono" "on (via $real)"
    echo on
}

disable_mono() {
    local real id
    active || { echo off; return; }
    systemctl --user stop "$UNIT.service" || true
    if [ -f "$PREV" ]; then
        real=$(head -n1 "$PREV")
        id=$(node_id "$real")
        [ -n "$id" ] && wpctl set-default "$id"
        rm -f "$PREV"
    fi
    notify "Mono" "off"
    echo off
}

case "${1:-toggle}" in
    on) enable_mono ;;
    off) disable_mono ;;
    toggle) if active; then disable_mono; else enable_mono; fi ;;
    status) if active; then echo on; else echo off; fi ;;
    *) printf 'usage: dots-mono [on|off|toggle|status]\n' >&2; exit 1 ;;
esac
