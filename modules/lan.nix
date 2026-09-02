{ ... }:
let
  lanInterface = "enp5s0";
in
{
  networking.firewall.interfaces.${lanInterface} = {
    allowedTCPPorts = [
      8096
      8081
      8920
      9696
    ];
  };
}
