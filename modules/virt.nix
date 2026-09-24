{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  vmGroup = "claude-vm";
  vmChain = "claude-vm-out";

  vmRules = ipt: blocked: ''
    ${ipt} -w -N ${vmChain} 2>/dev/null || ${ipt} -w -F ${vmChain}
    ${ipt} -w -C OUTPUT -m owner --gid-owner ${vmGroup} -j ${vmChain} 2>/dev/null \
      || ${ipt} -w -A OUTPUT -m owner --gid-owner ${vmGroup} -j ${vmChain}
    ${ipt} -w -A ${vmChain} -m conntrack ! --ctstate NEW -j RETURN
    ${ipt} -w -A ${vmChain} -p udp --dport 53 -j RETURN
    ${ipt} -w -A ${vmChain} -p tcp --dport 53 -j RETURN
    ${ipt} -w -A ${vmChain} -m addrtype --dst-type LOCAL -j REJECT
    ${ipt} -w -A ${vmChain} -d ${blocked} -j REJECT
  '';

  vmRulesStop = ipt: ''
    ${ipt} -w -D OUTPUT -m owner --gid-owner ${vmGroup} -j ${vmChain} 2>/dev/null || true
    ${ipt} -w -F ${vmChain} 2>/dev/null || true
    ${ipt} -w -X ${vmChain} 2>/dev/null || true
  '';
in
{

  virtualisation.libvirtd = {
    enable = true;

    onBoot = "ignore";
    onShutdown = "shutdown";

    qemu = {
      package = pkgs.qemu_kvm;

      runAsRoot = false;

      swtpm.enable = true;

      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  systemd.services.libvirtd = {
    wants = [ "data.mount" ];
    after = [ "data.mount" ];
  };

  users.users.${username}.extraGroups = [ "kvm" ];

  users.groups.${vmGroup}.members = [ username ];

  programs.virt-manager.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virt-viewer
    spice-gtk
    virtio-win

    qemu

    OVMF
    swtpm
  ];

  systemd.tmpfiles.rules = [
    "d /data/vms 0771 root libvirtd -"
    "a+ /data/vms - - - - u:${username}:rwx"
    "d /data/vms/iso 0771 ${username} libvirtd -"
  ];

  networking.firewall.interfaces.virbr0 = {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };

  networking.firewall.extraCommands =
    vmRules "iptables" "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,169.254.0.0/16"
    + vmRules "ip6tables" "fc00::/7,fe80::/10";

  networking.firewall.extraStopCommands = vmRulesStop "iptables" + vmRulesStop "ip6tables";

}
