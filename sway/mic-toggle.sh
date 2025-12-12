#!/usr/bin/env bash
# Toggle default source (mic) mute and send a notification.

# Toggle mute
pactl set-source-mute @DEFAULT_SOURCE@ toggle

# Read new state (yes/no)
state=$(pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print $2}')

# Notify
if [ "$state" = "yes" ]; then
  notify-send "Microphone" "Muted"
else
  notify-send "Microphone" "Unmuted"
fi
