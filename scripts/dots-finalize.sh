# One-shot, idempotent finisher for the Quickshell Rise bar.
#   - every shell-out goes straight through hyprctl (no dots-* shim needed)
#   - logo sized from the asset's real pixel dimensions
#   - right-click on system widgets opens a matching TUI
# Safe to re-run.

RISE="${1:-$HOME/dots/config/quickshell/rise}"
[ -d "$RISE" ] || { echo "dots-finalize: no such dir: $RISE" >&2; exit 1; }

TERM_CMD="${DOTS_TERMINAL:-ghostty}"
# NB: hyprctl dispatch goes through Lua on a Lua config, and [float; size ...]
# is a syntax error there. Spawn the terminal directly and let a windowrule
# float it by class instead.
# ghostty wants --class=VALUE (equals, not space) and validates it as a GTK
# application id, so it must be dotted. Match it with class:com.dots.float
float() { printf '%s --class=com.dots.float -e %s' "$TERM_CMD" "$2"; }

widgets() {
    for d in "$RISE/modules" "$RISE/variants/V2/modules"; do
        [ -d "$d" ] && printf '%s\n' "$d"
    done
}

# ── 1. logo: derive aspect + height from the actual file ────────────────
logo_fix() {
    local png w h asp
    png="$RISE/variants/V2/assets/nixos-logo.png"
    [ -f "$png" ] || png="$RISE/assets/nixos-logo.png"
    [ -f "$png" ] || { echo "  logo: asset missing, skipped"; return 0; }

    if command -v identify >/dev/null 2>&1; then
        w=$(identify -format '%w' "$png" 2>/dev/null)
        h=$(identify -format '%h' "$png" 2>/dev/null)
    fi
    [ -n "${w:-}" ] && [ -n "${h:-}" ] || { w=647; h=192; }
    asp="($w / $h)"

    local d
    for d in $(widgets); do
        [ -f "$d/LauncherWidget.qml" ] || continue
        sed -i -E "s|hyprlandLogo \? \(948 / 154\) : \([0-9]+ / [0-9]+\)|hyprlandLogo ? (948 / 154) : $asp|" \
            "$d/LauncherWidget.qml"
        # the fall-through height was 20px, which renders the wordmark tiny
        sed -i -E "s|(archTextLogo \? 17 : )[0-9]+$|\\126|" "$d/LauncherWidget.qml"
        sed -i -E "s|(archTextLogo \? 8 : )[0-9]+$|\\114|" "$d/LauncherWidget.qml"
    done
    echo "  logo: ${w}x${h}, height 26"
}

# ── 2. rewire every shell-out to a direct hyprctl call ──────────────────
# widget file : id : command run on click
rewire() {
    local file="$1" pid="$2" cmd="$3" d
    for d in $(widgets); do
        [ -f "$d/$file" ] || continue
        if grep -q "id: $pid" "$d/$file"; then
            sed -i -E "s|Process \{ id: $pid; command: \[[^]]*\] \}|Process { id: $pid; command: [\"bash\", \"-c\", \"$cmd\"] }|" "$d/$file"
        fi
    done
}

logo_fix

# file manager on the old packages button
rewire ArchUpdaterWidget.qml filesProc "$(float '1100 700' yazi)"

echo "  buttons: file manager -> yazi"

# ── 3. right-click TUIs on the system widgets ───────────────────────────
add_rmb() {
    local file="$1" pid="$2" cmd="$3" d
    for d in $(widgets); do
        [ -f "$d/$file" ] || continue
        grep -q "id: $pid" "$d/$file" && continue
        python3 - "$d/$file" "$pid" "$cmd" <<'PYEOF'
import sys, pathlib, re
path, pid, cmd = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path); s = p.read_text()
if f"id: {pid}" in s:
    sys.exit(0)
m = re.search(r'^(\s*)MouseArea \{', s, re.M)
if not m:
    sys.exit(0)
ind = m.group(1)
proc = f'{ind}Process {{ id: {pid}; command: ["bash", "-c", "{cmd}"] }}\n\n'
s = s[:m.start()] + proc + s[m.start():]

m2 = re.search(r'^(\s*)MouseArea \{\n', s, re.M)
blk = s[m2.end():]
if 'acceptedButtons' not in blk[:400]:
    s = s[:m2.end()] + f'{ind}    acceptedButtons: Qt.LeftButton | Qt.RightButton\n' + s[m2.end():]

# merge into the EXISTING onClicked; a second one would just shadow it
m3 = re.search(r'^(\s*)onClicked:\s*(\{|function\s*\([^)]*\)\s*\{|\([^)]*\)\s*=>\s*\{)', s, re.M)
if m3:
    ind3 = m3.group(1)
    guard = f'\n{ind3}    if (e.button === Qt.RightButton) {{ {pid}.running = false; {pid}.running = true; return }}'
    head = s[m3.start():m3.end()]
    if 'function' not in head and '=>' not in head:
        head = head.replace('onClicked:', 'onClicked: function (e)', 1)
    s = s[:m3.start()] + head + guard + s[m3.end():]
p.write_text(s)
PYEOF
    done
}

add_rmb CpuWidget.qml        cpuTui  "$(float '1200 750' btop)"
add_rmb MemoryWidget.qml     memTui  "$(float '1200 750' btop)"
add_rmb GpuWidget.qml        gpuTui  "$(float '1200 750' nvtop)"
add_rmb StorageWidget.qml    stoTui  "$(float '1100 700' 'yazi /')"
add_rmb NetworkWidget.qml    netTui  "$(float '900 600' impala)"
add_rmb BluetoothWidget.qml  btTui   "$(float '900 600' bluetui)"

# ── audio: add a pactl fallback and surface the real error ─────────────
for d in $(widgets); do
    [ -f "$d/AudioWidget.qml" ] || continue
    grep -q 'pactl set-sink-mute' "$d/AudioWidget.qml" || sed -i \
        -e 's|"pamixer -t"|"pamixer -t \|\| pactl set-sink-mute @DEFAULT_SINK@ toggle"|' \
        -e 's|"pamixer " + (up ? "--increase " : "--decrease ") + amount|"pamixer " + (up ? "--increase " : "--decrease ") + amount + " \|\| pactl set-sink-volume @DEFAULT_SINK@ " + (up ? "+" : "-") + amount + "%"|' \
        "$d/AudioWidget.qml"
done
echo "  audio: pactl fallback added"

echo "  buttons: right-click TUIs on cpu/mem/gpu/storage/network/bluetooth"

# ── 4. verify nothing lost brace balance ───────────────────────────────
bad=0
while read -r q; do
    o=$(tr -cd '{' <"$q" | wc -c); c=$(tr -cd '}' <"$q" | wc -c)
    [ "$o" = "$c" ] || { echo "  BROKEN: $q ($o/$c)"; bad=1; }
done < <(find "$RISE" -name '*.qml')
[ "$bad" = 0 ] && echo "  qml: all balanced" || echo "  qml: FIX NEEDED"

echo "dots-finalize: done"
