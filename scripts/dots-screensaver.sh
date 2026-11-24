# dots-screensaver: Omarchy's screensaver. A black fullscreen terminal on
# every monitor plays terminal-text effects (tte) over a big clock. Any key,
# or the pointer moving, ends it. hypridle starts it before the lock
# (config/hypr/hypridle.conf) and stops it when you come back.
#
#   dots-screensaver start | stop | run   (run: inside each terminal)

class=dev.dots.screensaver

running_pids() {
    hyprctl clients -j 2>/dev/null | jq -r --arg c "$class" '.[] | select(.class == $c) | .pid'
}

cmd_start() {
    local mon out
    [ -z "$(running_pids)" ] || exit 0
    # not over a game. Under the lock it's harmless (the lock stays on top,
    # and hypridle stops it on resume), so the lock isn't probed: taking its
    # lock file even briefly could make a real lock fail to start
    [ "$(head -n1 "${XDG_STATE_HOME:-$HOME/.local/state}/dots/hypr/game" 2>/dev/null)" != on ] || exit 0
    while read -r mon; do
        # names go into a Lua string below: plain ones only
        [[ $mon =~ ^[A-Za-z0-9._-]+$ ]] || continue
        # per-launch rules: fullscreen on this monitor
        out=$(hyprctl eval "hl.exec_cmd('ghostty --class=$class --background=000000 --background-opacity=1 --font-size=13 -e dots-screensaver run', { monitor = '$mon', fullscreen = true, no_anim = true, opaque = true, no_blur = true })" 2>&1) || true
        if [ "$out" != ok ]; then
            printf 'dots-screensaver: %s: %s\n' "$mon" "$out" >&2
        fi
    # monitors showing a fullscreen window (a paused video, a document) are
    # skipped: a workspace has one fullscreen window, and the screensaver's
    # would knock that one out of fullscreen for good
    done < <(jq -rn --argjson m "$(hyprctl monitors -j)" --argjson w "$(hyprctl workspaces -j)" '
        ($w | map(select(.hasfullscreen) | .id)) as $full
        | $m[] | select((.disabled | not) and ((.activeWorkspace.id as $a | $full | index($a)) | not)) | .name')
}

cmd_stop() {
    local pid
    while read -r pid; do
        [[ $pid =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null || true
    done < <(running_pids)
}

banner() {
    figlet -f big -w 200 "$(date +%H:%M)"
    printf '\n%s\n' "$(date '+%A %-d %B')"
}

cmd_run() {
    # effect is global: the EXIT trap runs after this function has returned
    local before next=0
    effect=""
    printf '\e[?25l'
    trap 'printf "\e[?25h"; [ -z "$effect" ] || kill "$effect" 2>/dev/null' EXIT
    before=$(hyprctl cursorpos 2>/dev/null || true)
    # an effect plays in the background while a key or the pointer moving is
    # watched for, so it ends at once, not when the effect is over (started
    # from the menu, hypridle's on-resume doesn't cover it)
    while :; do
        # the next effect 3 s after the last one ends (input still watched)
        if [ -n "$effect" ] && ! kill -0 "$effect" 2>/dev/null; then
            effect="" next=$((SECONDS + 3))
        fi
        if [ -z "$effect" ] && ((SECONDS >= next)); then
            clear
            banner | tte --frame-rate 60 --canvas-width 0 --canvas-height 0 \
                --anchor-canvas c --anchor-text c --random-effect 2>/dev/null &
            effect=$!
        fi
        if read -rsn1 -t 0.5; then break; fi
        [ "$(hyprctl cursorpos 2>/dev/null || true)" = "$before" ] || break
    done
    cmd_stop
}

case "${1:-}" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    run) cmd_run ;;
    *)
        echo "usage: dots-screensaver start|stop|run" >&2
        exit 2
        ;;
esac
