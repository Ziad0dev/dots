CMD="$(basename "$0")"
TERM_CMD="${DOTS_TERMINAL:-ghostty}"

launch_float() {
    systemd-run --user --scope --quiet --collect \
        -- "$TERM_CMD" --class=com.dots.float -e sh -c "$*" &
}

case "$CMD" in
    dots-theme-set)
        exec themectl set "$1"
        ;;
    dots-theme-bg-set)
        exec themectl bg set "$1"
        ;;

    dots-swayosd-client | dots-swayosd-brightness)
        if command -v swayosd-client >/dev/null 2>&1; then
            exec swayosd-client "$@"
        fi
        exit 0
        ;;

    dots-audio-input-mute)
        exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;

    dots-brightness-display)
        if command -v brightnessctl >/dev/null 2>&1; then
            brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'
        else
            echo 100
        fi
        exit 0
        ;;

    dots-toggle-notification-silencing)
        if command -v dunstctl >/dev/null 2>&1; then
            dunstctl set-paused toggle
            paused=$(dunstctl is-paused)
            mkdir -p "$HOME/.local/state/dots"
            printf '{"dnd":%s}\n' "$paused" >"$HOME/.local/state/dots/notifications.json"
            printf '%s\n' "$paused"
        fi
        exit 0
        ;;

    dots-toggle-idle)
        if systemctl --user is-active --quiet hypridle.service; then
            systemctl --user stop hypridle.service
            echo "off"
        else
            systemctl --user start hypridle.service
            echo "on"
        fi
        exit 0
        ;;

    dots-capture-screenrecording)
        case "${1:-}" in
            --save-replay)
                # gsr-replay.service is declared in modules/recording.nix and
                # exposes ExecReload = kill -USR1 $MAINPID
                if systemctl --user is-active --quiet gsr-replay.service; then
                    systemctl --user reload gsr-replay.service
                else
                    notify-send "Replay" "Replay buffer not running" 2>/dev/null || true
                fi
                ;;
            --stop)
                systemctl --user stop dots-gsr.service 2>/dev/null || true
                ;;
            *)
                out="$HOME/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4"
                mkdir -p "$HOME/Videos"
                # a transient UNIT, not a scope: lifetime independent of this
                # shim, so it survives us exiting. SIGINT lets gsr finalise the
                # mp4 instead of being SIGTERMed mid-write.
                # shellcheck disable=SC2086
                systemd-run --user --unit=dots-gsr --quiet --collect \
                    --property=KillSignal=SIGINT \
                    --property=TimeoutStopSec=15 \
                    -- gpu-screen-recorder ${DOTS_GSR_ARGS:--w DP-1 -f 60 -c mp4 -k hevc -q very_high -a default_output|easyeffects_source} \
                       -o "$out"
                ;;
        esac
        exit 0
        ;;
    dots-screenrecord-filename)
        printf '%s/Videos/recording-%s.mp4\n' "$HOME" "$(date +%Y%m%d-%H%M%S)"
        exit 0
        ;;

    dots-launch-floating-terminal-with-presentation)
        launch_float "$@"
        exit 0
        ;;
    dots-launch-or-focus-tui)
        launch_float "$@"
        exit 0
        ;;
    dots-launch-wifi)
        launch_float impala
        exit 0
        ;;
    dots-launch-bluetooth)
        launch_float bluetui
        exit 0
        ;;
    dots-launch-audio)
        launch_float wiremix
        exit 0
        ;;

    dots-tz-select)
        launch_float "sh -c 'timedatectl list-timezones | fzf | xargs -r sudo timedatectl set-timezone'"
        exit 0
        ;;

    dots-hw-display)
        for c in /sys/class/backlight/amdgpu_bl* /sys/class/backlight/intel_backlight \
                 /sys/class/backlight/acpi_video* /sys/class/backlight/*; do
            [ -e "$c" ] && { printf '%s\n' "${c##*/}"; break; }
        done
        exit 0
        ;;

    dots-update)
        launch_float "sh -c 'cd ~/dots && nh os switch; echo; echo done - press enter; read -r _'"
        exit 0
        ;;
    dots-update-available)
        # flake.lock older than a week counts as one pending update
        lock="$HOME/dots/flake.lock"
        if [ -f "$lock" ]; then
            age=$(( ( $(date +%s) - $(stat -c %Y "$lock") ) / 86400 ))
            [ "$age" -gt 7 ] && echo 1
        fi
        exit 0
        ;;

    dots-updates)
        # pending-update count, same signal dots-update-available reports
        cache="${XDG_CACHE_HOME:-$HOME/.cache}/dots-updates"
        if [ -f "$cache" ] && [ "$(( $(date +%s) - $(stat -c %Y "$cache") ))" -lt 3600 ]; then
            cat "$cache"
            exit 0
        fi
        locked=$(nix flake metadata "$HOME/dots" --json 2>/dev/null \
            | jq -r '.locks.nodes.chaotic.locked.rev // empty') || true
        remote=$(git ls-remote https://github.com/chaotic-cx/nyx HEAD 2>/dev/null | cut -f1) || true
        if [ -n "${locked:-}" ] && [ -n "${remote:-}" ] && [ "$locked" != "$remote" ]; then
            printf '1\n' >"$cache"
        else
            printf '0\n' >"$cache"
        fi
        cat "$cache"
        exit 0
        ;;

    dots-mounts)
        # names of declared mounts that are not currently healthy; empty = all ok
        bad=""
        for m in /data /mnt/media /mnt/backup /mnt/newvolume; do
            unit=$(systemd-escape -p --suffix=mount "$m" 2>/dev/null) || continue
            auto="${unit%.mount}.automount"
            if [ "$(systemctl show -p LoadState --value "$auto" 2>/dev/null)" = "loaded" ]; then
                watch="$auto"
            else
                watch="$unit"
            fi
            if systemctl is-failed --quiet "$unit" 2>/dev/null \
                || ! systemctl is-active --quiet "$watch" 2>/dev/null; then
                bad="$bad ${m##*/}"
            fi
        done
        printf '%s\n' "${bad# }"
        exit 0
        ;;

    dots-llm)
        llm_units="llama-cpp llama-sec llama-agent llama-gemma llama-coder llama-fim ollama"
        llm_active=""
        for u in $llm_units; do
            if systemctl is-active --quiet "$u.service" 2>/dev/null; then
                llm_active="$u"
                break
            fi
        done
        case "${1:-status}" in
            status)
                printf '%s\n' "${llm_active:-none}"
                ;;
            off)
                for u in $llm_units; do
                    systemctl stop "$u.service" >/dev/null 2>&1 || true
                done
                ;;
            next)
                target=""
                if [ -n "$llm_active" ]; then
                    seen=0
                    for u in $llm_units; do
                        if [ "$seen" = 1 ]; then
                            target="$u"
                            seen=2
                            break
                        fi
                        [ "$u" = "$llm_active" ] && seen=1
                    done
                fi
                [ -n "$target" ] || target="llama-cpp"
                if [ -n "$llm_active" ] && [ "$llm_active" != "$target" ]; then
                    systemctl stop "$llm_active.service" >/dev/null 2>&1 || true
                fi
                systemctl start "$target.service" >/dev/null 2>&1 || true
                ;;
        esac
        exit 0
        ;;

    dots-qbt)
        qbt="http://127.0.0.1:8081"
        info=$(curl -fs --max-time 2 "$qbt/api/v2/transfer/info" 2>/dev/null) || true
        if [ -z "${info:-}" ]; then
            printf 'off\n'
            exit 0
        fi
        dl=$(printf '%s' "$info" | jq -r '.dl_info_speed // 0') || dl=0
        up=$(printf '%s' "$info" | jq -r '.up_info_speed // 0') || up=0
        n=$(curl -fs --max-time 2 "$qbt/api/v2/torrents/info?filter=downloading" 2>/dev/null \
            | jq -r 'length' 2>/dev/null) || true
        printf '%s %s %s\n' "${n:-0}" "$dl" "$up"
        exit 0
        ;;

    dots-weather | dots-weather-status)
        if command -v curl >/dev/null 2>&1; then
            curl -fs --max-time 3 "https://wttr.in?format=%l:+%c+%t+%w" || true
        fi
        exit 0
        ;;

    dots-voxtype-config)
        launch_float "sh -c 'voxtype models | fzf --prompt=\"whisper model > \" | xargs -r voxtype set-model'"
        exit 0
        ;;
    dots-voxtype-model)
        exec voxtype model
        ;;

    dots-shell)
        case "${1:-}" in
            lock)    exec quickshell -c lock ;;
            restart) exec systemctl --user restart quickshell ;;
            notifications)
                case "${2:-}" in
                    ping) echo ok ;;
                    status)
                        command -v dunstctl >/dev/null 2>&1 || exit 1
                        printf '{"dnd":%s}\n' "$(dunstctl is-paused)"
                        ;;
                    *) exit 1 ;;
                esac
                exit 0
                ;;
            idle)
                case "${2:-}" in
                    status)
                        systemctl --user is-active --quiet hypridle.service && echo on || echo off
                        ;;
                    *) exit 1 ;;
                esac
                exit 0
                ;;
            *) exit 0 ;;
        esac
        ;;



    *)
        exit 127
        ;;
esac
