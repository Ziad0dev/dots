img="$1"
[ -n "$img" ] || exit 1
[ -f "$img" ] || exit 1

awww img "$img" --transition-type random --transition-fps 60 --transition-duration 1

state="${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme"
mkdir -p "$state"
ln -sfn "$img" "$state/wallpaper"
