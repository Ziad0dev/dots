{
  config,
  lib,
  pkgs,
  ...
}:

let

  cpuProfile = "responsive";

  isPassive = cpuProfile == "passive";
  isMax = cpuProfile == "max";
  usesPPD = cpuProfile == "responsive";

  pl1Watts = 65;
  pl2Watts = 117;
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

  services.journald.settings.Journal = {
    SystemMaxUse = "512M";
    SystemMaxFileSize = "64M";
    MaxRetentionSec = "1month";
  };

  powerManagement.cpuFreqGovernor = lib.mkIf (isMax || isPassive) (
    if isPassive then "schedutil" else "performance"
  );

  boot.kernelParams = [ "zswap.enabled=0" ] ++ lib.optional isPassive "intel_pstate=passive";

  # Runtime EPP switching (the bar's power-profile button): performance →
  # performance, balanced → balance_performance, power-saver → power. The
  # choice persists across reboots in /var/lib/power-profiles-daemon.
  services.power-profiles-daemon.enable = usesPPD;

  systemd.services.cpu-power-limit = {
    description = "Set RAPL package power limits";
    wantedBy = [ "multi-user.target" ];
    # writes sysfs, so no ProtectKernelTunables; everything else is shut
    serviceConfig = import ../lib/hardening.nix // {
      Type = "oneshot";
      RemainAfterExit = true;
      PrivateNetwork = true;
      ProtectKernelTunables = false;
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
    script = ''
      for d in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do
        [ -w "$d/constraint_0_power_limit_uw" ] && echo ${toString (pl1Watts * 1000000)} > "$d/constraint_0_power_limit_uw"
        [ -w "$d/constraint_1_power_limit_uw" ] && echo ${toString (pl2Watts * 1000000)} > "$d/constraint_1_power_limit_uw"
      done
      exit 0
    '';
  };

  environment.systemPackages = with pkgs; [
    linuxPackages.cpupower
    linuxPackages.turbostat
  ];
}
