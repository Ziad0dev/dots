# dots

NixOS + Hyprland. Quickshell bar, Ghostty, Neovim, Zen.

![screenshot](.github/screenshot.png)

## Install

```sh
git clone https://github.com/Ziad0dev/dots ~/dots
cd ~/dots
nixos-rebuild switch --flake .#nixos
```

Edit `flake.nix` first — `hostname` and `username` are set at the top — and
replace `hosts/nixos/hardware-configuration.nix` with your own.

## Stack

| | |
| --- | --- |
| WM | Hyprland (Lua config) |
| Bar | Quickshell |
| Terminal | Ghostty |
| Editor | Neovim, Emacs |
| Music | mpd + rmpc |
| Browser | Zen |
| Shell | Fish |
| Theme | 20 themes, switch with `themectl set <name>` |

## Rebuilding

```sh
git add -A && nh os switch
```

`git add` is required — untracked files are invisible to the flake.

## Layout

```
flake.nix     hostname, username, host outputs
hosts/        per-host hardware + configuration
modules/      system config, one file per concern
home/         home-manager
lib/          shared helpers
config/       app config, symlinked live into ~/.config
flakes/       curated tool sets, usable standalone
scripts/      helpers
```

## Tool flakes

`flakes/infosec` and `flakes/maths` group packages into named sets. The
home-manager modules are wired into `home/home.nix`; everything else is
meant to be ephemeral:

```sh
nix develop ~/dots/flakes/infosec#web -c fish
nix develop ~/dots/flakes/maths#mathlib -c fish
```

```sh
nix develop 'github:Ziad0dev/dots?dir=flakes/infosec#binary'
```

`nix run ./flakes/infosec#audit` lists names that no longer resolve in
nixpkgs. Sets live in `names.nix`, one string per attribute path;
anything that stops resolving is dropped rather than breaking eval.
