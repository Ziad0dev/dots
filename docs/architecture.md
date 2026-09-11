# Architecture

## Layout

```
flake.nix       inputs, username, every output
lib/            mk.nix (output builders), overlays, shared systemd hardening, nvidia fix
hosts/          nixos/ (the desktop), darwin/, claude-vm/
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
| `nixosConfigurations.claude-vm` | `mk.nixos` with `home = false` | `hosts/claude-vm/` — qemu guest, user `dev` |
| `darwinConfigurations.mac` | `mk.darwin` | `hosts/darwin/` + home-manager (profile `desktop`, which on darwin selects the darwin profile) |
| `homeConfigurations."ziad0dev@mac"` | `mk.home` | aarch64-darwin, desktop |
| `homeConfigurations."ziad0dev@linux"` | `mk.home` | x86_64-linux, minimal |
| `homeConfigurations."ziad0dev@linux-desktop"` | `mk.home` | x86_64-linux, desktop |
| `homeConfigurations."ziad0dev@aarch64-linux"` | `mk.home` | aarch64-linux, minimal |
| `templates.*` | — | nine project templates, see [Development](development.md#project-templates) |
| `formatter.<system>` | — | `nixfmt-tree` for `nix fmt` |

Supported systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin` (nixpkgs 26.11 dropped `x86_64-darwin`).

## `lib/mk.nix`

Three builders, all passing the same `specialArgs` — `inputs`, `username`, `hostname`, `system`, `profile` — so every module can take them as arguments.

```nix
mk.nixos  { hostname, username, system ? "x86_64-linux", profile ? "desktop", modules ? [ ], homeModule ? ../home/home.nix, home ? true }
mk.darwin { hostname, username, system ? "aarch64-darwin", profile ? "desktop", modules ? [ ], homeModule ? ../home/home.nix }
mk.home   { username, system, profile ? "minimal", repoPath ? null, homeDirectory ? null, modules ? [ ] }
```

When home-manager rides on a system (`mk.nixos`, `mk.darwin`) it runs with `useGlobalPkgs`, `useUserPackages` and `backupFileExtension = "backup"`. There is no separate `home-manager switch` on the desktop — one `nh os switch` activates both, and one rollback reverts both.

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
| `nixcord` | Discord + Vencord + Krisp | `nixpkgs-nixcord` input also pinned to ours |
| `spicetify-nix` | Spotify theming | |
| `obsidian-extensions` | overlay: `obsidianPlugins`, `obsidianThemes` | |
| `zig-overlay`, `zls` | Zig 0.16.0 + matching zls | overlay provides `pkgs.zigpkgs` |
| `nix-index-database` | prebuilt nix-index DB, powers `,` | |
| `vpn-confinement` | `vpnNamespaces` NixOS module | |
| `dvr-patched` | patched DaVinci Resolve | |
| `vm-curator` | VM management tool | |

Every input that has a nixpkgs input follows ours; duplicates are what drag in a second or third nixpkgs.

## Home-manager composition

`home/home.nix` is only a dispatcher:

| Profile file | Loaded when | Carries |
|---|---|---|
| `profiles/base.nix` | always | `dots.repoPath` / `dots.theme` options, shell (fish + abbrevs), git, ssh, direnv + nix-direnv, CLI tools, nvim/ghostty/tmux/broot/ranger/btop links, dev-home, fastfetch, yazi, git-hooks, infosec + maths `core` sets |
| `profiles/linux-desktop.nix` | Linux and `profile == "desktop"` | Hyprland session target, Quickshell, theming, GTK/Qt/cursor, desktop apps, MPD, udiskie, hypridle, nixcord, emacs, Obsidian, Spicetify, VS Code, … |
| `profiles/darwin.nix` | macOS | GNU userland, `open` abbrevs, macOS defaults |

Everything under `home/` that isn't a profile is an app module imported by one of these.

## Live config: the `link` pattern

```nix
link = sub: config.lib.file.mkOutOfStoreSymlink "${config.dots.repoPath}/config/${sub}";
home.file.".config/hypr".source = link "hypr";
```

`mkOutOfStoreSymlink` points `~/.config/hypr` at the working tree, not a store copy, so edits land without a rebuild. The cost is that home-manager no longer knows the contents — so **each config path has exactly one owner**: either a `link` or an HM module, never both.

| Linked from `config/` | By |
|---|---|
| nvim, ghostty, tmux, broot, ranger, btop.conf | `profiles/base.nix` |
| hypr, dunst, quickshell, flameshot, gammastep, rmpc, mpv, Kvantum themes, zen → `~/.config/zen-theme`, share-picker | `profiles/linux-desktop.nix` |
| yazi (`yazi.toml`, `keymap.toml`, `init.lua` — per file) | `home/yazi.nix` |
| emacs `init.el` | `home/emacs.nix` |

Files linked to `~/.local/state/dots/theme/*` instead of `config/` (btop theme, yazi theme, swayosd css) are themectl output — see [Theming](theming.md).

## `dots.repoPath`

Declared twice, in two namespaces, both defaulting to `~/dots`:

- NixOS: `modules/quality.nix` — used by `programs.nh.flake`.
- home-manager: `home/profiles/base.nix` — used by `link`, the `flakeup` abbrev, fastfetch art, git hooks, yazi, emacs, AI-usage refresh.

## Runtime state

| Path | Written by | Read by |
|---|---|---|
| `~/.local/state/dots/theme/` | `themectl` | every themed app — see [Theming](theming.md#templates) |
| `~/.local/state/dots/theme/current` | `themectl set` | `themectl current`, `next`, `prev` |
| `~/.local/state/dots/theme/wallpaper` | `dots-set-wallpaper` | `dots-current-wallpaper`, pickers |
| `~/.local/state/dots/shell/current/` | `themectl` (`shell_compat`) | Quickshell Rise and the lock screen: `theme/colors.sh`, `background`, `theme.name` |
| `~/.local/state/dots/indicators/` | hypridle, gammastep units | bar widgets (`stay-awake`, `nightlight`) |
| `~/.local/state/dots/voxtype/` | `voxtype` | bar widget (`phase`), model choice |
| `/var/lib/dots-theme/sddm.json` | `themectl` (`sddm_compat`) | the SDDM greeter, before login |

## `lib/` helpers

| File | Is | Used by |
|---|---|---|
| `mk.nix` | output builders | `flake.nix` |
| `overlays.nix` | `[ zig-overlay, obsidian-extensions ]` | NixOS host, `mk.home` |
| `hardening.nix` | plain attrset of systemd sandbox options | `vpn.nix`, `media.nix`, `media-extras.nix`, `hello-page.nix` — each merges its own exceptions over it |
| `nvidia-zstd-refs.nix` | function `{ pkgs }: drv: drv'` | `hosts/nixos/configuration.nix` only |

`nvidia-zstd-refs.nix` must stay out of `modules/` and out of any `imports` list: it's a function, not a module, and NixOS would call it with module arguments. See [Troubleshooting](troubleshooting.md#nvidia-open-reference-check-failure).
