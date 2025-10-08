#!/usr/bin/env bash
# Simple power menu (wofi or rofi)
choice=$(printf "Lock\nLogout\nReboot\nShutdown" | rofi -dmenu -p "Power")
case "$choice" in
  Lock) swaylock ;;
  Logout) swaymsg exit ;;
  Reboot) systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
esac
