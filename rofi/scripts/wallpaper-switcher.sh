#!/bin/bash

# ═══════════════════════════════════════════════════════
# ROFI WALLPAPER SWITCHER - Random SWWW Transitions
# Works with your existing rofi config
# ═══════════════════════════════════════════════════════

WALLPAPER_DIR="$HOME/Pictures/wallpapers/"

# Get list of wallpapers
get_wallpapers() {
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -printf "%f\n" | sort
}

# Show rofi menu (uses your existing config)
SELECTION=$(get_wallpapers | rofi -dmenu -i -p "🩸 Select Wallpaper")

if [ -n "$SELECTION" ]; then
    WALLPAPER="$WALLPAPER_DIR/$SELECTION"
    
    # Random transitions array
    TRANSITIONS=("simple" "fade" "wipe" "wave" "grow" "center" "outer" "any")
    TRANSITION=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}
    
    # Kill and restart swww daemon
    pkill swww-daemon
    sleep 1
    swww-daemon &
    sleep 2
    
    # Generate pywal colors
    wal -i "$WALLPAPER" -n -s -t -e --backend colorz
    
    # Apply wallpaper with RANDOM transition
    swww img "$WALLPAPER" \
        --transition-type "$TRANSITION" \
        --transition-angle $(shuf -i 0-360 -n 1) \
        --transition-duration 2 \
        --transition-fps 60 \
        --transition-bezier 0.65,0,0.35,1
    
    # Reload wal
    wal -i $WALLPAPER 
    
    # Reload compositor
    if pgrep -x Hyprland > /dev/null; then
        hyprctl reload
    fi
    
    if pgrep -x sway > /dev/null; then
        swaymsg reload
    fi
    
    notify-send "🩸 Wallpaper Applied" "$SELECTION\nTransition: $TRANSITION" -t 3000
fi
