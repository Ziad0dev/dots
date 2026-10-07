# Getting started

## Pick an output

| You have | Build | Profile |
|---|---|---|
| The desktop (or a fork of it) | `nixosConfigurations.nixos` | desktop: Hyprland + everything in `modules/` |
| A Mac | `darwinConfigurations.mac` | nix-darwin + home-manager, darwin profile |
| Any Linux with Nix, headless | `homeConfigurations."ziad0dev@linux"` / `"ziad0dev@aarch64-linux"` | minimal: shell, editors, CLI tools |
| Any Linux with Nix, graphical | `homeConfigurations."ziad0dev@linux-desktop"` | desktop home profile without the NixOS system layer |

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
| `hosts/nixos/configuration.nix` | `hardware.nvidia` block (`nvidia_cachyos-bore`) | NVIDIA + CachyOS kernel only; drop on other GPUs |
| `hosts/nixos/configuration.nix` | timezone, locale, `dots.sddm.theme` | |
| `modules/gaming.nix` | `boot.kernelPackages = linuxPackages_cachyos-bore` | Kernel choice lives here, not in the host |
| `modules/storage.nix`, `modules/media.nix` | exFAT drives by UUID, pool disks by label (`pool1`…), `/data/scratch` by partlabel | `nofail`, so missing drives don't block boot |
| `modules/lan.nix` | `lanInterface = "enp5s0"` | Jellyfin ports are opened on this interface only |
| `hosts/nixos/configuration.nix` | `dots.recording.monitor = "DP-1"` | Replay buffer captures nothing if the output doesn't exist (manual recordings take the focused output) |
| `modules/performance.nix` | `cpuProfile`, `pl1Watts` / `pl2Watts` | Intel RAPL limits for a 12400F |
| `config/hypr/hyprland.lua` | `monitorProfiles`, workspace → monitor rules | Unknown outputs fall back to `preferred/auto` |
| `home/profiles/linux-desktop.nix` | MPD `hw:CARD=G30`, udiskie ignore list | Bit-perfect DAC output, drive UUIDs |
| `modules/vpn.nix` | qBittorrent `AuthSubnetWhitelist`, Mullvad DNS | |
| `modules/hello-page.nix` | expects `~/the-page/app.py` | Skipped (`ConditionPathExists`) when the app isn't there |

### Files that must exist out-of-band

Nothing secret is in the store. These are created by hand once — or, for the first three secrets, kept encrypted in the repo instead: [Secrets](secrets.md).

| Path | Used by | Notes |
|---|---|---|
| `/etc/wireguard/mullvad.conf` | `modules/vpn.nix` | Mullvad WireGuard config; `wg-dns` rewrites its `DNS =` line on every start |
| `/etc/restic/password` | `modules/backup.nix` | Unit refuses to start if empty |
| `/etc/luks-data.key` | crypttab (`hardware-configuration.nix`, `modules/storage.nix`) | Unlocks `/data` and `/data/scratch` after root is open |
| `/var/lib/secrets/the-page.env` | `modules/hello-page.nix` | Optional (`-` prefix) |
| `~/.password-store` | `pass`, `secretspec`, `pass-secret-service` | `pass init <gpg-id>` |
| `/data/models/*.gguf` | `modules/llm.nix` | Units aren't autostarted, so missing models only fail on demand |
| `/data/models/whisper/ggml-*.bin` | `voxtype` | Dictation |
| `~/Pictures/wallpapers/` | `themectl bg`, wallpaper picker | |

Also: `sudo tailscale up` once — Jellyfin's remote access, the qBittorrent/Prowlarr port mappings and `hello-page-serve` all ride the tailnet.

### First login

The first activation renders `dots.theme` (oxocarbon), so the session starts themed. Pick another with `themectl set kanagawa` — see [Theming](theming.md).

## A new machine: disko + `dots-install`

`lib/disko.nix` is a one-disk layout (ESP + LUKS2 + btrfs subvolumes; with `impermanence = true`, `/` is a tmpfs and state lives in `/persist`). A host imports it with its disk:

```nix
imports = [
  inputs.disko.nixosModules.disko
  (import ../../lib/disko.nix { device = "/dev/nvme0n1"; impermanence = true; })
];
```

Add the host to `dots.installer.hosts` (next to `vm` in `flake.nix`), build the ISO and write it to a stick:

```fish
nix build .#nixosConfigurations.installer.config.system.build.isoImage
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot it and run `dots-install <host> [--age-key FILE]`. It asks for the disk passphrase, partitions and formats (erasing the disk), puts the age key where the host's `dots.secrets.keyFile` expects it, and installs the prebuilt system — offline, nothing is built. The desktop itself is not on disko: its disks hold `/data`, and a layout that can wipe them isn't worth having around.

### Testing in a VM

`nixosConfigurations.vm` is the whole path in miniature. The quick check boots its config in a NixOS test:

```fish
nix build .#checks.x86_64-linux.vm -L
```

The full one installs it from the ISO onto a blank disk under QEMU (UEFI from `OVMF.fd`):

```fish
qemu-img create -f qcow2 vm.qcow2 20G
cp (nix build --print-out-paths nixpkgs#OVMF.fd)/FV/OVMF_VARS.fd vars.fd; chmod +w vars.fd
set ovmf (nix build --print-out-paths nixpkgs#OVMF.fd)/FV/OVMF_CODE.fd
qemu-system-x86_64 -enable-kvm -m 4096 -smp 4 -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=$ovmf -drive if=pflash,format=raw,file=vars.fd \
  -drive file=vm.qcow2,if=virtio -cdrom result/iso/*.iso
# in the ISO:
sudo dots-install vm --age-key /etc/dots/hosts/vm/test-age-key.txt
```

Then boot without `-cdrom`, give the disk passphrase, and log in as `ziad0dev` / `dots` (the password comes from `secrets/vm.yaml`). Anything written outside `/home`, `/nix` and the persisted paths is gone after a reboot.

`tests/iso-install.py` does all of that unattended over the serial console — install, LUKS unlock, login, secrets, home-manager, theme, then a second boot to check that `/` was reset and `/var/log`, `/home` and `machine-id` were kept. Usage is in its header.

## macOS

```fish
git clone https://github.com/Ziad0dev/dots ~/dots
sudo nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake ~/dots#mac
```

Rebuild afterwards with `sudo darwin-rebuild switch --flake ~/dots#mac`. The `update` abbrev on darwin expands to `nh darwin switch`; home-manager installs nh there. Homebrew is declared in `hosts/darwin/default.nix` but `enable = false`.

## Any other Linux

```fish
git clone https://github.com/Ziad0dev/dots ~/dots
nix run github:nix-community/home-manager -- switch --flake ~/dots#ziad0dev@linux
```

Rebuild afterwards with `home-manager switch --flake ~/dots#ziad0dev@linux` — the base profile enables `programs.home-manager`, so the CLI is on PATH. `update` expands to `nh home switch -c ziad0dev@linux` (the output you switched to), and home-manager installs nh.

On a fresh upstream Nix install, prefix with `nix --extra-experimental-features 'nix-command flakes'` until flakes are enabled.

### Cloned somewhere other than `~/dots`

Set both options — one is a NixOS option, the other a home-manager option:

```nix
dots.repoPath = "/path/to/dots";                               # NixOS, drives nh's flake path
home-manager.users.<you>.dots.repoPath = "/path/to/dots";      # HM, drives every config/ symlink
```

For standalone home-manager, `mk.home` takes a `repoPath` argument. Scripts get the path baked in at build time, so nothing else needs it.

### No checkout at all

Set `dots.liveConfig = false` and every linked config comes from the flake source in the store instead of `repoPath` — see [Architecture](architecture.md#live-config-dotslink-and-dotsliveconfig).
