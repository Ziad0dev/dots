notify() { notify-send -a dots-lens "$@" || true; }

geometry=$(slurp 2>/dev/null) || exit 0
[ -n "$geometry" ] || exit 0

if ! grim -g "$geometry" - | wl-copy --type image/png; then
    notify -u critical "Lens" "capture failed"
    exit 1
fi

notify "Lens" "Region copied. Paste it with Ctrl+V."
setsid -f xdg-open "https://lens.google.com/" >/dev/null 2>&1
