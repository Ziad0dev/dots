#!/usr/bin/env bash
set -uo pipefail

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    sleep 10
    exit 0
fi

sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
fifo=$(mktemp -u)
mkfifo "$fifo"
socat -U - UNIX-CONNECT:"$sock" > "$fifo" 2>/dev/null &
spid=$!
trap 'kill $spid 2>/dev/null; rm -f "$fifo"' EXIT
grep -m1 --line-buffered "activelayout>>" < "$fifo"
