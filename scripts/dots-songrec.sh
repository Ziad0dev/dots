STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dots/songrec"
HISTORY="$STATE/history.tsv"
SECONDS_TO_RECORD="${DOTS_SONGREC_SECONDS:-10}"

notify() { notify-send -a dots-songrec -h string:x-canonical-private-synchronous:dots-songrec "$@" || true; }

sink_name() {
    wpctl inspect @DEFAULT_AUDIO_SINK@ | sed -n '/node\.name = /{s/.*node\.name = "\(.*\)"/\1/p;q}'
}

source_name() {
    wpctl inspect @DEFAULT_AUDIO_SOURCE@ | sed -n '/node\.name = /{s/.*node\.name = "\(.*\)"/\1/p;q}'
}

WAV=""
trap 'rm -f "$WAV"' EXIT

listen() {
    local mode="$1" wav json title artist url target
    wav=$(mktemp --suffix=.wav "${XDG_RUNTIME_DIR:-/tmp}/dots-songrec.XXXXXX")
    WAV="$wav"

    if [ "$mode" = mic ]; then
        target=$(source_name)
        notify -t "$((SECONDS_TO_RECORD * 1000))" "Listening" "microphone, ${SECONDS_TO_RECORD}s"
        timeout -s INT "$SECONDS_TO_RECORD" pw-record --target "$target" "$wav" || true
    else
        target=$(sink_name)
        notify -t "$((SECONDS_TO_RECORD * 1000))" "Listening" "desktop audio, ${SECONDS_TO_RECORD}s"
        timeout -s INT "$SECONDS_TO_RECORD" pw-record --target "$target" -P '{ stream.capture.sink = true }' "$wav" || true
    fi

    [ -s "$wav" ] || { notify -u critical "Song recognition" "nothing was recorded"; exit 1; }

    if ! json=$(timeout 30 songrec audio-file-to-recognized-song "$wav" 2>/dev/null); then
        notify -u critical "Song recognition" "songrec failed (network?)"
        exit 1
    fi

    title=$(jq -r '.track.title // empty' <<<"$json")
    artist=$(jq -r '.track.subtitle // empty' <<<"$json")
    url=$(jq -r '.track.url // empty' <<<"$json")

    if [ -z "$title" ]; then
        notify "Song recognition" "no match"
        exit 2
    fi

    mkdir -p "$STATE"
    printf '%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$artist" "$title" "$url" >>"$HISTORY"
    printf '%s - %s' "$artist" "$title" | wl-copy
    printf '%s - %s\n%s\n' "$artist" "$title" "$url"
    notify "$title" "$artist  (copied)"
}

case "${1:-}" in
    "" | desktop) listen desktop ;;
    mic) listen mic ;;
    history)
        [ -f "$HISTORY" ] || exit 0
        awk -F'\t' '{ printf "%s  %s - %s\n", substr($1, 1, 16), $2, $3 }' "$HISTORY" | tail -n "${2:-20}"
        ;;
    *) printf 'usage: dots-songrec [desktop|mic|history [n]]\n' >&2; exit 1 ;;
esac
