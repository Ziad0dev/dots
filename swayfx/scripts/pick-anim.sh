#!/usr/bin/env bash
# pick-anim.sh <packname|next|prev>
set -e

FILE="$HOME/.config/swayfx/effects/animation-packs.conf"
packs=(minimal pop elastic slide cinematic)

usage() {
  echo "Usage: pick-anim.sh <pack|next|prev>" >&2
  exit 1
}

[[ $# -ne 1 ]] && usage
target="$1"

current=$(grep -m1 '^set \\$anim_pack' "$FILE" | awk '{print $3}')
[[ -z $current ]] && current="minimal"

if [[ "$target" == "next" || "$target" == "prev" ]]; then
  idx=-1
  for i in "${!packs[@]}"; do [[ "${packs[$i]}" == "$current" ]] && idx=$i && break; done
  (( idx < 0 )) && idx=0
  if [[ "$target" == "next" ]]; then
    target=${packs[$(((idx+1)%${#packs[@]}))]}
  else
    target=${packs[$(((idx-1+${#packs[@]})%${#packs[@]}) )]}
  fi
fi

found=0
for p in "${packs[@]}"; do [[ "$p" == "$target" ]] && found=1 && break; done
(( !found )) && echo "Unknown pack: $target" >&2 && exit 1

tmp=$(mktemp)
while IFS= read -r line; do
  if [[ "$line" =~ ^set\\ \\$anim_pack ]]; then
    echo "#$line" >> "$tmp"
  elif [[ "$line" =~ ^#set\\ \\$anim_pack\\ $target$ ]]; then
    echo "${line:1}" >> "$tmp"
  else
    echo "$line" >> "$tmp"
  fi
done < "$FILE"

mv "$tmp" "$FILE"
swaymsg reload >/dev/null
command -v notify-send >/dev/null 2>&1 && notify-send "SwayFX" "Animation pack: $target"