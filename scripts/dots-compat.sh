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
            dunstctl is-paused
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
                    -- gpu-screen-recorder ${DOTS_GSR_ARGS:--w DP-1 -f 60 -c mp4 -k hevc -q very_high -a default_output} \
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
        lock="$HOME/dots/flake.lock"
        if [ -f "$lock" ]; then
            age=$(( ( $(date +%s) - $(stat -c %Y "$lock") ) / 86400 ))
            [ "$age" -gt 7 ] && echo 1 || echo 0
        else
            echo 0
        fi
        exit 0
        ;;

    dots-weather | dots-weather-status)
        if command -v curl >/dev/null 2>&1; then
            curl -fs --max-time 3 "https://wttr.in?format=%l:+%c+%t+%w" || true
        fi
        exit 0
        ;;

    dots-voxtype-config)
        launch_float "sh -c 'echo voxtype not installed; read -r _'"
        exit 0
        ;;
    dots-voxtype-model)
        echo "none"
        exit 0
        ;;

    dots-shell)
        case "${1:-}" in
            lock) exec hyprlock ;;
            restart) exec systemctl --user restart quickshell ;;
            *) exit 0 ;;
        esac
        ;;

    dots-launch-editor)
        launch_float nvim
        exit 0
        ;;

    dots-files)
        launch_float yazi
        exit 0
        ;;

    *)
        exit 0
        ;;
esac
