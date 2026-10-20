{ config, lib, ... }:
{
  # the wired NIC, named by the host: it's hardware, and the LAN-facing
  # ports (Jellyfin here, Forgejo in forgejo.nix) open on it only
  options.dots.lanInterface = lib.mkOption {
    type = lib.types.str;
    example = "enp5s0";
    description = "Network interface the LAN-facing services open their firewall ports on.";
  };

  config.networking.firewall.interfaces.${config.dots.lanInterface} = {
    allowedTCPPorts = [
      8096
      8920
      # soulseek-rs listener (home/soulseek.nix); peers reach it through a
      # port forward on the router
      2234
    ];
    allowedUDPPorts = [ 5353 ];
  };

  # answer for <hostname>.local on the LAN: Forgejo's ROOT_URL is nixos.local
  config.services.avahi.publish = {
    enable = true;
    addresses = true;
  };
}
