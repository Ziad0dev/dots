# System modules

Everything in `modules/` is imported by `desktopModules` in `flake.nix`, together with chaotic's `nyx-cache`, `nyx-overlay` and `nyx-registry`. Order doesn't matter except where noted. Anything with more moving parts is covered in [Services](services.md) or [Desktop](desktop.md).

## Host: `hosts/nixos/configuration.nix`

What stays in the host rather than a module is what's specific to this hardware or has nowhere better to go.

| Area | Settings |
|---|---|
| Boot | systemd-boot, `configurationLimit = 3`, `nct6775` (board sensors) |
| Sleep | Suspend, hibernate, hybrid-sleep all disabled at the systemd level — the box never sleeps |
| GPU | `hardware.nvidia`: open kernel module, modesetting, `nvidiaPersistenced`, `package = fixZstdRefs pkgs.nvidia_cachyos`; LACT; CoolerControl |
| Session | `programs.hyprland` from the flake input (package + portal), XWayland; portals hyprland → gtk, ScreenCast/Screenshot pinned to hyprland |
| Desktop plumbing | dbus, polkit (+ rule letting the active local session mount/eject via udisks), printing, gvfs, udisks2, usbmuxd (iPhone) |
| Off | Bluetooth, blueman |
| Containers | Docker **rootless** (`enableOnBoot = false`), Podman |
| User | fish, uid 1001, groups `wheel networkmanager audio video input libvirtd` |
| Nix | flakes, `cache.nixos.org` + `hyprland.cachix.org`, `allowUnfree`, overlays from `lib/overlays.nix`, auto-optimise |
| Env | `NIXOS_OZONE_WL`, `MOZ_ENABLE_WAYLAND`, `QT_QPA_PLATFORM=wayland;xcb` |
| Packages | Rescue and system-level set only: git, curl, wget, jq, tree, zip, neovim, htop, btop, lm_sensors, usbutils, gparted, exfatprogs, libimobiledevice, ifuse, hyprpolkitagent, coolercontrol-gui, DaVinci Resolve (`dvr-patched`), share picker, ark, qt6ct |
| Fonts | Fira Code / JetBrains Mono Nerd, Noto (+CJK, emoji), Font Awesome, plus document fonts (New Computer Modern, Libertinus, STIX Two, Latin Modern, DejaVu, Liberation) |

The package test for the system list: root needs it, a system service needs it, it has to work before login or with a broken home-manager generation, or NixOS has to discover a unit file from it. Everything else goes to `home.packages`.

## Modules

### Base system

| Module | Owns |
|---|---|
| `quality.nix` | The NixOS `dots.repoPath` option; nix-daemon at idle CPU/IO priority; `trusted-users`; `keep-outputs` / `keep-derivations`; nix-community cache; `/tmp` wiped on boot; `vm.max_map_count` (games), `split_lock_mitigate = 0`; weekly fstrim; plocate (pruned of `/nix/store`, `/mnt`, `/data`, …); gamemode settings; smartd; fwupd; Avahi mDNS |
| `performance.nix` | 8 GiB swapfile + zram at priority 100, `swappiness 180` / `page-cluster 0` (zram tuning), dirty-bytes caps, inotify limits, systemd-oomd on user slices, nix-daemon `MemoryMax 75%` + OOM score 500, `max-jobs 3` / `cores 4`, journald caps, CPU profile (below), RAPL limits, cpupower + turbostat |
| `dev.nix` | `programs.nh` (flake = `dots.repoPath`), nh's GC timer `--keep 3 --keep-since 4d`, `warn-dirty = false` |
| `cleanup.nix` | Coredump storage capped at 1 GiB |
| `secrets.nix` | secretspec, pass, gnupg agent with pinentry-qt, bitwarden-cli |
| `ananicy-fix.nix` | Overlay: prepends `<cstring>`/`<cstdint>` to every ananicy-cpp source file so 1.2.0 builds on current libc++. Delete once nixpkgs ships a fixed ananicy-cpp |

#### CPU profile (`performance.nix`)

`cpuProfile` is a `let` binding at the top of the file:

| Value | Effect |
|---|---|
| `"responsive"` (default) | `intel_pstate` active mode; a `cpu-epp` oneshot writes `performance` to every CPU's energy-performance preference. In active mode EPP is the lever that matters, not the governor name |
| `"max"` | `performance` governor |
| `"passive"` | `intel_pstate=passive` + schedutil — the only mode where a sched_ext scheduler's frequency hints reach a governor |

`cpu-power-limit` sets RAPL PL1/PL2 from `pl1Watts` / `pl2Watts` (65 / 117 W) at boot.

### Desktop

| Module | Owns |
|---|---|
| `sddm.nix` | The SDDM greeter, built from `config/sddm/dots` + a theme palette. See [Desktop → login](desktop.md#login-sddm) |
| `lockscreen.nix` | `security.pam.services.quickshell-lock` — the PAM stack the Quickshell lock screen authenticates against |
| `osd.nix` | swayosd's libinput backend (system unit + dbus), started with `graphical.target` |
| `audio.nix` | PipeWire (ALSA incl. 32-bit, Pulse, JACK, WirePlumber), rtkit; clock allowed at 44.1/48/88.2/96/176.4/192 kHz so bit-perfect playback doesn't resample; resample quality 10 |
| `hdr.nix` | libplacebo; `DXVK_HDR=1`, `PROTON_ENABLE_WAYLAND=1`, `PROTON_ENABLE_HDR=1` |
| `recording.nix` | gpu-screen-recorder (with the capability wrapper), GTK front-end, the `gsr-replay` user unit, `/data/replays`. See [Desktop → recording](desktop.md#recording) |
| `flatpak.nix` | Flatpak + the `flatpak-managed` reconciler. See [Services → flatpak](services.md#flatpak) |
| `foreign.nix` | Running non-Nix binaries: nix-ld, AppImage binfmt, an `fhs` shell, distrobox, steam-run. See [Development → foreign binaries](development.md#foreign-binaries) |

### Gaming

| Module | Owns |
|---|---|
| `gaming.nix` | **The kernel** (`linuxPackages_cachyos`); sched_ext (`scx_lavd`, currently **disabled**); Steam + gamescope session + `proton-cachyos`, remote-play/dedicated ports closed; gamemode; ananicy-cpp with CachyOS rules; ProtonUp-Qt, Heroic; `/data/games` |
| `gaming-extras.nix` | protontricks, winetricks, Lutris |

Per-user: MangoHud in `home/gaming-home.nix` (hidden by default, `Right Shift + F12`).

### Dev

| Module | Owns |
|---|---|
| `dev-langs.nix` | System-wide toolchains: Zig 0.16.0 + zls, nixd, lua-language-server, clang_multi / clang-tools / lldb / gdb / mold / ccache / bear / meson / ninja / valgrind / cppcheck, python313 + uv / ruff / pyright, SBCL (swank, alexandria) + rlwrap; ccache at `/var/cache/ccache` |
| `virt.nix` | libvirtd (unprivileged QEMU, swtpm, virtiofsd), virt-manager, SPICE USB redirection, OVMF, virtio-win; `/data/vms` and `/data/vms/iso`; `virbr0` trusted; libvirtd ordered after `data.mount` |

### Services and network

| Module | Owns | Details |
|---|---|---|
| `media.nix` | Jellyfin (NVENC), Radarr, Sonarr, Tailscale, the 10 TB `/mnt/media` mount, `media` group (gid 3000) | [Services](services.md#media) |
| `media-extras.nix` | Audiobookshelf, calibre-web, whisper-cpp | [Services](services.md#media) |
| `vpn.nix` | WireGuard namespace `wg`; qBittorrent, Prowlarr, FlareSolverr confined to it | [Services](services.md#vpn-namespace) |
| `mullvad.nix` | Mullvad daemon + GUI for the host; systemd-resolved with LLMNR off | |
| `lan.nix` | Jellyfin ports on the LAN interface only | |
| `llm.nix` | Six llama.cpp units (Vulkan), mutually exclusive, user-startable without sudo | [Services](services.md#local-llms) |
| `ollama.nix` | Ollama (Vulkan) on `127.0.0.1:11434`, not autostarted | [Services](services.md#local-llms) |
| `backup.nix` | Daily restic of `$HOME` to `/mnt/backup/restic` | [Services](services.md#backups) |
| `storage.nix` | `/mnt/backup` (root-only, hidden from file managers) and `/mnt/newvolume` | [Services](services.md#storage) |
| `hello-page.nix` | A small Python site from `~/the-page`, published on the tailnet with `tailscale serve` | [Services](services.md#hello-page) |

## Adding a module

1. Create `modules/<thing>.nix`. Module arguments available: `config lib pkgs inputs username hostname system profile`.
2. Add `./modules/<thing>.nix` to `desktopModules` in `flake.nix`.
3. `git add -A` — the pre-commit hook fails on a flake reference to an untracked file.
4. `update`.

Service modules follow a common shape: `openFirewall = false`, `unitConfig.RequiresMountsFor` on any external mount the service reads, and `serviceConfig = import ../lib/hardening.nix // { … }` with the exceptions it needs.
