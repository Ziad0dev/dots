#!/bin/bash
# Theme selector script for Hyprland
# Allows selection from predefined wallpapers

WALLPAPER_DIR="$HOME/Pictures"

# Get list of wallpapers
WALLPAPERS=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | sort)

# Display in rofi with preview
CHOSEN=$(echo "$WALLPAPERS" | sed "s|$WALLPAPER_DIR/||g" | rofi -dmenu -i -p "Select Wallpaper" -theme-str 'window {width: 50%;}')

if [ -n "$CHOSEN" ]; then
    WALLPAPER="$WALLPAPER_DIR/$CHOSEN"
    
    # Set wallpaper with swww
    swww img "$WALLPAPER" --transition-type fade --transition-fps 60
    
    # Generate color scheme with pywal
    wal -i "$WALLPAPER" -n
    
    # Update Hyprland colors
    ~/.config/hypr/scripts/update-colors.sh
    
    # Reload waybar to apply new colors
    killall waybar
    waybar &
    
    # Notify user
    notify-send "Theme Applied" "Selected: $CHOSEN"
fi
