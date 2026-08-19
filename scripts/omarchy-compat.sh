CMD="$(basename "$0")"
TERM_CMD="${DOTS_TERMINAL:-ghostty}"

launch_float() {
    hyprctl dispatch exec "[float; size 1000 600; center] $TERM_CMD -e $*" >/dev/null 2>&1 || true
}

case "$CMD" in
    omarchy-theme-set)
        exec themectl set "$1"
        ;;
    omarchy-theme-bg-set)
        exec themectl bg set "$1"
        ;;

    omarchy-swayosd-client | omarchy-swayosd-brightness)
        if command -v swayosd-client >/dev/null 2>&1; then
            exec swayosd-client "$@"
        fi
        exit 0
        ;;

    omarchy-audio-input-mute)
        exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;

    omarchy-brightness-display)
        if command -v brightnessctl >/dev/null 2>&1; then
            brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'
        else
            echo 100
        fi
        exit 0
        ;;

    omarchy-toggle-notification-silencing)
        if command -v dunstctl >/dev/null 2>&1; then
            dunstctl set-paused toggle
            dunstctl is-paused
        fi
        exit 0
        ;;

    omarchy-toggle-idle)
        if pgrep hypridle >/dev/null 2>&1; then
            pkill hypridle
            echo "off"
        else
            hyprctl dispatch exec hypridle >/dev/null 2>&1 || true
            echo "on"
        fi
        exit 0
        ;;

    omarchy-capture-screenrecording)
        if command -v wf-recorder >/dev/null 2>&1; then
            if pgrep wf-recorder >/dev/null 2>&1; then
                pkill -INT wf-recorder
            else
                hyprctl dispatch exec \
                    "wf-recorder -f $HOME/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4" \
                    >/dev/null 2>&1 || true
            fi
        fi
        exit 0
        ;;
    omarchy-screenrecord-filename)
        printf '%s/Videos/recording-%s.mp4\n' "$HOME" "$(date +%Y%m%d-%H%M%S)"
        exit 0
        ;;

    omarchy-launch-floating-terminal-with-presentation)
        launch_float "$@"
        exit 0
        ;;
    omarchy-launch-or-focus-tui)
        launch_float "$@"
        exit 0
        ;;
    omarchy-launch-wifi)
        launch_float impala
        exit 0
        ;;
    omarchy-launch-bluetooth)
        launch_float bluetui
        exit 0
        ;;
    omarchy-launch-audio)
        launch_float wiremix
        exit 0
        ;;

    omarchy-tz-select)
        launch_float "sh -c 'timedatectl list-timezones | fzf | xargs -r sudo timedatectl set-timezone'"
        exit 0
        ;;

    omarchy-hw-display)
        launch_float "sh -c 'fastfetch; echo; read -r _'"
        exit 0
        ;;

    omarchy-update)
        launch_float "sh -c 'cd ~/dots && nh os switch; echo; echo done - press enter; read -r _'"
        exit 0
        ;;
    omarchy-update-available)
        # flake.lock older than a week counts as one pending update
        lock="$HOME/dots/flake.lock"
        if [ -f "$lock" ]; then
            age=$(( ( $(date +%s) - $(stat -c %Y "$lock") ) / 86400 ))
            [ "$age" -gt 7 ] && echo 1
        fi
        exit 0
        ;;

    omarchy-weather | omarchy-weather-status)
        if command -v curl >/dev/null 2>&1; then
            curl -fs --max-time 3 "https://wttr.in?format=%l:+%c+%t+%w" || true
        fi
        exit 0
        ;;

    omarchy-voxtype-config)
        launch_float "sh -c 'echo voxtype not installed; read -r _'"
        exit 0
        ;;
    omarchy-voxtype-model)
        echo "none"
        exit 0
        ;;

    omarchy-shell)
        case "${1:-}" in
            lock) exec hyprlock ;;
            restart) exec systemctl --user restart quickshell ;;
            *) exit 0 ;;
        esac
        ;;

    omarchy-launch-editor)
        launch_float nvim
        exit 0
        ;;

    *)
        exit 0
        ;;
esac
