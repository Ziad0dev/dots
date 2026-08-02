{ config, lib, pkgs, username, ... }:

{
  # ── Mullvad ───────────────────────────────────────────────────────────────
  services.mullvad-vpn = {
    enable = true;
    # The daemon and the GUI are separate packages now — setting `package` to
    # pkgs.mullvad-vpn breaks the daemon assertion, since that derivation no
    # longer ships one. Leave `package` alone and ask for the GUI here.
    gui.enable = true;
  };

  # Mullvad ships its own DNS handling and expects to drive resolved rather
  # than fight NetworkManager over /etc/resolv.conf. Without this, DNS leaks
  # or breaks outright when the tunnel comes up.
  services.resolved.enable = true;

 
}
