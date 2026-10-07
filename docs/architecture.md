# Architecture

## Layout

```
flake.nix       inputs, username, every output
lib/            mk.nix (output builders), overlays, shared systemd hardening, nvidia fix
hosts/          nixos/ (the desktop), darwin/
modules/        NixOS modules, one concern per file
home/           home-manager: home.nix dispatcher, profiles/, one module per app
config/         raw app config, symlinked live into ~/.config
config/themes/  palettes + templates rendered by themectl
flakes/         standalone tool flakes (infosec, maths), also imported as HM modules
templates/      `nix flake init` templates
scripts/        shell sources packaged by the nix modules, plus the git hook
```

## Outputs

| Output | Built by | Contents |
|---|---|---|
| `nixosConfigurations.nixos` | `mk.nixos` | `hosts/nixos/*` + `desktopModules` + chaotic's cache/overlay/registry modules + home-manager (profile `desktop`) |
| `darwinConfigurations.mac` | `mk.darwin` | `hosts/darwin/` + home-manager (profile `desktop`, which on darwin selects the darwin profile) |
| `homeConfigurations."ziad0dev@mac"` | `mk.home` | aarch64-darwin, desktop |
| `homeConfigurations."ziad0dev@linux"` | `mk.home` | x86_64-linux, minimal |
| `homeConfigurations."ziad0dev@linux-desktop"` | `mk.home` | x86_64-linux, desktop |
| `homeConfigurations."ziad0dev@aarch64-linux"` | `mk.home` | aarch64-linux, minimal |
| `nixosConfigurations.vm` | `mk.nixos` | `hosts/vm`: a small test host — disko layout, root on tmpfs, sops, home-manager minimal with `liveConfig = false` |
| `nixosConfigurations.installer` | `mk.nixos` (no home) | `hosts/installer`: minimal ISO + `dots-install`, with every host in `dots.installer.hosts` prebuilt |
| `checks.x86_64-linux.vm` | `tests/vm.nix` | NixOS test booting the vm host: sops, pure home-manager, default theme |
| `templates.*` | — | nine project templates, see [Development](development.md#project-templates) |
| `formatter.<system>` | — | `nixfmt-tree` for `nix fmt` |

Supported systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin` (nixpkgs 26.11 dropped `x86_64-darwin`).

## `lib/mk.nix`

Three builders, all passing the same `specialArgs` — `inputs`, `username`, `hostname`, `system`, `profile` — so every module can take them as arguments.

```nix
mk.nixos  { hostname, username, system ? "x86_64-linux", profile ? "desktop", modules ? [ ], homeModule ? ../home/home.nix, home ? true }
mk.darwin { hostname, username, system ? "aarch64-darwin", profile ? "desktop", modules ? [ ], homeModule ? ../home/home.nix }
mk.home   { name, username, system, profile ? "minimal", repoPath ? null, homeDirectory ? null, modules ? [ ] }
```

When home-manager rides on a system (`mk.nixos`, `mk.darwin`) it runs with `useGlobalPkgs`, `useUserPackages`, `backupFileExtension = "backup"` and `overwriteBackup` (a second clash on the same file replaces the old `.backup` instead of failing the activation). There is no separate `home-manager switch` on the desktop — one `nh os switch` activates both, and one rollback reverts both.

`mk.home` imports nixpkgs itself (`mkPkgs`) with `allowUnfree` and `lib/overlays.nix`.

## Inputs

| Input | Role | Notes |
|---|---|---|
| `chaotic` | chaotic-nyx: CachyOS kernel, `nvidia_cachyos`, `proton-cachyos`, ananicy rules, binary cache, registry entry | **Source of nixpkgs** |
| `nixpkgs` | — | `follows = "chaotic/nixpkgs"` |
| `home-manager` | | chaotic's HM follows this one |
| `nix-darwin` | Mac output | |
| `hyprland` | compositor + portal, NixOS module | hyprland.cachix.org substituter configured |
| `hyprland-preview-share-picker` | screenshare picker for xdph | |
| `zen-browser`, `helium` | browsers | |
| `nixcord` | Discord + Vencord + OpenASAR | its `nixpkgs-packages` and `nixpkgs-ci` inputs also follow ours |
| `obsidian-extensions` | overlay: `obsidianPlugins`, `obsidianThemes` | |
| `zig-overlay`, `zls` | Zig 0.16.0 + matching zls | overlay provides `pkgs.zigpkgs` |
| `nix-index-database` | prebuilt nix-index DB, powers `,` | |
| `nix-flatpak` | declarative user flatpaks (`home/flatpak.nix`) | no inputs of its own |
| `vpn-confinement` | `vpnNamespaces` NixOS module | |
| `vm-curator` | VM management tool | |

Every input that has a nixpkgs input follows ours; duplicates are what drag in a second or third nixpkgs.

## Home-manager composition

`home/home.nix` is only a dispatcher:

| Profile file | Loaded when | Carries |
|---|---|---|
| `profiles/base.nix` | always | `dots.repoPath` / `dots.theme` options, shell (fish + abbrevs), git, ssh, direnv + nix-direnv, CLI tools, nvim/ghostty/tmux/broot/ranger/btop links, dev-home, fastfetch, yazi, git-hooks, infosec + maths `core` sets |
| `profiles/linux-desktop.nix` | Linux and `profile == "desktop"` | Hyprland session target, Quickshell, theming, GTK/Qt/cursor, desktop apps, MPD, udiskie, hypridle, nixcord, emacs, Obsidian, Spicetify, … |
| `profiles/darwin.nix` | macOS | GNU userland, `open` abbrevs, macOS defaults |

Everything under `home/` that isn't a profile is an app module imported by one of these.

## Live config: `dotsLink` and `dots.liveConfig`

```nix
{ dotsLink, ... }:
{ home.file.".config/hypr".source = dotsLink "hypr"; }
```

`dotsLink` is a module argument set in `profiles/base.nix`. What it returns depends on `dots.liveConfig`:

| `dots.liveConfig` | `~/.config/hypr` points at | Edits | Rollback |
|---|---|---|---|
| `true` (default) | `<repoPath>/config/hypr`, via `mkOutOfStoreSymlink` | land immediately, no rebuild | does **not** revert config — the link follows the working tree |
| `false` | `<store copy of config/>/config/hypr` | need a rebuild | reverts with the generation; no checkout needed |

Pure mode is what the `vm` host uses, and what to pick on a machine you deploy to rather than edit on. Configs are read-only there, so apps that write into their own config dir (btop saving `btop.conf`, lazy.nvim's `lazy-lock.json`) can't persist those writes.

Either way home-manager doesn't know the contents of a linked directory — so **each config path has exactly one owner**: either a `dotsLink` or an HM module, never both.

| Linked from `config/` | By |
|---|---|
| nvim, ghostty, tmux, broot, ranger, btop.conf | `profiles/base.nix` |
| hypr, quickshell, flameshot, gammastep, rmpc, mpv, Kvantum themes, zen → `~/.config/zen-theme`, share-picker | `profiles/linux-desktop.nix` |
| yazi (`yazi.toml`, `keymap.toml`, `init.lua` — per file) | `home/yazi.nix` |
| emacs `init.el` | `home/emacs.nix` |

Files linked to `~/.local/state/dots/theme/*` instead of `config/` (btop theme, yazi theme, swayosd css) are themectl output — see [Theming](theming.md).

## `dots.repoPath` and `dots.src`

`dots.repoPath` is the git checkout. Declared twice, in two namespaces, both defaulting to `~/dots`:

- NixOS: `modules/quality.nix` — used by `programs.nh.flake`.
- home-manager: `home/profiles/base.nix` — used by `dotsLink` in live mode, the `flakeup` abbrev, git hooks, standalone `programs.nh.flake`, and baked into the scripts that act on the checkout (`dots-update`, `dots-updates`, `dots-timemachine`; each still honours `DOTS_REPO` / `DOTS_DIR`).

`dots.src` (home-manager, read-only) is where `config/` is *read* from at runtime: `repoPath` in live mode, a store copy of just `config/` in pure mode (so unrelated repo edits don't rebuild it). themectl's palettes and templates, fastfetch art and the theme pickers (`DOTS_DIR` in the Quickshell unit) use it. Scripts under `config/quickshell/rise/scripts` are reached through `~/.config/quickshell/rise`, which is right in both modes.

How rebuild abbrevs are chosen: `update` is `nh os switch` when home-manager rides on NixOS, `nh darwin switch` on nix-darwin, and `nh home switch -c <output>` for a standalone `homeConfigurations` output (`mk.home` passes its attribute name). Off NixOS, home-manager installs nh itself.

## Runtime state

| Path | Written by | Read by |
|---|---|---|
| `~/.local/state/dots/theme/` | `themectl` | every themed app — see [Theming](theming.md#templates) |
| `~/.local/state/dots/theme/current` | `themectl set` | `themectl current`, `next`, `prev` |
| `~/.local/state/dots/theme/wallpaper` | `dots-set-wallpaper` | `dots-current-wallpaper`, pickers |
| `~/.local/state/dots/shell/current/` | `themectl` (`shell_compat`) | Quickshell Rise and the lock screen: `theme/colors.sh`, `background`, `theme.name` |
| `~/.local/state/dots/shell/settings.json` | Quickshell Rise (control panel toggles) | Rise on start — one key per setting, validated per key; migrated once from the old `~/.cache/quickshell_*` files |
| `~/.local/state/dots/indicators/` | hypridle, gammastep units | bar widgets (`stay-awake`, `nightlight`) |
| `~/.local/state/dots/voxtype/` | `voxtype` | bar widget (`phase`), model choice |
| `/var/lib/dots-theme/sddm.json` | `themectl` (`sddm_compat`) | the SDDM greeter, before login |

## `lib/` helpers

| File | Is | Used by |
|---|---|---|
| `mk.nix` | output builders | `flake.nix` |
| `overlays.nix` | `[ zig-overlay, obsidian-extensions ]` | NixOS host, `mk.home` |
| `hardening.nix` | plain attrset of systemd sandbox options | `vpn.nix`, `media.nix`, `media-extras.nix`, `hello-page.nix` — each merges its own exceptions over it |
| `vpn-ready.nix` | function `pkgs: script` — waits (up to 80 s, never fails) until DNS works inside the VPN namespace | `vpn.nix` |
| `disko.nix` | function `{ device, impermanence ? false }: module` — ESP + LUKS2 + btrfs | `hosts/vm`, new hosts ([Getting started](install.md#a-new-machine-disko--dots-install)) |

The functions here are not modules: keep them out of `modules/` (everything there is imported) and out of `imports` unless called first, or NixOS calls them with module arguments.
