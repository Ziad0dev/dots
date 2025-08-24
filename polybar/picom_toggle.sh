#!/bin/bash

# Picom Toggle Script for Polybar
# Shows current picom status and toggles on click

get_picom_status() {
    if pgrep -x "picom" > /dev/null; then
        echo "ON"
    else
        echo "OFF"
    fi
}

toggle_picom() {
    if pgrep -x "picom" > /dev/null; then
        # Picom is running, kill it
        pkill picom
        notify-send "Picom" "Compositor disabled" -i "video-display"
    else
        # Picom is not running, start it
        picom -b
        notify-send "Picom" "Compositor enabled" -i "video-display"
    fi
}

case "$1" in
    --toggle)
        toggle_picom
        ;;
    *)
        # Default: show status
        status=$(get_picom_status)
        if [ "$status" = "ON" ]; then
            echo "◉"
        else
            echo "○"
        fi
        ;;
esac 