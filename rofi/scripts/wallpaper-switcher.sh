#!/usr/bin/env bash
# ⸸ wallpaper switcher — rofi + awww ⸸

WALLPAPER_DIR="$HOME/Pictures/wallpapers"

get_wallpapers_with_icons() {
    cd "$WALLPAPER_DIR" || exit 1
    for wallpaper in *.jpg *.jpeg *.png *.webp *.gif; do
        [ -f "$wallpaper" ] && echo -en "$wallpaper\0icon\x1f$WALLPAPER_DIR/$wallpaper\n"
    done
}

SELECTION=$(get_wallpapers_with_icons | rofi -dmenu -i -p "🩸 Select Wallpaper" -show-icons)
[ -z "$SELECTION" ] && exit 0

WALLPAPER="$WALLPAPER_DIR/$SELECTION"

# Daemon is started by hyprland exec-once; only start if somehow missing.
pgrep -x awww-daemon >/dev/null || { awww-daemon & sleep 1; }

TRANSITIONS=("simple" "fade" "wipe" "wave" "grow" "center" "outer" "any")
TRANSITION=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}

awww img "$WALLPAPER" \
    --transition-type "$TRANSITION" \
    --transition-angle "$(shuf -i 0-360 -n 1)" \
    --transition-duration 2 \
    --transition-fps 144 \
    --transition-bezier 0.65,0,0.35,1

# Pywal theming — only if installed (it isn't in configuration.nix right now)
if command -v wal >/dev/null; then
    wal -i "$WALLPAPER" -n -s -t -e
    pgrep -x Hyprland >/dev/null && hyprctl reload
fi

notify-send "🩸 Wallpaper Applied" "$SELECTION\nTransition: $TRANSITION" -t 3000
