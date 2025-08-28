#!/bin/bash
# Setup scratchpad applications for Hyprland
# Adapted from your i3 scratchpad setup

# Wait for Hyprland to be ready
sleep 2

# Create translate scratchpad
hyprctl dispatch exec "[workspace special:translate] kitty --title translate -e zsh -c 'trans -I'"

# Create calendar scratchpad  
hyprctl dispatch exec "[workspace special:calendar] kitty --title calendar -e zsh -c 'ikhal'"

echo "Scratchpad applications started"
