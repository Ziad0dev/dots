{ pkgs, config, ... }:

let
  # Oxocarbon-ish accents to match the rest of the setup.
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
        # Ghostty implements the kitty graphics protocol, so a real image
        # renders properly rather than as ASCII. Drop any PNG at the path
        # below. `width`/`height` are in terminal CELLS, not pixels.
        type = "kitty";
        source = "${config.home.homeDirectory}/dots/config/fastfetch/logo.png";
        width = 32;
        height = 16;
        padding.top = 2;
        padding.left = 2;

        # --- alternatives, swap in by replacing the block above ---
        # Built-in flat NixOS lambda, no image needed:
        #   type = "builtin"; source = "nixos2";
        # Others: nixos, nixos_small, nixos_old, nixos_old_small
        #
        # Image rendered as coloured ASCII (works in any terminal, incl. TTY):
        #   type = "chafa"; source = "...logo.png"; width = 40;
        #
        # Your own ASCII art with $1/$2 colour placeholders:
        #   type = "file"; source = "...nixos.txt";
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
        {
          type = "custom";
          format = "\u001b[${mauve}m────────────────────────────";
        }
        { type = "os"; key = "  os"; }
        { type = "kernel"; key = "  kernel"; format = "{release}"; }
        { type = "wm"; key = "  wm"; }
        { type = "shell"; key = "  shell"; }
        { type = "terminal"; key = "  term"; }
        { type = "packages"; key = "  pkgs"; }
        { type = "uptime"; key = "  uptime"; }
        {
          type = "custom";
          format = "\u001b[${mauve}m────────────────────────────";
        }
        { type = "cpu"; key = "  cpu"; showPeCoreCount = true; }
        { type = "gpu"; key = "  gpu"; }
        { type = "memory"; key = "  mem"; }
        { type = "swap"; key = "  swap"; }
        { type = "disk"; key = "  disk"; folders = "/:/data"; }
        {
          type = "custom";
          format = "\u001b[${mauve}m────────────────────────────";
        }
        { type = "colors"; symbol = "circle"; }
        "break"
      ];
    };
  };
}
