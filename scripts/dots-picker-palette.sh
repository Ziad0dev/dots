name="$(themectl current 2>/dev/null || true)"
[ -n "$name" ] || exit 0

pal=""
for r in "$HOME/dots/config/themes" "${XDG_CONFIG_HOME:-$HOME/.config}/dots/themes"; do
    for f in "$r/$name/theme.sh" "$r/$name/colors.sh"; do
        if [ -f "$f" ]; then
            pal="$f"
            break 2
        fi
    done
done
[ -n "$pal" ] || exit 0

sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*"?(#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?)"?[[:space:]]*$/\2 = "\3"/p' "$pal"
