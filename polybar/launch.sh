#!/usr/bin/env bash

## Simplified Polybar Launch Script with Pywal Integration
## Single script to handle launching and reloading
##
## SETUP:
## 1. Install: polybar, pywal, zscroll, playerctl
## 2. Run: wal -i /path/to/wallpaper
## 3. Launch: ~/.config/polybar/launch.sh
## 4. Reload colors: ~/.config/polybar/launch.sh reload
##
## FILES INCLUDED:
## - config.ini (main config)
## - colors.ini (pywal colors)  
## - modules.ini (all modules with occult symbols)
## - launch.sh (this script)
## - get_spotify_status.sh (spotify with symbols)
## - scroll_spotify_status.sh (scrolling text)

# Function to show usage
show_usage() {
    echo "Usage: $0 [reload|start]"
    echo "  start  - Start polybar normally"
    echo "  reload - Reload polybar with new pywal colors"
    echo "  (no args) - Default start"
}

# Function to load pywal colors
load_pywal_colors() {
    if command -v wal &> /dev/null && [ -f ~/.cache/wal/colors.Xresources ]; then
        xrdb -merge ~/.cache/wal/colors.Xresources
        echo "✨ Loaded pywal colors to Xresources"
    else
        echo "⚠️  Pywal colors not found - using defaults"
    fi
}

# Function to launch polybar
launch_polybar() {
    # Terminate already running bar instances
    killall -q polybar
    
    # Wait until the processes have been shut down
    while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
    
    # Auto-detect monitor
    if type "xrandr" &> /dev/null; then
        export MONITOR=$(xrandr --query | grep " connected" | grep -o '^[^ ]*' | head -1)
        echo "🖥️  Using monitor: $MONITOR"
    fi
    
    # Remove previous log
    rm -f /tmp/polybar.log
    
    # Launch polybar
    echo "🚀 Launching polybar with occult theme and pywal colors..."
    echo "---" | tee -a /tmp/polybar.log
    polybar -c ~/.config/polybar/config.ini main >>/tmp/polybar.log 2>&1 &
    
    echo "✅ Polybar launched successfully!"
}

# Main logic
case "${1:-start}" in
    "reload")
        echo "🔄 Reloading polybar with new pywal colors..."
        load_pywal_colors
        launch_polybar
        ;;
    "start"|"")
        load_pywal_colors
        launch_polybar
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
