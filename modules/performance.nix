{ config, lib, pkgs, ... }:

# modules/performance.nix — memory, swap, OOM behaviour, and VM tuning.
#
# Context: 15.4 GiB RAM with zram-only swap. zram compresses pages *inside*
# RAM, so it buys roughly 2-3 GiB of effective headroom, not real capacity —
# once it's full there is nowhere to spill to and the kernel OOM killer
# starts shooting whatever is largest, which is why terminals and browsers
# were dying. Three fixes here, in order of importance:
#
#   1. a real swap file, so cold pages leave RAM entirely
#   2. systemd-oomd actually monitoring something (NixOS enables the daemon
#      but leaves every slice unmanaged by default, so it does nothing)
#   3. nix builds bounded, so `nh os switch` can't eat the desktop
#
# CPU-side scheduling is already handled in gaming.nix (scx_lavd +
# ananicy-cpp + CachyOS kernel) — deliberately not duplicated here.

{
  # ── Swap ────────────────────────────────────────────────────────────────
  # NixOS creates this file on activation. It lives on the LUKS root, so
  # swapped-out pages are encrypted at rest. 8 GiB is sized for "absorb a
  # browser + a Nix build", not for hibernation (which would need >= RAM
  # size plus a resume= kernel param, and isn't configured).
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024; # MiB
    }
  ];

  # NOTE: zramSwap.enable/memoryPercent stay in hosts/nixos/configuration.nix.
  # Only `priority` is set here — different attributes of the same option
  # merge across modules, so this does NOT conflict with that block.
  # Priority must outrank the swapfile (which defaults to -1 / 5) so hot
  # pages compress in RAM and only genuinely cold ones reach the disk.
  zramSwap.priority = 100;

  boot.kernel.sysctl = {
    # zram/SSD swap is orders of magnitude faster than the spinning disks
    # the default of 60 was tuned for. 180 is the value the zram maintainers
    # and CachyOS both use: swap early and often rather than thrashing the
    # page cache.
    "vm.swappiness" = 180;

    # Swap readahead is a pessimisation for zram — it's random-access
    # memory, not a disk with seek costs. 0 = read exactly one page.
    "vm.page-cluster" = 0;

    # Reclaim inode/dentry caches less eagerly. Helps a lot with the huge
    # directory trees on this machine (nix store, exFAT media library).
    "vm.vfs_cache_pressure" = 50;

    # Cap dirty writeback in bytes rather than percent. On 15 GiB the
    # percentage defaults let ~3 GiB of dirty pages accumulate, which turns
    # into a multi-second stall when it finally flushes — very visible as
    # audio dropouts and input lag during large writes.
    "vm.dirty_bytes" = 268435456; # 256 MiB
    "vm.dirty_background_bytes" = 134217728; # 128 MiB

    # File watchers: lazy.nvim, direnv, and language servers across large
    # trees exhaust the default 65536 quickly and then fail silently.
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };

  # ── Userspace OOM killer ────────────────────────────────────────────────
  # NixOS sets systemd.oomd.enable = true by default but leaves
  # enableRootSlice / enableSystemSlice / enableUserSlices all FALSE — so
  # the daemon runs and manages nothing. Turning on user slices gives it
  # something to act on: it watches PSI memory-pressure and kills the
  # worst-offending cgroup *before* the kernel's OOM killer has to make a
  # cruder choice.
  #
  # NixOS's implementation uses ManagedOOMMemoryPressure (pressure-based),
  # not ManagedOOMSwap (swap-usage-based). That matters: the swap-based
  # policy is the one that caused the well-known "oomd killed my browser
  # for no reason" complaints on other distros, and it isn't in play here.
  systemd.oomd = {
    enableUserSlices = true;
    settings.OOM = {
      # Only act on sustained pressure, not a momentary spike during e.g.
      # a game launching or a compile starting.
      DefaultMemoryPressureDurationSec = "20s";
    };
  };

  # ── Keep Nix builds from eating the desktop ─────────────────────────────
  # Builds run as children of nix-daemon, so they share its cgroup and these
  # limits apply to the whole build tree.
  systemd.services.nix-daemon.serviceConfig = {
    MemoryAccounting = true;
    # Hard ceiling. A build that exceeds it gets killed (the build fails)
    # instead of the kernel picking a victim from your session. Raise it if
    # a legitimately large build starts failing with OOM.
    MemoryMax = "75%";
    # Tiebreaker: if the kernel OOM killer does have to choose, make the
    # build far more attractive than anything you're using.
    OOMScoreAdjust = 500;
  };

  nix.settings = {
    # 12 threads, 15.4 GiB — the default (max-jobs = auto = 12) can put a
    # dozen compilers in flight at once, which is how a rebuild turns into
    # an OOM. 3 jobs x 4 cores saturates the CPU with bounded memory.
    max-jobs = 3;
    cores = 4;
    # Bail out of a build rather than filling the root filesystem: if free
    # space drops below min-free, nix GCs until max-free is available.
    min-free = 1024 * 1024 * 1024; # 1 GiB
    max-free = 8 * 1024 * 1024 * 1024; # 8 GiB
  };

  # ── Logs ────────────────────────────────────────────────────────────────
  # The default journal cap is 10% of the filesystem — tens of GiB here, and
  # this machine logs heavily (jellyfin, the *arrs, docker, hyprland).
  services.journald.extraConfig = ''
    SystemMaxUse=512M
    SystemMaxFileSize=64M
    MaxRetentionSec=1month
  '';

  # ── NVIDIA suspend/resume ───────────────────────────────────────────────
  # Without this the driver doesn't save VRAM contents across suspend, so
  # anything holding GPU memory (a game, llama-server, a compositor) comes
  # back corrupted or wedged. Costs a little suspend/resume time.
  hardware.nvidia.powerManagement.enable = true;
}
