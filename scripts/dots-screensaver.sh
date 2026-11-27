# dots-screensaver: a themed clock over every monitor, drawn by the bar
# (config/quickshell/rise/Screensaver.qml). hypridle starts it at 5 min and
# stops it when you come back (config/hypr/hypridle.conf); any key, a click or
# the pointer moving also ends it.
#
# It is a bar overlay, not terminal windows: Hyprland resets every idle timer
# when a window opens or takes focus, so a window-based screensaver woke
# hypridle straight away and the lock and blackout never came.
#
# At the lock it is paused (black, nothing animating) rather than stopped:
# closing it moves keyboard focus to a window, which resets the timers again.
#
#   dots-screensaver start | stop | pause | status

ipc() { qs -c rise ipc call screensaver "$@"; }

case "${1:-}" in
    start)
        # not over a game
        [ "$(head -n1 "${XDG_STATE_HOME:-$HOME/.local/state}/dots/hypr/game" 2>/dev/null)" != on ] || exit 0
        ipc start >/dev/null
        ;;
    stop) ipc stop >/dev/null 2>&1 || true ;;
    pause) ipc pause >/dev/null 2>&1 || true ;;
    status) ipc active ;;
    *)
        echo "usage: dots-screensaver start|stop|pause|status" >&2
        exit 2
        ;;
esac
