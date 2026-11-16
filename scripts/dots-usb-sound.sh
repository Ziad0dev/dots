OFF="${XDG_STATE_HOME:-$HOME/.local/state}/dots/usb-sound-off"

play() {
    [ -e "$OFF" ] && return 0
    pw-play "$DOTS_SOUNDS/$1.wav" >/dev/null 2>&1 &
}

watch_usb() {
    local last="" now
    udevadm monitor --udev --subsystem-match=usb/usb_device | while read -r _ _ action _; do
        case "$action" in
            add | remove) ;;
            *) continue ;;
        esac
        now="$action $(date +%s)"
        [ "$now" = "$last" ] && continue
        last="$now"
        if [ "$action" = add ]; then play device-added; else play device-removed; fi
    done
}

case "${1:-}" in
    watch) watch_usb ;;
    on) rm -f "$OFF"; echo on ;;
    off) mkdir -p "${OFF%/*}"; touch "$OFF"; echo off ;;
    toggle)
        if [ -e "$OFF" ]; then rm -f "$OFF"; echo on; else mkdir -p "${OFF%/*}"; touch "$OFF"; echo off; fi
        ;;
    status) if [ -e "$OFF" ]; then echo off; else echo on; fi ;;
    *) printf 'usage: dots-usb-sound {watch|on|off|toggle|status}\n' >&2; exit 1 ;;
esac
