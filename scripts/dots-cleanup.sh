DOTS="${1:-$HOME/dots}"
cd "$DOTS" || { echo "dots-cleanup: no such dir: $DOTS" >&2; exit 1; }

say() { printf '  %s\n' "$1"; }

echo "== dead nix modules =="
if [ -f home/quickshell.nix ] && ! grep -q 'quickshell\.nix' home/home.nix; then
    rm -f home/quickshell.nix
    say "removed home/quickshell.nix: not imported, yet it declared a second"
    say "programs.quickshell and rebuilt four helpers quickshell-rise.nix owns"
fi
if [ -f scripts/omarchy-compat.sh ]; then
    rm -f scripts/omarchy-compat.sh
    say "removed scripts/omarchy-compat.sh, superseded by dots-compat.sh"
fi

echo "== duplicate package =="
if grep -qE '^[[:space:]]+quickshell$' home/home.nix; then
    sed -i '/^[[:space:]]\+quickshell$/d' home/home.nix
    say "dropped bare quickshell from home.packages; programs.quickshell.package has it"
fi

echo "== hyprland binds =="
HL=config/hypr/hyprland.lua
if [ -f "$HL" ]; then
    sed -i '/exec_cmd("qs -c theme-picker")/d' "$HL"
    sed -i '/^hl\.dsp\.exec_cmd("qs -c picker ipc call picker wallpaper")$/d' "$HL"
    sed -i 's|qs -c picker ipc call picker |qs -c rise ipc call picker |g' "$HL"
    sed -i 's|env PATH=.*wallpaper-switcher\.sh|qs -c rise ipc call picker wallpaper|' "$HL"
    sed -i 's|^local colors = (_ok and _rendered) or require("colors")$|local colors = require("colors")|' "$HL"
    sed -i 's|^dofile(os\.getenv("HOME")|pcall(dofile, os.getenv("HOME")|' "$HL"
    sed -i '/^[[:space:]]*hl\.exec_cmd("waybar")$/d' "$HL"
    say "removed the duplicate SUPER+CTRL+SHIFT+SPACE bind and the two bare"
    say "exec_cmd calls that ran at parse time instead of on a key"
    say "repointed picker IPC at the rise config and dropped waybar autostart"
fi

echo "== orphaned quickshell config =="
if [ -d config/quickshell/picker ] && ! grep -rq 'c picker' config/hypr/hyprland.lua home/*.nix 2>/dev/null; then
    say "config/quickshell/picker is unreferenced now that activeConfig = rise"
    say "keep as fallback, or: git rm -r config/quickshell/picker"
fi

echo
echo "dots-cleanup: done - review with 'git diff', then 'git add -A'"
