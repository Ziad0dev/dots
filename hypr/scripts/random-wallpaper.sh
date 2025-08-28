#!/bin/bash
# Random wallpaper script for Hyprland with pywal integration
# Adapted from your i3 setup

WALLPAPER_DIR="$HOME/Pictures"

# Find a random wallpaper
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)

if [ -n "$WALLPAPER" ]; then
    # Set wallpaper with swww
    swww img "$WALLPAPER" --transition-type wipe --transition-fps 60
    
    # Generate color scheme with pywal
    wal -i "$WALLPAPER" -n
    
    # Update Hyprland colors
    ~/.config/hypr/scripts/update-colors.sh
    
    # Reload waybar to apply new colors
    killall waybar
    waybar &
    
    # Notify user
    notify-send "Wallpaper Changed" "Applied: $(basename "$WALLPAPER")"
else
    notify-send "Error" "No wallpapers found in $WALLPAPER_DIR"
fi
