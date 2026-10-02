{ config, pkgs, ... }:
let
  themectl = pkgs.writeShellApplication {
    name = "themectl";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gettext
      gnugrep
      gnused
      jq
      matugen
      procps
      systemd
    ];
    text = builtins.readFile ../scripts/themectl.sh;
  };

in
{
  home.packages = [ themectl ];

  xdg.configFile."cava/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/dots/theme/cava";

  xdg.configFile."fuzzel/fuzzel.ini".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/dots/theme/fuzzel.ini";
}
