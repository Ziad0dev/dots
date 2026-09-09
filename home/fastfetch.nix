{ pkgs, config, ... }:

let
  blue = "38;2;51;177;255";
  pink = "38;2;238;83;150";
  mauve = "38;2;190;149;255";

  # Random logo, rendered fresh per invocation.
  #
  # chafa converts an image to ANSI at an EXACT cell size, so the art can never
  # overflow into the module column — the failure mode of hand-made .txt art,
  # whose height must be guessed. It also emits well-formed escapes, unlike
  # colorscripts written to be run standalone in a terminal.
  #
  # Sources, in order of preference:
  #   config/fastfetch/art/*.{png,jpg,jpeg}  your own picks
  #   config/themes/*/preview.{png,jpg}      the 46 theme previews
  #   config/themes/*/wallpaper.jpg          the wallpapers
  # All read at RUNTIME, so adding art needs no rebuild.
  randomArt = pkgs.writeShellScript "fastfetch-random-art" ''
    set -u
    repo="${config.dots.repoPath}"

    pick=$(${pkgs.findutils}/bin/find \
             "$repo/config/fastfetch/art" \
             "$repo/config/themes" \
             -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
             2>/dev/null \
           | ${pkgs.coreutils}/bin/shuf -n 1)
    [ -n "''${pick:-}" ] || exit 0

    exec ${pkgs.chafa}/bin/chafa \
      --format symbols --symbols block --size 24x12 \
      --colors full --dither none --polite on "$pick"
  '';
in
{
  home.packages = [ pkgs.chafa ];

  programs.fastfetch = {
    enable = true;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

      logo = {
        # command-raw uses the command's stdout verbatim. Needs fastfetch
        # >= 2.30; on older builds an unknown type degrades to NO logo.
        type = "command-raw";
        source = "${randomArt}";
        width = 24;
        height = 12;
        padding = {
          top = 1;
          left = 2;
          right = 3;
        };

        # Static fallbacks:
        #   type = "kitty"; source = "${config.dots.repoPath}/config/quickshell/rise/assets/nixos-logo.png";
        #   type = "builtin"; source = "nixos2";
        # `fastfetch --list-logos` shows ~300 built-in distro logos, all
        # correctly sized and coloured.
      };

      display = {
        separator = " ";
        color = {
          keys = blue;
          title = pink;
        };
      };

      modules = [
        "break"
        {
          type = "title";
          format = "{user-name}@{host-name}";
        }
        # `separator` draws the rule itself — do NOT hand-roll ANSI escapes
        # here: Nix has no \u escape, so "\u001b" ends up printed literally.
        {
          type = "separator";
          string = "─";
          outputColor = mauve;
        }
        {
          type = "os";
          key = "  os";
        }
        {
          type = "kernel";
          key = "  kernel";
          format = "{release}";
        }
        {
          type = "wm";
          key = "  wm";
        }
        {
          type = "shell";
          key = "  shell";
        }
        {
          type = "terminal";
          key = "  term";
        }
        {
          type = "uptime";
          key = "  uptime";
        }
        {
          type = "separator";
          string = "─";
          outputColor = mauve;
        }
        {
          type = "cpu";
          key = "  cpu";
        }
        {
          type = "gpu";
          key = "  gpu";
          format = "{name}";
        }
        {
          type = "memory";
          key = "  mem";
        }
        {
          type = "swap";
          key = "  swap";
        }
        {
          type = "disk";
          key = "  disk";
          folders = "/";
        }
        {
          type = "separator";
          string = "─";
          outputColor = mauve;
        }
        {
          type = "colors";
          symbol = "circle";
        }
        "break"
      ];
    };
  };
}
