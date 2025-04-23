#!/usr/bin/env bash

## Add this to your wm startup file.

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Remove previous log
rm -f /tmp/polybar.log

# Launch the blood red occult-themed polybar
echo "---" | tee -a /tmp/polybar.log
polybar -c ~/.config/polybar/config.ini main >>/tmp/polybar.log 2>&1 &

echo "Polybar launched with blood red occult theme..."
