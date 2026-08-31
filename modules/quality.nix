{ lib, pkgs, ... }:

{

  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  nix.settings = {
    trusted-users = [ "@wheel" ];
    keep-outputs = true;
    keep-derivations = true;
    substituters = [ "https://nix-community.cachix.org" ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  boot.tmp.cleanOnBoot = true;

  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
    "kernel.split_lock_mitigate" = 0;
    "net.core.rmem_max" = 2500000;
  };

  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  services.locate = {
    enable = true;
    package = pkgs.plocate;
    prunePaths = [
      "/tmp"
      "/var/tmp"
      "/var/cache"
      "/var/lib/docker"
      "/var/lib/libvirt"
      "/nix/store"
      "/mnt"
      "/data"
    ];
  };

  programs.gamemode.settings = {
    general = {
      renice = 10;
      inhibit_screensaver = 1;
    };
  };

  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.wall.enable = true;
  };

  services.fwupd.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

}
