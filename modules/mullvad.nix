{ ... }:

{

  services.mullvad-vpn = {
    enable = true;
    gui.enable = true;
  };

  services.resolved = {
    enable = true;
    settings.Resolve.LLMNR = "no";
  };

}
