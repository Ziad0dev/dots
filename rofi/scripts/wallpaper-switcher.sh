#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers/"

# Generate rofi entries with image icons
get_wallpapers_with_icons() {
    cd "$WALLPAPER_DIR" || exit 1
    for wallpaper in *.jpg *.jpeg *.png *.webp *.gif; do
        if [ -f "$wallpaper" ]; then
            # Format: filename\0icon\x1fpath_to_image\n
            echo -en "$wallpaper\0icon\x1f$WALLPAPER_DIR/$wallpaper\n"
        fi
    done
}

# Show rofi menu with image previews
SELECTION=$(get_wallpapers_with_icons | rofi -dmenu -i -p "🩸 Select Wallpaper" -show-icons)

if [ -n "$SELECTION" ]; then
    WALLPAPER="$WALLPAPER_DIR/$SELECTION"
    
    # Random transitions array
    TRANSITIONS=("simple" "fade" "wipe" "wave" "grow" "center" "outer" "any")
    TRANSITION=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}
    
    # Kill and restart awww daemon
    pkill awww-daemon
    sleep 1
    awww-daemon &
    sleep 2
    
    # Generate pywal colors
    wal -i "$WALLPAPER" -n -s -t -e --backend colorz
    
    # Apply wallpaper with RANDOM transition
    awww img "$WALLPAPER" \
        --transition-type "$TRANSITION" \
        --transition-angle $(shuf -i 0-360 -n 1) \
        --transition-duration 2 \
        --transition-fps 60 \
        --transition-bezier 0.65,0,0.35,1
    
    # Reload wal
    wal -i "$WALLPAPER" 
    
    # Reload compositor
    if pgrep -x Hyprland > /dev/null; then
        hyprctl reload
    fi
    
    if pgrep -x sway > /dev/null; then
        swaymsg reload
    fi
    
    notify-send "🩸 Wallpaper Applied" "$SELECTION\nTransition: $TRANSITION" -t 3000
    
    echo "✅ Wallpaper changed to: $SELECTION"
fi
