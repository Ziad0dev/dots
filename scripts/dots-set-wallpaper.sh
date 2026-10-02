img="$1"
[ -n "$img" ] || exit 1
[ -f "$img" ] || exit 1

awww img "$img" --transition-type random --transition-fps 60 --transition-duration 1

state="${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme"
mkdir -p "$state"
ln -sfn "$img" "$state/wallpaper"

# Login greeter: a blurred, dimmed copy it loads at the next login (see
# modules/sddm.nix, dots.sddm.live). Rendered in the background; the swap
# above shouldn't wait on the blur.
greeter=/var/lib/dots-theme
if [ -w "$greeter" ]; then
    (
        magick "$img" -resize 2560x -blur 0x18 -modulate 45 -quality 90 "$greeter/wallpaper.jpg.tmp" &&
            mv -f "$greeter/wallpaper.jpg.tmp" "$greeter/wallpaper.jpg" &&
            if [ -f "$greeter/sddm.json" ]; then
                jq '.wallpaper = "file:///var/lib/dots-theme/wallpaper.jpg"' "$greeter/sddm.json" >"$greeter/sddm.json.tmp" &&
                    mv -f "$greeter/sddm.json.tmp" "$greeter/sddm.json"
            fi
    ) >/dev/null 2>&1 &
fi
