# dots — documentation

One flake that builds a NixOS desktop, a nix-darwin Mac, standalone
home-manager profiles for any machine with Nix, a disposable agent VM, and a
set of project templates.

## Contents

| Doc | Read it when |
|---|---|
| [Getting started](install.md) | Putting the repo on a new machine, or forking it |
| [Workflow](workflow.md) | Day-to-day: editing, rebuilding, updating, rolling back |
| [Architecture](architecture.md) | You want to know how the flake, hosts, modules and home profiles fit together |
| [System modules](modules.md) | Looking up what a file in `modules/` owns |
| [Services](services.md) | Media stack, VPN namespace, local LLMs, backups, mounts, ports |
| [Desktop](desktop.md) | Hyprland, keybinds, the Quickshell bar, lock/idle, recording, dictation |
| [Theming](theming.md) | `themectl`, palette format, templates, adding a theme |
| [Development](development.md) | Languages, editors, templates, tool flakes, the agent VM, foreign binaries |
| [Scripts & commands](scripts.md) | Every `dots-*` command, `themectl`, `voxtype`, fish abbrevs |
| [Troubleshooting](troubleshooting.md) | Something broke — known failure modes and rough edges |
| [Nix cheatsheet](nix-cheatsheet.md) | Quick command reference, mostly for starting projects |

Neovim has its own doc: [`config/nvim/README.md`](../config/nvim/README.md).

These files are the source of truth. The [wiki](https://github.com/Ziad0dev/dots/wiki) is generated from them on every push to `main` — edit here, not there.

## The shape of it

```
flake.nix ──┬─ nixosConfigurations.nixos ── hosts/nixos + modules/* + home-manager(desktop)
            ├─ nixosConfigurations.claude-vm ── hosts/claude-vm (qemu, no home-manager)
            ├─ darwinConfigurations.mac ── hosts/darwin + home-manager(desktop → darwin profile)
            ├─ homeConfigurations.<user>@{linux,linux-desktop,aarch64-linux,mac}
            ├─ templates.{zig,rust,haskell,c,python,lisp,beam,typst,latex}
            └─ formatter (nixfmt-tree)

home/home.nix ── profiles/base.nix           always
             ├── profiles/linux-desktop.nix  Linux + profile "desktop"
             └── profiles/darwin.nix         macOS

config/  ── symlinked live into ~/.config (edit, no rebuild)
config/themes/ + themectl ── rendered into ~/.local/state/dots/theme/
```

## Three rules

1. **`git add` before nix sees it.** The flake is a git checkout; untracked files do not exist to Nix.
2. **One owner per path.** A config directory is either a live symlink into `config/` or managed by a home-manager module, never both.
3. **Edits under `config/` are live; edits to `.nix` and `scripts/` need a rebuild.** Scripts are packaged with `writeShellApplication`, so the installed copy is a store path.
