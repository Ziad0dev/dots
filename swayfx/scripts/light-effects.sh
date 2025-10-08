#!/usr/bin/env bash
# Apply lightweight performance profile (lower blur, minimal animations)
set -e

BLUR_FILE="$HOME/.config/swayfx/effects/blur-presets.conf"

# Replace active blur lines
sed -i \
  -e 's/^blur_radius .*/blur_radius 7/' \
  -e 's/^blur_passes .*/blur_passes 2/' \
  "$BLUR_FILE"

# Switch to minimal pack
"$HOME/.config/swayfx/scripts/pick-anim.sh" minimal

swaymsg reload >/dev/null
command -v notify-send >/dev/null 2>&1 && notify-send "SwayFX" "Light performance profile applied"