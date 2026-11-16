#!/bin/sh
out="${XDG_RUNTIME_DIR:-/tmp}/dots-i3status.toml"
theme="${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme/i3status-rs.toml"
cat "$HOME/.config/sway/status.toml" >"$out.tmp"
[ -f "$theme" ] && cat "$theme" >>"$out.tmp"
mv -f "$out.tmp" "$out"
[ "${1:-}" = build ] && exit 0
exec i3status-rs "$out"
