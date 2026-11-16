{
  pkgs,
  username,
  ...
}:

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

  users.users.${username}.extraGroups = [ "kvm" ];

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
    "d /var/lib/libvirt/images 0771 root libvirtd -"
    "a+ /var/lib/libvirt/images - - - - u:${username}:rwx"
    "d /var/lib/libvirt/isos 0771 ${username} libvirtd -"
  ];

  networking.firewall.interfaces.virbr0 = {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };

}
