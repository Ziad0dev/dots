{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{

  services.mullvad-vpn = {
    enable = true;

    gui.enable = true;
  };

  services.resolved.enable = true;

}
