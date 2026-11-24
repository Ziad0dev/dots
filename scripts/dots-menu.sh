# dots-menu: everything in one searchable menu, after Omarchy's menu
# (SUPER + ALT + Space). The menu is the Rise launcher's menu mode
# (panels/AppLauncher.qml), so it looks like the rest of the shell; this
# fuzzel version below is the fallback when the bar isn't running, and what
# `dots-menu <section>` opens. Escape at any level closes it.
#
#   dots-menu [apps|learn|capture|share|toggle|style|setup|webapps|update|system]

# DOTS_DIR: the checkout (dots.repoPath; the package sets it)
DOTS_DIR="${DOTS_DIR:-$HOME/dots}"

# Each entry runs detached, so the menu (and its fuzzel) can go away.
go() { setsid -f "$@" >/dev/null 2>&1 </dev/null; }
qs_call() { go qs -c rise ipc call "$@"; }
# a terminal for things that ask for a password or want to be watched
# (the command is passed as arguments, never spliced into the bash -c text)
term() { go ghostty --class=com.dots.float.md -e bash -c '"$@"; echo; read -rp "Done. Enter closes this window."' _ "$@"; }
has() { command -v "$1" >/dev/null 2>&1; }

# menu PROMPT ITEM... : prints the chosen item, nothing on Escape
# (no items: a free-text prompt, which prints what was typed)
menu() {
    local prompt="$1" lines
    shift
    lines=$(($# > 0 ? $# : 1))
    if (($#)); then printf '%s\n' "$@"; fi |
        fuzzel --dmenu --prompt "$prompt › " --lines "$lines" --width 34 2>/dev/null || true
}

apps() { qs_call launcher toggle; }

main() {
    case "$(menu Menu Apps Learn Capture Share Toggle Style Setup "Web apps" Update System)" in
        Apps) apps ;;
        Learn) learn ;;
        Capture) capture ;;
        Share) share ;;
        Toggle) toggle ;;
        Style) style ;;
        Setup) setup ;;
        "Web apps") webapps ;;
        Update) update ;;
        System) system ;;
    esac
}

learn() {
    case "$(menu Learn Keybindings "Dots docs" "Hyprland wiki" "NixOS options" "Home Manager options")" in
        Keybindings) qs_call keybinds toggle ;;
        "Dots docs") go xdg-open "$DOTS_DIR/docs/README.md" ;;
        "Hyprland wiki") go xdg-open https://wiki.hypr.land ;;
        "NixOS options") go xdg-open https://search.nixos.org/options ;;
        "Home Manager options") go xdg-open https://home-manager-options.extranix.com ;;
    esac
}

capture() {
    case "$(menu Capture "Screenshot area" "Screenshot screen" "Screenshot window" "Record screen" "Record area" \
        "Stop recording" "Colour picker" "Identify song" "Google Lens")" in
        "Screenshot area") go dots-shot region ;;
        "Screenshot screen") go dots-shot screen ;;
        "Screenshot window") go dots-shot window ;;
        "Record screen") go dots-capture-screenrecording ;;
        "Record area") go dots-capture-screenrecording --region ;;
        "Stop recording") go dots-capture-screenrecording --stop ;;
        "Colour picker") go hyprpicker -a -n -f hex ;;
        "Identify song") go dots-songrec ;;
        "Google Lens") go dots-lens ;;
    esac
}

share() {
    case "$(menu Share "LocalSend" "Clipboard history" "Emoji")" in
        LocalSend) go localsend_app ;;
        "Clipboard history") qs_call clipboard toggle ;;
        Emoji) go bemoji -n -t ;;
    esac
}

toggle() {
    case "$(menu Toggle "Game mode" "Night light" "Do not disturb" "Stay awake" "Glass" "Blur" "Screensaver now")" in
        "Game mode") go dots-look game toggle ;;
        "Night light") go dots-nightlight toggle ;;
        "Do not disturb") go dots-toggle-notification-silencing ;;
        "Stay awake") go dots-toggle-idle ;;
        Glass) go dots-look glass toggle ;;
        Blur) go dots-look blur toggle ;;
        "Screensaver now") go dots-screensaver start ;;
    esac
}

style() {
    case "$(menu Style Theme "Next theme" Wallpaper "Next wallpaper" Animations "Screen shader" \
        "Layout: tiling" "Layout: scrolling" "Layout: floating")" in
        Theme) qs_call picker theme ;;
        "Next theme") go themectl next ;;
        Wallpaper) qs_call picker wallpaper ;;
        "Next wallpaper") go themectl bg next ;;
        Animations) go dots-look anim pick ;;
        "Screen shader") go dots-look shader pick ;;
        "Layout: tiling") go dots-layout set tiling ;;
        "Layout: scrolling") go dots-layout set scrolling ;;
        "Layout: floating") go dots-layout set floating ;;
    esac
}

setup() {
    local items=("Settings" "Settings app" "Audio")
    has nm-connection-editor && items+=("Network connections")
    case "$(menu Setup "${items[@]}")" in
        Settings) qs_call settings toggle ;;
        "Settings app") qs_call nexus toggle ;;
        Audio) if has wiremix; then go ghostty --class=com.dots.float.md -e wiremix; else go pavucontrol; fi ;;
        "Network connections") go nm-connection-editor ;;
    esac
}

webapps() {
    local name url icon out choice apps=()
    mapfile -t apps < <(dots-webapp list)
    choice=$(menu "Web apps" "Install…" "Remove…" "${apps[@]}")
    case "$choice" in
        "") ;;
        "Install…")
            name=$(menu "Name (e.g. YouTube)")
            [ -n "$name" ] || return 0
            url=$(menu "Address (https://…)")
            [ -n "$url" ] || return 0
            icon=$(menu "Icon PNG or SVG address (optional, Enter skips)")
            if out=$(dots-webapp install "$name" "$url" "$icon" 2>&1); then
                notify-send -a dots-menu "Web app installed" "$name is in the launcher" || true
            else
                notify-send -a dots-menu "Couldn't install $name" "$out" || true
            fi
            ;;
        "Remove…")
            name=$(menu Remove "${apps[@]}")
            [ -n "$name" ] || return 0
            if dots-webapp remove "$name"; then
                notify-send -a dots-menu "Web app removed" "$name" || true
            fi
            ;;
        *) go dots-webapp open "$choice" ;;
    esac
}

update() {
    case "$(menu Update "Rebuild system" "Update flake inputs and rebuild" "Update Flatpak apps" "Restart the bar")" in
        "Rebuild system") term nh os switch "$DOTS_DIR" ;;
        "Update flake inputs and rebuild") term nh os switch --update "$DOTS_DIR" ;;
        "Update Flatpak apps") term flatpak update ;;
        "Restart the bar") go systemctl --user restart quickshell ;;
    esac
}

system() {
    case "$(menu System Lock Screensaver "Session menu…")" in
        Lock) go loginctl lock-session ;;
        Screensaver) go dots-screensaver start ;;
        "Session menu…") qs_call session toggle ;;
    esac
}

case "${1:-}" in
    # the bar says "true" once it has opened (or closed) the menu
    "") [ "$(qs -c rise ipc call launcher menu 2>/dev/null)" = true ] || main ;;
    apps | learn | capture | share | toggle | style | setup | webapps | update | system) "$1" ;;
    *)
        echo "usage: dots-menu [apps|learn|capture|share|toggle|style|setup|webapps|update|system]" >&2
        exit 2
        ;;
esac
