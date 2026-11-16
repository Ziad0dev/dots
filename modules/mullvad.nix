{ pkgs, ... }:

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

    # Encrypted, validated DNS. resolved only speaks DNS-over-TLS (not DoH);
    # same privacy, no extra daemon. This is policy only: the servers come from
    # the NetworkManager profile, set by the DNS switcher in the quickshell
    # network panel (config/quickshell/rise/scripts/qs-dns), which pins them as
    # "ip#tls-name". Strict DoT means a plain-DNS server never answers, so a
    # fresh profile has no working DNS until a server is picked there.
    # Two links are exempt: tailscale turns DoT off on its own link, and the
    # Mullvad tunnel is handled below (its in-tunnel DNS, 10.64.0.1, is plain
    # and does the ad/tracker blocking).
    settings.Resolve.DNSOverTLS = "true";
    settings.Resolve.DNSSEC = "true";
  };

  # The Mullvad tunnel's DNS is plain (and does the content blocking), which
  # strict DoT/DNSSEC would reject, so lookups would fail while connected. When
  # the tunnel link appears, relax both on that link only; the settings vanish
  # with the link on disconnect. Matches by name so it follows whatever the
  # daemon calls the interface.
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", KERNEL=="*mullvad*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mullvad-resolved@%k.service"
  '';

  systemd.services."mullvad-resolved@" = {
    description = "Relax resolved DoT/DNSSEC on the Mullvad tunnel %i";
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart =
        pkgs.writeShellScript "mullvad-resolved" ''
          iface=$1
          resolvectl=${pkgs.systemd}/bin/resolvectl
          # resolved learns about the link a moment after udev does
          for _ in $(seq 50); do
            $resolvectl status "$iface" >/dev/null 2>&1 && break
            sleep 0.2
          done
          $resolvectl dnsovertls "$iface" no
          $resolvectl dnssec "$iface" allow-downgrade
        ''
        + " %i";
    };
  };

}
