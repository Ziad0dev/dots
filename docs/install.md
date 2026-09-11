# Getting started

## Pick an output

| You have | Build | Profile |
|---|---|---|
| The desktop (or a fork of it) | `nixosConfigurations.nixos` | desktop: Hyprland + everything in `modules/` |
| A Mac | `darwinConfigurations.mac` | nix-darwin + home-manager, darwin profile |
| Any Linux with Nix, headless | `homeConfigurations."ziad0dev@linux"` / `"ziad0dev@aarch64-linux"` | minimal: shell, editors, CLI tools |
| Any Linux with Nix, graphical | `homeConfigurations."ziad0dev@linux-desktop"` | desktop home profile without the NixOS system layer |
| A throwaway sandbox | `nixosConfigurations.claude-vm` | see [Development](development.md#agent-vm) |

`username` is set once at the top of `flake.nix`; hostnames are per output.

## NixOS

```fish
git clone https://github.com/Ziad0dev/dots ~/dots
cd ~/dots
nixos-generate-config --show-hardware-config > hosts/nixos/hardware-configuration.nix
sudo nixos-rebuild switch --flake .#nixos
```

After the first switch, `nh` takes over (`update` in fish). See [Workflow](workflow.md).

### Machine-specific values

The desktop output is built for one box. On anything else, go through this list before switching — most of these fail soft (`nofail` mounts, units that aren't autostarted), but not all.

| Where | Value | Why it matters |
|---|---|---|
| `hosts/nixos/hardware-configuration.nix` | LUKS root, `/data` (LUKS2 via crypttab + keyfile), `/boot` | Replace wholesale |
| `hosts/nixos/configuration.nix` | `hardware.nvidia` block, `fixZstdRefs pkgs.nvidia_cachyos` | NVIDIA + CachyOS kernel only; drop on other GPUs |
| `hosts/nixos/configuration.nix` | `uid = 1001` | `DOCKER_HOST` in `home/profiles/linux-desktop.nix` hardcodes `/run/user/1001` |
| `hosts/nixos/configuration.nix` | timezone, locale, `dots.sddm.theme` | |
| `modules/gaming.nix` | `boot.kernelPackages = linuxPackages_cachyos` | Kernel choice lives here, not in the host |
| `modules/storage.nix`, `modules/media.nix` | exFAT drives by UUID | `nofail` + automount, so missing drives don't block boot |
| `modules/lan.nix` | `lanInterface = "enp5s0"` | Jellyfin ports are opened on this interface only |
| `modules/recording.nix` | `monitor = "DP-1"` | Replay buffer captures nothing if the output doesn't exist |
| `modules/performance.nix` | `cpuProfile`, `pl1Watts` / `pl2Watts` | Intel RAPL limits for a 12400F |
| `config/hypr/hyprland.lua` | `monitorProfiles`, workspace → monitor rules | Unknown outputs fall back to `preferred/auto` |
| `home/profiles/linux-desktop.nix` | MPD `hw:CARD=G30`, udiskie ignore list | Bit-perfect DAC output, drive UUIDs |
| `modules/vpn.nix` | qBittorrent `AuthSubnetWhitelist`, Mullvad DNS | |
| `modules/hello-page.nix` | expects `~/the-page/app.py` | Restarts every 5 s if the app isn't there — drop the module on other machines |

### Files that must exist out-of-band

Nothing secret is in the store. These are created by hand once:

| Path | Used by | Notes |
|---|---|---|
| `/etc/wireguard/mullvad.conf` | `modules/vpn.nix` | Mullvad WireGuard config; `wg-dns` rewrites its `DNS =` line on every start |
| `/etc/restic/password` | `modules/backup.nix` | Unit refuses to start if empty |
| `/etc/luks-data.key` | `hardware-configuration.nix` crypttab | Unlocks `/data` after root is open |
| `/var/lib/secrets/the-page.env` | `modules/hello-page.nix` | Optional (`-` prefix) |
| `~/.password-store` | `pass`, `secretspec`, `pass-secret-service` | `pass init <gpg-id>` |
| `/data/models/*.gguf` | `modules/llm.nix` | Units aren't autostarted, so missing models only fail on demand |
| `/data/models/whisper/ggml-*.bin` | `voxtype` | Dictation |
| `~/Pictures/wallpapers/` | `themectl bg`, wallpaper picker | |

Also: `sudo tailscale up` once — Jellyfin's remote access, the qBittorrent/Prowlarr port mappings and `hello-page-serve` all ride the tailnet.

### First login

```fish
themectl set kanagawa
```

Until a theme has been rendered, `~/.local/state/dots/theme/` is empty. Everything that includes from it is written to tolerate that (Ghostty's `config-file = ?…`, Hyprland's `pcall(dofile …)`, Neovim's oxocarbon fallback), but borders, the bar and the lock screen look default until you run it. See [Theming](theming.md).

## macOS

```fish
git clone https://github.com/Ziad0dev/dots ~/dots
sudo nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake ~/dots#mac
```

Rebuild afterwards with `sudo darwin-rebuild switch --flake ~/dots#mac`. The `update` abbrev on darwin expands to `nh darwin switch`, but nh is only installed by the NixOS host — see [rough edges](troubleshooting.md#known-rough-edges). Homebrew is declared in `hosts/darwin/default.nix` but `enable = false`.

## Any other Linux

```fish
git clone https://github.com/Ziad0dev/dots ~/dots
nix run github:nix-community/home-manager -- switch --flake ~/dots#ziad0dev@linux
```

Rebuild afterwards with `home-manager switch --flake ~/dots#ziad0dev@linux` — the base profile enables `programs.home-manager`, so the CLI is on PATH. As on macOS, the `update` abbrev assumes nh.

On a fresh upstream Nix install, prefix with `nix --extra-experimental-features 'nix-command flakes'` until flakes are enabled.

### Cloned somewhere other than `~/dots`

Set both options — one is a NixOS option, the other a home-manager option:

```nix
dots.repoPath = "/path/to/dots";                               # NixOS, drives nh's flake path
home-manager.users.<you>.dots.repoPath = "/path/to/dots";      # HM, drives every config/ symlink
```

For standalone home-manager, `mk.home` takes a `repoPath` argument. Some scripts still assume `~/dots` — see [Troubleshooting → rough edges](troubleshooting.md#known-rough-edges).
