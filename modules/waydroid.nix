{ pkgs, ... }:

{
  virtualisation.waydroid.enable = true;

  environment.systemPackages = [ pkgs.waydroid-helper ];

  networking.firewall.extraCommands = ''
    ip46tables -N dots-waydroid 2>/dev/null || ip46tables -F dots-waydroid
    ip46tables -A dots-waydroid -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip46tables -A dots-waydroid -p udp -m multiport --dports 53,67 -j ACCEPT
    ip46tables -A dots-waydroid -p tcp --dport 53 -j ACCEPT
    ip46tables -A dots-waydroid -j DROP
    ip46tables -I nixos-fw 1 -i waydroid0 -j dots-waydroid
  '';

  networking.firewall.extraStopCommands = ''
    ip46tables -D nixos-fw -i waydroid0 -j dots-waydroid 2>/dev/null || true
    ip46tables -F dots-waydroid 2>/dev/null || true
    ip46tables -X dots-waydroid 2>/dev/null || true
  '';
}
