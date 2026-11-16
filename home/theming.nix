{ config, ... }:
{
  # themectl itself is in home/themectl.nix (every profile)
  xdg.configFile."cava/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/dots/theme/cava";

  xdg.configFile."fuzzel/fuzzel.ini".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/dots/theme/fuzzel.ini";
}
