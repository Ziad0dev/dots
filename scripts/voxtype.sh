STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dots/voxtype"
WAV="$STATE/capture.wav"
PIDF="$STATE/rec.pid"
PHASE="$STATE/phase"
MODELF="$STATE/model"
MODELDIR="${VOXTYPE_MODEL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/voxtype/models}"

mkdir -p "$STATE"

whisper_bin() {
    local b
    for b in whisper-cli whisper-cpp main; do
        if command -v "$b" >/dev/null 2>&1; then printf '%s' "$b"; return 0; fi
    done
    return 1
}

current_model() {
    if [ -s "$MODELF" ] && [ -f "$(cat "$MODELF")" ]; then
        cat "$MODELF"
        return 0
    fi
    find "$MODELDIR" -maxdepth 1 -name 'ggml-*.bin' 2>/dev/null | sort | head -1
}

model_label() {
    local m
    m=$(current_model) || true
    if [ -n "$m" ]; then basename "$m" .bin | sed 's/^ggml-//'; else printf 'none'; fi
}

set_phase() { printf '%s' "$1" >"$PHASE"; }

rec_alive() {
    local pid
    pid=$(cat "$PIDF" 2>/dev/null) || return 1
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null
}

# pw-record finalises the WAV header on exit; wait for that (up to 3 s)
# instead of guessing, or whisper reads a truncated file
stop_pid() {
    local i=0
    kill "$1" 2>/dev/null || return 0
    while kill -0 "$1" 2>/dev/null && [ "$i" -lt 60 ]; do
        sleep 0.05
        i=$((i + 1))
    done
}

get_phase() {
    local p="idle"
    [ -s "$PHASE" ] && p=$(cat "$PHASE")
    if [ "$p" = "recording" ] && ! rec_alive; then
        rm -f "$PIDF"
        set_phase idle
        p="idle"
    fi
    printf '%s' "$p"
}

emit_text() {
    local text="$1"
    [ -z "$text" ] && return 0
    if command -v wtype >/dev/null 2>&1; then
        wtype -- "$text" || true
    else
        printf '%s' "$text" | wl-copy || true
        notify-send -a voxtype "Copied to clipboard" "wtype not installed" 2>/dev/null || true
    fi
    return 0
}

start_rec() {
    if rec_alive; then stop_pid "$(cat "$PIDF")"; fi
    rm -f "$WAV"
    pw-record --rate 16000 --channels 1 --format s16 "$WAV" &
    echo $! >"$PIDF"
    set_phase recording
}

stop_rec() {
    local pid model bin text
    pid=$(cat "$PIDF" 2>/dev/null) || pid=""
    if [ -n "$pid" ]; then stop_pid "$pid"; fi
    rm -f "$PIDF"
    set_phase transcribing

    model=$(current_model) || model=""
    bin=$(whisper_bin) || bin=""
    if [ -z "$bin" ]; then
        set_phase idle
        notify-send -a voxtype "whisper not found" 2>/dev/null || true
        return 0
    fi
    if [ -z "$model" ]; then
        set_phase idle
        notify-send -a voxtype "No model" "Put ggml-*.bin in $MODELDIR" 2>/dev/null || true
        return 0
    fi

    rm -f "$STATE/out.txt"
    "$bin" -m "$model" -f "$WAV" -nt -np -otxt -of "$STATE/out" >/dev/null 2>&1 || true
    text=$(cat "$STATE/out.txt" 2>/dev/null) || text=""
    text=$(printf '%s' "$text" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')
    set_phase idle
    emit_text "$text"
}

phase=$(get_phase)

case "${1:-status}" in
    toggle)
        case "$phase" in
            recording)    stop_rec ;;
            transcribing) : ;;
            *)            start_rec ;;
        esac
        ;;
    start)
        [ "$phase" = idle ] && start_rec
        ;;
    stop)
        [ "$phase" = recording ] && stop_rec
        ;;
    model)
        model_label
        echo
        ;;
    models)
        find "$MODELDIR" -maxdepth 1 -name 'ggml-*.bin' 2>/dev/null | sort
        ;;
    set-model)
        printf '%s' "${2:-}" >"$MODELF"
        ;;
    status)
        case "$phase" in
            recording)    tip="Recording — press again to transcribe" ;;
            transcribing) tip="Transcribing…" ;;
            *)            tip="Idle ($(model_label))" ;;
        esac
        if printf '%s' "$*" | grep -q json; then
            printf '{"class":"%s","alt":"%s","tooltip":"%s"}\n' "$phase" "$phase" "$tip"
        else
            printf '%s\n' "$phase"
        fi
        ;;
    *)
        exit 1
        ;;
esac
exit 0
