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

    MemoryHigh = "50%";
    MemoryMax = "75%";

    OOMScoreAdjust = 500;
  };

  nix.settings = {

    max-jobs = 4;
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

  # RAPL package limits at boot. The sustained limit (PL1) is the one the CPU
  # reports as its own rating, so no part number or wattage is written in
  # this public repo. A machine-local /var/lib/dots/cpu-power-limit.env
  # (PL1_WATTS=…, PL2_WATTS=…) overrides PL1 and is the only source of PL2;
  # without it the boost limit stays as the firmware set it.
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
      EnvironmentFile = "-/var/lib/dots/cpu-power-limit.env";
    };
    script = ''
      for d in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do
        [ -d "$d" ] || continue
        if [ -n "''${PL1_WATTS:-}" ]; then
          pl1=$((PL1_WATTS * 1000000))
        else
          pl1=$(cat "$d/constraint_0_max_power_uw" 2>/dev/null || echo 0)
        fi
        if [ "$pl1" -gt 0 ] && [ -w "$d/constraint_0_power_limit_uw" ]; then
          echo "$pl1" > "$d/constraint_0_power_limit_uw"
        fi
        if [ -n "''${PL2_WATTS:-}" ] && [ -w "$d/constraint_1_power_limit_uw" ]; then
          echo $((PL2_WATTS * 1000000)) > "$d/constraint_1_power_limit_uw"
        fi
      done
      exit 0
    '';
  };

  environment.systemPackages = with pkgs; [
    linuxPackages.cpupower
    linuxPackages.turbostat
  ];
}
