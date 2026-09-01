{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{

  services.mullvad-vpn = {
    enable = false;

    gui.enable = false;
  };

  services.resolved.enable = true;

}
