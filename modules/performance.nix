{ config, lib, pkgs, ... }:

let

  cpuProfile = "responsive";

  isPassive = cpuProfile == "passive";
  isMax     = cpuProfile == "max";
  setsEPP   = cpuProfile == "responsive";
in
{

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024;
    }
  ];

  zramSwap.priority = 100;

  boot.kernel.sysctl = {

    "vm.swappiness" = 180;

    "vm.page-cluster" = 0;

    "vm.vfs_cache_pressure" = 50;

    "vm.dirty_bytes" = 268435456;
    "vm.dirty_background_bytes" = 134217728;

    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };

  systemd.oomd = {
    enableUserSlices = true;
    settings.OOM = {

      DefaultMemoryPressureDurationSec = "20s";
    };
  };

  systemd.services.nix-daemon.serviceConfig = {
    MemoryAccounting = true;

    MemoryMax = "75%";

    OOMScoreAdjust = 500;
  };

  nix.settings = {

    max-jobs = 3;
    cores = 4;

    min-free = 1024 * 1024 * 1024;
    max-free = 8 * 1024 * 1024 * 1024;
  };

  services.journald.extraConfig = ''
    SystemMaxUse=512M
    SystemMaxFileSize=64M
    MaxRetentionSec=1month
  '';

  hardware.nvidia.powerManagement.enable = true;

  powerManagement.cpuFreqGovernor =
    lib.mkIf (isMax || isPassive) (if isPassive then "schedutil" else "performance");

  boot.kernelParams = lib.mkIf isPassive [ "intel_pstate=passive" ];

  systemd.services.cpu-epp = lib.mkIf setsEPP {
    description = "Set HWP energy_performance_preference to performance";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        [ -w "$f" ] && echo performance > "$f"
      done
      exit 0
    '';
  };

  powerManagement.resumeCommands =
    lib.mkIf setsEPP "${pkgs.systemd}/bin/systemctl restart cpu-epp.service";

  environment.systemPackages = with pkgs; [
    linuxPackages.cpupower
    linuxPackages.turbostat
  ];
}
