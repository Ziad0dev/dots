{ pkgs, config, ... }:

# Theme switching, adapted from omarchy's approach (MIT, David Heinemeier
# Hansson — github.com/basecamp/omarchy).
#
# Omarchy's model: each theme is a directory of per-app config fragments;
# switching copies the chosen theme into a stable path, then pokes every
# running app to re-read it. Apps never reference a theme by name — only the
# stable path — so adding a theme requires no app config changes.
#
# What changes here, because this is NixOS and not Arch:
#
#   * Omarchy ships whole per-app config files per theme (btop.theme,
#     vscode.json, ...). That means duplicating every app's config across
#     every theme. Instead each theme here is ONE palette file (colors.sh)
#     and the switcher RENDERS the per-app fragments from shared templates.
#     Adding a theme = 25 hex values, not 12 files.
#
#   * Omarchy's lock screen is Quickshell (`omarchy-shell lock`), a whole
#     compositor shell. Not ported — hyprlock is already here and the
#     hyprlock.conf is rendered from the palette like everything else.
#
#   * Rendered output goes to $XDG_STATE_HOME, never into the repo, so
#     switching themes never shows up as a git diff.
#
# Layout:
#   config/themes/<name>/colors.sh      the palette (the whole theme)
#   config/themes/<name>/wallpaper.*    optional, picked up if present
#   config/themes/_templates/*.in       shared per-app templates
#   ~/.local/state/dots/theme/          rendered output + `current` symlink

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

        mkdir -p "$STATE"

        # Export the palette so envsubst can see it. shellcheck can't follow
        # a runtime source, hence the disable.
        set -a
        # shellcheck disable=SC1091
        . "$dir/colors.sh"
        set +a

        # Render every template. envsubst only substitutes variables that are
        # exported, so a stray $TIME in hyprlock.conf.in would be blanked —
        # pass an explicit allow-list so hyprlock's own $TIME survives.
        local vars
        vars=$(sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\)=.*/''${\1}/p' "$dir/colors.sh" | tr '\n' ' ')

        envsubst "$vars" < "$TPL/colors.lua.in"        > "$STATE/colors.lua"
        envsubst "$vars" < "$TPL/hyprlock.conf.in"     > "$STATE/hyprlock.conf"
        envsubst "$vars" < "$TPL/waybar-colors.css.in" > "$STATE/waybar-colors.css"
        envsubst "$vars" < "$TPL/rofi-colors.rasi.in"  > "$STATE/rofi-colors.rasi"

        ln -nsf "$dir" "$STATE/current"
        echo "$name" > "$STATE/name"

        # Wallpaper, if the theme ships one.
        local wp
        wp=$(find "$dir" -maxdepth 1 -type f \
               \( -iname 'wallpaper.*' -o -iname 'background.*' \) | head -n1)
        if [ -n "$wp" ] && command -v awww >/dev/null; then
          awww img "$wp" --transition-type fade --transition-duration 1 || true
        fi

        # Poke the running apps. Each is optional — a missing one must not
        # fail the switch.
        command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
        pkill -SIGUSR2 waybar 2>/dev/null || true
        command -v dunstctl >/dev/null && dunstctl reload 2>/dev/null || true
        systemctl --user restart hypridle 2>/dev/null || true

        command -v notify-send >/dev/null && \
          notify-send -t 2000 "theme" "$name" || true
        echo "theme: $name"
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
  home.packages = [ themectl ];

  # A rofi picker over the same script, for a keybind.
  programs.fish.functions.theme = {
    description = "pick a theme with rofi";
    body = ''
      set -l pick (themectl list | rofi -dmenu -i -p "theme")
      test -n "$pick"; and themectl set $pick
    '';
  };
}
