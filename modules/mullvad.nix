{ ... }:

{

  services.mullvad-vpn = {
    enable = false;
    gui.enable = false;
  };

  services.resolved = {
    enable = true;
    settings.Resolve.LLMNR = "no";
  };

}
