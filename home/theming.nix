{ config, pkgs, ... }:
let
  themectl = pkgs.writeShellApplication {
    name = "themectl";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      findutils
      gettext
      gnugrep
      gnused
      jq
      matugen
      procps
      systemd
    ];
    # live: the checkout's themes; pure: the ones in the store
    text = ''
      DOTS_DIR="''${DOTS_DIR:-${config.dots.src}}"
    ''
    + builtins.readFile ../scripts/themectl.sh;
  };

in
{
  home.packages = [ themectl ];

  xdg.configFile."cava/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/dots/theme/cava";

  xdg.configFile."fuzzel/fuzzel.ini".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/dots/theme/fuzzel.ini";
}
