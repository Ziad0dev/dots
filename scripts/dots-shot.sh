# Screenshots: dots-shot region|screen|window
#
# Saves to the pictures dir (what the shell's screenshot browser reads),
# copies to the clipboard, and posts a notification with the shot as its
# icon: click opens it, "Edit" opens satty on the same file.
set -euo pipefail

mode=${1:-region}

dir=${DOTS_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$(xdg-user-dir PICTURES 2>/dev/null || true)}}
case "$dir" in "" | "$HOME") dir="$HOME/Pictures" ;; esac
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
region)
    # freeze the screen while selecting, like flameshot did
    hyprpicker -r -z >/dev/null 2>&1 &
    freeze=$!
    sleep 0.1
    geom=$(slurp -d) || geom=""
    kill "$freeze" 2>/dev/null || true
    [ -n "$geom" ] || exit 0
    grim -g "$geom" "$file"
    ;;
screen)
    output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    grim -o "$output" "$file"
    ;;
window)
    geom=$(hyprctl activewindow -j | jq -r 'if .at then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')
    [ -n "$geom" ] || exit 0
    grim -g "$geom" "$file"
    ;;
*)
    echo "usage: dots-shot region|screen|window" >&2
    exit 2
    ;;
esac

wl-copy --type image/png <"$file"

# notify-send -A blocks until the notification is acted on or closed
(
    action=$(notify-send -a Screenshot -i "$file" \
        -A default=Open -A edit=Edit \
        "Screenshot saved" "${file/#$HOME/\~} · copied to clipboard") || exit 0
    case "$action" in
    default) xdg-open "$file" ;;
    edit) satty --filename "$file" --output-filename "$file" --copy-command wl-copy ;;
    esac
) >/dev/null 2>&1 &
