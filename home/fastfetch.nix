{ pkgs, config, ... }:

let
  blue = "38;2;51;177;255";
  pink = "38;2;238;83;150";
  mauve = "38;2;190;149;255";
in
{
  home.packages = [ pkgs.chafa ];

  programs.fastfetch = {
    enable = true;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

      logo = {
        # Ghostty speaks the kitty graphics protocol, so a PNG renders as a
        # real image. width/height are terminal CELLS — 22x11 keeps it beside
        # the text instead of dominating the window.
        type = "kitty";
        source = "${config.dots.repoPath}/config/quickshell/rise/assets/nixos-logo.png";
        width = 22;
        height = 11;
        preserveAspectRatio = true;
        padding = {
          top = 1;
          left = 2;
          right = 3;
        };

        # No image handy? Built-in art, nothing else to install:
        #   type = "builtin"; source = "nixos2";
        # Others: nixos, nixos_small, nixos_old, nixos_old_small
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
