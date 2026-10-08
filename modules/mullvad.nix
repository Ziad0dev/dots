{ ... }:

{

  services.mullvad-vpn = {
    enable = true;
    gui.enable = true;
  };

  services.resolved = {
    enable = true;
    settings.Resolve.LLMNR = "no";
    # avahi (+ nss-mdns) answers .local; two mDNS stacks on 5353 make both
    # unreliable and avahi warns about it on every boot
    settings.Resolve.MulticastDNS = "no";
  };

}
