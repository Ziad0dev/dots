{ pkgs, config, ... }:

# Theme switching (Omarchy-inspired) — Waybar + Ghostty stay Oxocarbon.
#
# Layout:
#   ~/dots/config/themes/<name>/colors.sh
#   ~/dots/config/themes/<name>/preview.png
#   ~/dots/config/themes/<name>/wallpaper.*
#   ~/dots/config/themes/_templates/*.in
#   ~/.local/state/dots/theme/   rendered output + current symlink

let
  dots = "${config.home.homeDirectory}/dots";
  stateDir = "${config.home.homeDirectory}/.local/state/dots/theme";

  themectl = pkgs.writeShellApplication {
    name = "themectl";
    runtimeInputs = with pkgs; [ gettext coreutils gnused findutils ];
    text = ''
      THEMES="${dots}/config/themes"
      TPL="$THEMES/_templates"
      STATE="${stateDir}"

      usage() {
        echo "themectl list            list available themes"
        echo "themectl set <name>      apply a theme"
        echo "themectl current         print the active theme"
        echo "themectl next            cycle to the next theme"
      }

      list_themes() {
        find "$THEMES" -mindepth 1 -maxdepth 1 -type d \
          ! -name '_*' -printf '%f\n' | sort
      }

      apply() {
        local name="$1"
        local dir="$THEMES/$name"
        [ -d "$dir" ] || { echo "no such theme: $name" >&2; exit 1; }
        [ -f "$dir/colors.sh" ] || { echo "missing colors.sh in $name" >&2; exit 1; }

        mkdir -p "$STATE"

        set -a
        # shellcheck disable=SC1091
        . "$dir/colors.sh"
        set +a

        local vars
        vars=$(sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\)=.*/''${\1}/p' "$dir/colors.sh" | tr '\n' ' ')

        # Theme Rofi, hyprlock, optional nvim — NOT waybar, NOT terminal
        if [ -f "$TPL/colors.lua.in" ]; then
          envsubst "$vars" < "$TPL/colors.lua.in" > "$STATE/colors.lua"
        fi
        if [ -f "$TPL/hyprlock.conf.in" ]; then
          envsubst "$vars" < "$TPL/hyprlock.conf.in" > "$STATE/hyprlock.conf"
        fi
        if [ -f "$TPL/rofi-colors.rasi.in" ]; then
          envsubst "$vars" < "$TPL/rofi-colors.rasi.in" > "$STATE/rofi-colors.rasi"
        fi

        ln -nsf "$dir" "$STATE/current"
        echo "$name" > "$STATE/name"

        # Wallpaper (prefer wallpaper.*, else preview.png)
        local wp
        wp=$(find "$dir" -maxdepth 1 -type f \
               \( -iname 'wallpaper.*' -o -iname 'background.*' \) | head -n1)
        if [ -z "$wp" ]; then
          wp=$(find "$dir" -maxdepth 1 -type f -iname 'preview.png' | head -n1)
        fi
        if [ -n "$wp" ] && command -v awww >/dev/null; then
          awww img "$wp" --transition-type fade --transition-duration 1 || true
        fi

        # Reload apps that should follow the theme — never waybar
        command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
        command -v dunstctl >/dev/null && dunstctl reload 2>/dev/null || true
        systemctl --user restart hypridle 2>/dev/null || true

        command -v notify-send >/dev/null && \
          notify-send -t 2000 "theme" "$name" || true
        echo "theme: $name (waybar/terminal unchanged)"
      }

      case "''${1:-}" in
        list)    list_themes ;;
        current) cat "$STATE/name" 2>/dev/null || echo "(none)" ;;
        set)     [ -n "''${2:-}" ] || { usage; exit 1; }; apply "$2" ;;
        next)
          mapfile -t all < <(list_themes)
          cur=$(cat "$STATE/name" 2>/dev/null || echo "")
          idx=-1
          for i in "''${!all[@]}"; do
            [ "''${all[$i]}" = "$cur" ] && idx=$i && break
          done
          apply "''${all[$(( (idx + 1) % ''${#all[@]} ))]}"
          ;;
        *)       usage; exit 1 ;;
      esac
    '';
  };
in
{
  home.packages = [ themectl pkgs.quickshell ];

  home.file.".config/quickshell/theme-picker" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dots}/config/quickshell/theme-picker";
  };

  programs.fish.functions.theme = {
    description = "pick a theme with rofi (fallback)";
    body = ''
      set -l pick (themectl list | rofi -dmenu -i -p "theme")
      test -n "$pick"; and themectl set $pick
    '';
  };
}
