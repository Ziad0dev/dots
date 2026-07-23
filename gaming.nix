{ pkgs, username, ... }:

# ── Gaming ────────────────────────────────────────────────────────────────────
# CachyOS kernel + Steam stack. Game libraries live on the /data LUKS
# partition (mounted nofail — if it ever fails to unlock, Steam just shows
# games as uninstalled; nothing breaks).
#
# This file owns boot.kernelPackages (see note in configuration.nix).

{
  # CachyOS kernel — BORE scheduler + sched-ext patches. Comes prebuilt from
  # the chaotic-nyx cache (nyx-cache module in flake.nix). The nvidia module
  # in configuration.nix follows config.boot.kernelPackages, so the open
  # driver is rebuilt against this kernel automatically (few minutes, local).
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # sched-ext userspace scheduler. scx_lavd is the latency-oriented one
  # (originally built for the Steam Deck) — good default for gaming.
  # Check with: systemctl status scx
  services.scx = {
    enable    = true;
    scheduler = "scx_lavd";
  };

  # ── Steam ──────────────────────────────────────────────────────────────────
  # Note: programs.steam sets hardware.graphics.enable32Bit and the vm.max_map_count
  # sysctl itself; configuration.nix already has 32-bit GL on for Wine anyway.
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;                  # "Gamescope" session in SDDM
    extraCompatPackages = [ pkgs.proton-ge-bin ];    # GE-Proton in compat dropdown
    remotePlay.openFirewall      = false;
    dedicatedServer.openFirewall = false;
  };

  # gamemoded — games (or `gamemoderun %command%`) request perf governor etc.
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud        # overlay: mangohud %command%
    protonup-qt     # manage extra Proton-GE builds imperatively if wanted
    heroic          # Epic/GOG launcher — drop if unused
  ];

  # ── Game library on /data ──────────────────────────────────────────────────
  # Creates the dir with your ownership at boot. The Steam library itself is
  # imperative state: Steam → Settings → Storage → Add Drive → /data/games,
  # then set it as default. Proton prefixes (compatdata) live inside the
  # library folder, so they travel with the games.
  systemd.tmpfiles.rules = [
    "d /data/games 0755 ${username} users -"
  ];
}
