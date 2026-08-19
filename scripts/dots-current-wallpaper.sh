state="${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme"

for c in "$state/wallpaper" "$state/current-wallpaper" "$state/background"; do
    if [ -e "$c" ]; then
        readlink -f "$c"
        exit 0
    fi
done

if command -v awww >/dev/null 2>&1; then
    awww query 2>/dev/null |
        sed -nE 's/.*currently displaying: image: (.*)$/\1/p' |
        head -n1 || true
fi
