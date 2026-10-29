{ config, lib, ... }:
{
  # the wired NIC, named by the host: it's hardware, and the LAN-facing
  # ports open on it only
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
}
