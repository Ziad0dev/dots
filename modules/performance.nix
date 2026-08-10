{ config, lib, pkgs, ... }:

let
  ##########################################################################
  ## CPU PERFORMANCE PROFILE
  ##
  ## Flip this one string. Read the notes below before choosing "max".
  ##
  ##   "default"    - stock NixOS. intel_pstate active + powersave algorithm.
  ##   "responsive" - active + powersave, but EPP pinned to performance.
  ##                  RECOMMENDED. Keeps dynamic scaling, kills the ramp lag.
  ##   "max"        - active + performance algorithm. Pins the max P-state
  ##                  permanently. Highest idle power and heat.
  ##   "passive"    - hands frequency control back to the generic CPUFreq
  ##                  layer + schedutil, which is what sched_ext schedulers
  ##                  actually talk to. See the sched_ext note below.
  ##
  ## NOTE ON "powersave": on this machine the scaling driver is intel_pstate
  ## in ACTIVE mode. Its "powersave" is NOT the generic powersave governor --
  ## it does not park the CPU at minimum frequency. It is a dynamic algorithm
  ## roughly equivalent to schedutil/ondemand. So the 915 MHz idle reading was
  ## normal behaviour, not a stuck governor. The lever that actually matters
  ## in active mode is EPP, not the governor name.
  ##########################################################################
  cpuProfile = "responsive";

  isPassive = cpuProfile == "passive";
  isMax     = cpuProfile == "max";
  setsEPP   = cpuProfile == "responsive";
in
{

  ##########################################################################
  ## MEMORY / SWAP  (unchanged)
  ##########################################################################

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

  ##########################################################################
  ## CPU FREQUENCY
  ##
  ## Is "max" safe? Yes. The performance algorithm requests the highest
  ## P-state; it does NOT lift any protection. PL1/PL2 package power limits
  ## and Tjmax thermal throttling are enforced in hardware and still apply,
  ## so the i5-12400F (65 W base / 117 W turbo) cannot be pushed past its
  ## own limits from software. What you actually pay is idle power, package
  ## temperature and fan noise -- not silicon lifetime.
  ##
  ## Why "responsive" is the default here anyway: in active mode the
  ## powersave algorithm already scales dynamically. The thing that makes a
  ## desktop feel slow is the RAMP DELAY on a wakeup, and EPP is the knob
  ## that governs how eagerly HWP ramps. Setting EPP=performance gets you
  ## almost all of the snappiness of "max" without sitting at max clock while
  ## you read a webpage.
  ##########################################################################

  # Active-mode governor. Only meaningful for "max"; in active mode the only
  # two valid values are "powersave" and "performance".
  powerManagement.cpuFreqGovernor =
    lib.mkIf (isMax || isPassive) (if isPassive then "schedutil" else "performance");

  # Passive mode has to be selected on the kernel command line so it is set
  # before the driver registers.
  #
  ## sched_ext note: scx_lavd communicates frequency intent through
  ## scx_bpf_cpuperf_set(), which is consumed by the schedutil governor. In
  ## intel_pstate ACTIVE mode the generic governor layer is bypassed entirely,
  ## so those hints land nowhere and HWP decides alone -- it has no idea lavd
  ## has narrowed its primary domain to CPU 0. If you intend to keep scx_lavd,
  ## "passive" is the coherent choice: it is the only profile where the
  ## scheduler and the governor are actually talking to each other.
  boot.kernelParams = lib.mkIf isPassive [ "intel_pstate=passive" ];

  # EPP (Energy Performance Preference) is a 0-255 HWP bias, exposed as the
  # strings: default performance balance_performance balance_power power.
  # There is no NixOS option for it, so write it directly. Re-applied on
  # resume because suspend resets the MSR.
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

  # Heat lever, if you ever want it: capping the top P-state is done with
  #   echo 90 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
  # Leave it at 100 unless the package is actually running hot.

  # NOTE: both of these are per-kernel attributes under a linuxPackages set,
  # not top-level pkgs. Deliberately pkgs.linuxPackages (plain nixpkgs) rather
  # than config.boot.kernelPackages -- the latter resolves through chaotic's
  # own package set, which is the exact path that caused the nvidia unfree
  # eval failure. These are free packages so it would probably work, but there
  # is no reason to walk back into that package set for a diagnostic tool.
  environment.systemPackages = with pkgs; [
    linuxPackages.cpupower    # cpupower frequency-info
    linuxPackages.turbostat   # per-core MHz, package power, C-states
  ];
}
