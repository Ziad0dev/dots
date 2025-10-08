#!/usr/bin/env bash
# Random wallpaper + pywal + Waybar reload
WALL=$(find ~/Pictures -type f \( -iname "*.jpg" -o -iname "*.png" \) | shuf -n1)
[ -n "$WALL" ] && wal -i "$WALL"
# Set background (swaybg: we re-spawn using pkill & new)
pkill swaybg
swaybg -m fill -i "$WALL" &
# Optionally generate a sway colors file from pywal
if [ -f ~/.cache/wal/colors ]; then
  {
    echo "# Generated from pywal"
    sed -n '1,16p' ~/.cache/wal/colors | nl
  } > ~/.config/sway/colors
fi
# Reload sway & waybar
swaymsg reload
pkill -USR2 waybar 2>/dev/null
notify-send "Theme" "Applied new random theme"
