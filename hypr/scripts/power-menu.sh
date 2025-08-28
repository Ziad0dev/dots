#!/bin/bash
# Power menu script for Hyprland
# Adapted from your i3 setup

# Options
shutdown="⏻ Shutdown"
reboot="🔄 Reboot"
sleep="😴 Sleep"
hibernate="🛌 Hibernate"
logout="🚪 Logout"
lock="🔒 Lock"

# Rofi command
rofi_cmd() {
    rofi -dmenu \
        -i \
        -p "Power Menu" \
        -theme-str 'window {width: 300px; height: 250px;}' \
        -theme-str 'listview {lines: 6;}'
}

# Get user choice
chosen=$(echo -e "$lock\n$logout\n$sleep\n$hibernate\n$reboot\n$shutdown" | rofi_cmd)

# Execute based on choice
case $chosen in
    $shutdown)
        systemctl poweroff
        ;;
    $reboot)
        systemctl reboot
        ;;
    $sleep)
        systemctl suspend
        ;;
    $hibernate)
        systemctl hibernate
        ;;
    $logout)
        hyprctl dispatch exit
        ;;
    $lock)
        swaylock -f -c 000000
        ;;
esac
