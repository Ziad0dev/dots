# dots-mic-mode [toggle|clean|discord|status]
#   clean    EasyEffects removes noise (set Discord noise suppression to None)
#   discord  EasyEffects skips denoise (leave Discord's Krisp on)
# Never run both denoisers at once: stacked, they eat your consonants.
notify() { notify-send -a dots-mic "$@" || true; }

state_dir="${XDG_RUNTIME_DIR:-/tmp}/dots"
state="$state_dir/mic-mode"
mkdir -p "$state_dir"

# EasyEffects loads mic-discord at login and $XDG_RUNTIME_DIR is wiped on logout,
# so a missing state file always means "discord".
current=discord
if [ -f "$state" ]; then
    current=$(cat "$state")
    # EasyEffects restarted (crash, service restart) after we last switched:
    # it came back on the login default, so the file is stale
    if ee=$(pgrep -xo easyeffects) && etimes=$(ps -o etimes= -p "$ee"); then
        started=$(($(date +%s) - etimes))
        if [ "$started" -gt "$(stat -c %Y "$state")" ]; then
            current=discord
        fi
    fi
fi

case "${1:-toggle}" in
    toggle)
        if [ "$current" = discord ]; then target=clean; else target=discord; fi
        ;;
    clean | discord)
        target=$1
        ;;
    status)
        echo "$current"
        exit 0
        ;;
    *)
        echo "usage: dots-mic-mode [toggle|clean|discord|status]" >&2
        exit 2
        ;;
esac

if ! easyeffects --load-preset "mic-$target" >/dev/null 2>&1; then
    notify -u critical "Mic" "could not load preset mic-$target (is EasyEffects running?)"
    exit 1
fi

echo "$target" >"$state"
case "$target" in
    clean) notify "Mic: clean" "EasyEffects denoise ON. Set Discord noise suppression to None." ;;
    discord) notify "Mic: Discord" "EasyEffects denoise OFF. Leave Discord's Krisp on." ;;
esac
