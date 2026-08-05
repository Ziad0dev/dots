{ config, lib, pkgs, username, ... }:

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

  users.users.${username}.extraGroups = [ "libvirtd" "kvm" ];

  programs.virt-manager.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virt-viewer
    spice-gtk
    virtio-win

    libguestfs-with-appliance

    qemu
    quickemu
  ];

  systemd.tmpfiles.rules = [
    "d /data/vms 0771 root libvirtd -"
    "d /data/vms/iso 0771 ${username} libvirtd -"
  ];

  networking.firewall.trustedInterfaces = [ "virbr0" ];

}
