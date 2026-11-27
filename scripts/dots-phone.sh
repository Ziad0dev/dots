# dots-phone: the phone as part of the desktop (docs/desktop.md → Phone).
#
#   KDE Connect (Android and iPhone; pair once with `dots-phone pair`):
#     ring                  make the phone ring
#     send [FILE...]        send files (no arguments: pick them)
#     send-clipboard        send the clipboard's text
#     sms                   read and send text messages (Android)
#     pair                  open KDE Connect: pair devices, settings
#   scrcpy (Android, USB debugging on, or wireless debugging connected with adb):
#     mirror                show and control the phone's screen
#     webcam [back|front|stop]   phone camera as a webcam ("Phone camera"); again to stop
#   QR codes (any phone camera):
#     qr [TEXT]             show TEXT (or the clipboard) as a QR code
#     wifi-qr               the current Wi-Fi's name and password as a QR code
#   Quick Share (Android's "Share → Quick Share"):
#     quickshare            start RQuickShare on its fixed, firewall-opened port

notify() { notify-send -a Phone -i phone "$@" || true; }
die() {
    notify "$1" "${2:-}"
    printf 'dots-phone: %s %s\n' "$1" "${2:-}" >&2
    exit 1
}

# the paired, reachable KDE Connect device; asks which when there are several
kde_device() {
    local list n
    list=$(kdeconnect-cli --list-available --id-name-only 2>/dev/null || true)
    n=$(printf '%s' "$list" | grep -c . || true)
    if [ "$n" -eq 0 ]; then
        die "No phone connected" "Open KDE Connect on the phone (same network) and pair it: dots-phone pair"
    elif [ "$n" -eq 1 ]; then
        printf '%s\n' "${list%% *}"
    else
        local pick
        pick=$(printf '%s\n' "$list" | cut -d' ' -f2- | fuzzel --dmenu --prompt "Phone › " --lines "$n" 2>/dev/null) || exit 0
        [ -n "$pick" ] || exit 0
        printf '%s\n' "$list" | awk -v name="$pick" '{ id = $1; $1 = ""; sub(/^ /, ""); if ($0 == name) { print id; exit } }'
    fi
}

adb_ready() {
    adb get-state >/dev/null 2>&1 ||
        die "No Android phone over adb" "Plug it in with USB debugging on (Developer options), or pair Wireless debugging: adb pair, then adb connect"
}

show_qr() {
    local text="$1" dir
    [ -n "$text" ] || die "Nothing to encode" "Copy something first, or: dots-phone qr TEXT"
    dir=$(mktemp -d --tmpdir="${XDG_RUNTIME_DIR:-/tmp}" dots-qr.XXXXXX)
    # the window rule floats imv windows whose title names dots-qr.png
    qrencode --size 12 --margin 2 --output "$dir/dots-qr.png" -- "$text"
    imv "$dir/dots-qr.png" || true
    rm -rf -- "$dir"
}

# WIFI: QR format; \ ; , : " are escaped
wifi_escape() { printf '%s' "$1" | sed 's/[\\;,:"]/\\&/g'; }

cmd="${1:-}"
[ $# -eq 0 ] || shift
case "$cmd" in
    ring)
        id=$(kde_device)
        kdeconnect-cli --device "$id" --ring
        ;;
    send)
        id=$(kde_device)
        files=("$@")
        if [ ${#files[@]} -eq 0 ]; then
            picked=$(zenity --file-selection --multiple --separator=$'\n' --title "Send to phone" 2>/dev/null) || exit 0
            mapfile -t files <<<"$picked"
        fi
        for f in "${files[@]}"; do
            [ -e "$f" ] || die "No such file" "$f"
            kdeconnect-cli --device "$id" --share "$(realpath -- "$f")"
        done
        notify "Sent to phone" "${#files[@]} file(s)"
        ;;
    send-clipboard)
        text=$(wl-paste --no-newline --type text 2>/dev/null || true)
        [ -n "$text" ] || die "The clipboard has no text"
        id=$(kde_device)
        kdeconnect-cli --device "$id" --share-text "$text"
        notify "Clipboard sent to phone"
        ;;
    sms) exec kdeconnect-sms ;;
    pair) exec kdeconnect-app ;;
    mirror)
        adb_ready
        exec scrcpy --stay-awake --window-title "Phone"
        ;;
    webcam)
        unit=dots-phone-webcam
        if systemctl --user is-active --quiet "$unit" || [ "${1:-}" = stop ]; then
            systemctl --user stop "$unit" 2>/dev/null || true
            notify "Phone camera off"
            exit 0
        fi
        facing="${1:-back}"
        case "$facing" in back | front) ;; *) die "webcam: back, front or stop" ;; esac
        dev="${DOTS_PHONE_WEBCAM:-/dev/video42}"
        [ -e "$dev" ] || die "No $dev" "The v4l2loopback module loads at boot (modules/phone.nix): reboot after the switch"
        adb_ready
        # a transient unit, so it outlives the menu and `webcam` again stops it
        systemd-run --user --quiet --collect --unit="$unit" \
            scrcpy --video-source=camera --camera-facing="$facing" --no-audio --no-window --v4l2-sink="$dev"
        notify "Phone camera on" "Pick \"Phone camera\" in the app; dots-phone webcam again stops it"
        ;;
    qr) show_qr "${1:-$(wl-paste --no-newline --type text 2>/dev/null || true)}" ;;
    wifi-qr)
        name=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2 == "802-11-wireless" { print $1; exit }')
        [ -n "$name" ] || die "Not on Wi-Fi" "This computer has no active Wi-Fi connection to share"
        ssid=$(nmcli -g 802-11-wireless.ssid connection show "$name")
        psk=$(nmcli --show-secrets -g 802-11-wireless-security.psk connection show "$name")
        if [ -n "$psk" ]; then
            show_qr "WIFI:T:WPA;S:$(wifi_escape "$ssid");P:$(wifi_escape "$psk");;"
        else
            show_qr "WIFI:T:nopass;S:$(wifi_escape "$ssid");;"
        fi
        ;;
    quickshare)
        if pgrep -x rquickshare >/dev/null; then
            notify "Quick Share is already running" "It's in the tray"
            exit 0
        fi
        port="${DOTS_QUICKSHARE_PORT:-53320}"
        [[ $port =~ ^[0-9]+$ ]] || die "Bad DOTS_QUICKSHARE_PORT" "$port"
        dir="$HOME/.local/share/dev.mandre.rquickshare"
        f="$dir/.settings.json"
        mkdir -p "$dir"
        # RQuickShare picks a random port unless its settings name one; it resets the whole file
        # if the JSON is invalid, so write a validated copy (keeping a backup) while it's closed
        tmp=$(mktemp "$dir/.settings.XXXXXX")
        if [ -s "$f" ] && jq --argjson p "$port" '.port = $p' "$f" >"$tmp" 2>/dev/null; then
            [ "$(jq -r .port "$f" 2>/dev/null)" = "$port" ] || cp -- "$f" "$f.bak"
        else
            jq -n --argjson p "$port" '{port: $p}' >"$tmp"
        fi
        mv -f -- "$tmp" "$f"
        exec rquickshare
        ;;
    "" | -h | --help)
        cat <<'EOF'
usage: dots-phone COMMAND
  ring | send [FILE...] | send-clipboard | sms | pair      KDE Connect (Android, iPhone)
  mirror | webcam [back|front|stop]                        scrcpy (Android)
  qr [TEXT] | wifi-qr                                      QR codes (any phone)
  quickshare                                               Android Quick Share
EOF
        ;;
    *)
        echo "dots-phone: unknown command '$cmd' (dots-phone --help)" >&2
        exit 2
        ;;
esac
