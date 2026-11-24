# dots-webapp: a website as an app (Omarchy's web apps). It gets its own
# launcher entry, icon and window: Helium's app mode, no tabs or address bar.
#
#   dots-webapp install NAME URL [ICON-URL]   ICON-URL: an https PNG or SVG
#   dots-webapp remove NAME
#   dots-webapp list
#   dots-webapp open NAME
#   dots-webapp add | pick-remove             asks in the terminal (the menu's
#                                             Install… and Remove…)
#
# URL is https, or http on this machine only (the offline hub,
# http://127.0.0.1:8090/maps). Without an icon it uses the theme's browser
# icon. Entries are dots-webapp-<name>.desktop files in
# ~/.local/share/applications; the launcher and the dock pick them up.

apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
browser="${DOTS_WEBAPP_BROWSER:-helium}"

die() {
    printf 'dots-webapp: %s\n' "$1" >&2
    exit 1
}

# "YouTube Music" -> youtube-music; refuses names that leave nothing
slug_of() {
    local s
    s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')
    [ -n "$s" ] || die "the name needs letters or digits"
    printf '%s' "${s:0:40}"
}

desktop_of() { printf '%s/dots-webapp-%s.desktop' "$apps" "$(slug_of "$1")"; }

valid_url() {
    [[ $1 =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]]*)?$ ]] ||
        [[ $1 =~ ^http://(localhost|127\.0\.0\.1)(:[0-9]+)?(/[^[:space:]]*)?$ ]]
}

# fetch the icon into place: https only, small, and a PNG or SVG by content.
# No checksum: an icon from an arbitrary site has none published, so the
# checks are the transport (https, redirects included), size and content
# type; the file is only ever drawn, never run.
fetch_icon() { # fetch_icon URL SLUG -> prints the icon name, or fails
    local url="$1" slug="$2" tmp mime dir ext
    [[ $url =~ ^https://[^[:space:]]+$ ]] || die "the icon address must be https"
    tmp=$(mktemp)
    if ! curl --proto '=https' --tlsv1.2 -fsSL --max-time 20 --max-filesize 2000000 -o "$tmp" -- "$url"; then
        rm -f "$tmp"
        die "couldn't download the icon"
    fi
    mime=$(file -b --mime-type -- "$tmp")
    case "$mime" in
        image/png) dir="$icons/256x256/apps" ext=png ;;
        image/svg+xml) dir="$icons/scalable/apps" ext=svg ;;
        *)
            rm -f "$tmp"
            die "the icon is $mime, not a PNG or SVG"
            ;;
    esac
    mkdir -p "$dir"
    chmod 644 "$tmp"
    # one icon per app: an earlier one in the other format would win
    rm -f -- "$icons/256x256/apps/dots-webapp-$slug.png" "$icons/scalable/apps/dots-webapp-$slug.svg"
    mv -f -- "$tmp" "$dir/dots-webapp-$slug.$ext"
    printf 'dots-webapp-%s' "$slug"
}

cmd_install() {
    local name="${1:-}" url="${2:-}" icon_url="${3:-}" slug icon file tmp
    [ -n "$name" ] && [ -n "$url" ] || die "usage: dots-webapp install NAME URL [ICON-URL]"
    # the name goes into a desktop file's Name=: one plain line
    [[ $name =~ ^[[:alnum:]][[:alnum:]\ ._+-]{0,39}$ ]] || die "keep the name to letters, digits, spaces and . _ + -"
    valid_url "$url" || die "the address must be https:// (or http:// on this machine)"
    slug=$(slug_of "$name")
    file=$(desktop_of "$name")
    # "YouTube Music" and "youtube.music" share a file: don't replace another
    # app (checked first, before its icon could be overwritten)
    if [ -f "$file" ] && [ "$(sed -n 's/^Name=//p' "$file" | head -n 1)" != "$name" ]; then
        die "\"$(sed -n 's/^Name=//p' "$file" | head -n 1)\" already uses that name; remove it first"
    fi
    icon=web-browser
    if [ -n "$icon_url" ]; then
        icon=$(fetch_icon "$icon_url" "$slug") || exit 1
    fi
    mkdir -p "$apps"
    tmp=$(mktemp "$file.XXXXXX")
    # Exec names the entry, not the URL: a URL in Exec would need desktop-file
    # escaping (% and quotes), and open reads it back from X-Dots-Url
    cat >"$tmp" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=Web app: $url
Exec=dots-webapp open $slug
Icon=$icon
Categories=Network;WebBrowser;
StartupNotify=true
X-Dots-Url=$url
EOF
    chmod 644 "$tmp"
    mv -f -- "$tmp" "$file"
}

cmd_remove() {
    local name="${1:-}" slug file
    [ -n "$name" ] || die "usage: dots-webapp remove NAME"
    slug=$(slug_of "$name")
    file=$(desktop_of "$name")
    [ -f "$file" ] || die "no web app called $name"
    # only the files install wrote
    rm -f -- "$file" "$icons/256x256/apps/dots-webapp-$slug.png" "$icons/scalable/apps/dots-webapp-$slug.svg"
}

cmd_list() {
    local f
    for f in "$apps"/dots-webapp-*.desktop; do
        [ -f "$f" ] || continue
        sed -n 's/^Name=//p' "$f" | head -n 1
    done
}

cmd_open() {
    local name="${1:-}" file url
    [ -n "$name" ] || die "usage: dots-webapp open NAME"
    file=$(desktop_of "$name")
    [ -f "$file" ] || die "no web app called $name"
    url=$(sed -n 's/^X-Dots-Url=//p' "$file" | head -n 1)
    valid_url "$url" || die "$file has no valid X-Dots-Url"
    exec "$browser" --app="$url"
}

# the menu opens these in a small terminal
finish() {
    echo
    read -rp "Enter closes this window." _ || true
}

cmd_add() {
    local name url icon
    echo "A website as an app: its own launcher entry, icon and window."
    echo
    read -rp "Name (e.g. YouTube Music): " name || exit 0
    [ -n "$name" ] || exit 0
    read -rp "Address (https://…): " url || exit 0
    echo "Icon: an https PNG or SVG address, e.g. from"
    echo "  https://github.com/homarr-labs/dashboard-icons (Enter skips)"
    read -rp "Icon address: " icon || true
    if (cmd_install "$name" "$url" "$icon"); then
        echo "Installed: \"$name\" is in the launcher and the dock's app list."
    fi
    finish
}

cmd_pick_remove() {
    local list=() i choice
    mapfile -t list < <(cmd_list)
    if [ "${#list[@]}" -eq 0 ]; then
        echo "No web apps installed."
        finish
        exit 0
    fi
    for i in "${!list[@]}"; do printf '%3d  %s\n' "$((i + 1))" "${list[i]}"; done
    echo
    read -rp "Remove which (number, Enter cancels): " choice || exit 0
    if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
        if (cmd_remove "${list[choice - 1]}"); then echo "Removed \"${list[choice - 1]}\"."; fi
        finish
    fi
}

case "${1:-}" in
    install) shift; cmd_install "$@" ;;
    add) cmd_add ;;
    pick-remove) cmd_pick_remove ;;
    remove) shift; cmd_remove "$@" ;;
    list) cmd_list ;;
    open) shift; cmd_open "$@" ;;
    *) die "usage: dots-webapp {install NAME URL [ICON-URL] | remove NAME | list | open NAME | add | pick-remove}" ;;
esac
