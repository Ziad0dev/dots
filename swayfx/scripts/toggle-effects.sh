#!/usr/bin/env bash
# Toggle through animation packs by uncommenting the next pack marker.
set -e

FILE="$HOME/.config/swayfx/effects/animation-packs.conf"
packs=(minimal pop elastic slide cinematic)

current=$(grep -m1 '^set \\$anim_pack' "$FILE" | awk '{print $3}')
[[ -z $current ]] && current="minimal"

# Find current index
idx=-1
for i in "${!packs[@]}"; do
  [[ "${packs[$i]}" == "$current" ]] && idx=$i && break
done
(( idx < 0 )) && idx=0
next=${packs[$(((idx+1)%${#packs[@]}))]}

tmp=$(mktemp)
while IFS= read -r line; do
  if [[ "$line" =~ ^set\\ \\$anim_pack ]]; then
    echo "#$line" >> "$tmp"
  elif [[ "$line" =~ ^#set\\ \\$anim_pack\\ $next$ ]]; then
    echo "${line:1}" >> "$tmp"
  else
    echo "$line" >> "$tmp"
  fi
done < "$FILE"

mv "$tmp" "$FILE"
swaymsg reload >/dev/null
command -v notify-send >/dev/null 2>&1 && notify-send "SwayFX" "Animation pack: $next"