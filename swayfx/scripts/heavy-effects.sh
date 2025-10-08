#!/usr/bin/env bash
# Apply heavy cinematic profile (soft blur + cinematic animations)
set -e

BLUR_FILE="$HOME/.config/swayfx/effects/blur-presets.conf"

sed -i \
  -e 's/^blur_radius .*/blur_radius 12/' \
  -e 's/^blur_passes .*/blur_passes 4/' \
  "$BLUR_FILE"

"$HOME/.config/swayfx/scripts/pick-anim.sh" cinematic

swaymsg reload >/dev/null
command -v notify-send >/dev/null 2>&1 && notify-send "SwayFX" "Heavy cinematic profile applied"