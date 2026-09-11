# Workflow

## The loop

```fish
cd ~/dots
# edit
git add -A
update                      # nh os switch
```

`git add -A` is not optional. The flake is evaluated from git, so an untracked file is invisible and you end up debugging a version of the repo that doesn't exist.

## What needs a rebuild

| You edited | Takes effect |
|---|---|
| Anything under `config/` that is symlinked (hypr, nvim, ghostty, tmux, quickshell, dunst, yazi, mpv, …) | Immediately — `hyprctl reload`, restart the app, or nothing at all |
| `config/quickshell/rise/**` | Quickshell reloads QML on save; `dots-shell restart` if it wedges. The bar's helper scripts in `rise/scripts/` run straight from the repo |
| `config/themes/*/colors.sh`, `config/themes/_templates/*.in` | `themectl reload` — no rebuild. Exception: the theme baked into SDDM / Spotify, see below |
| `config/sddm/**`, or the theme named by `dots.sddm.theme` / `dots.theme` | Rebuild — the greeter and Spicetify theme are generated at build time |
| `scripts/*.sh` | Rebuild. `themectl`, `dots-compat` (all `dots-*` shims), `voxtype` and the wallpaper helpers are packaged with `writeShellApplication`; the thing on PATH is a store copy. `claude-vm.sh` and the git hook run from the repo |
| Any `.nix` file | Rebuild |

A switch that prints `PATHS +0, -0` after a `config/`-only change is expected — no store path moved.

## Rebuilding

| Command | Use |
|---|---|
| `update` | `nh os switch` — build, diff, activate |
| `nh os test` | Activate without a boot entry; reverts on reboot |
| `nh os boot` | Next boot only — kernel and driver bumps |
| `nh os build` | Build and show the diff, change nothing |
| `nh os switch -n` | Dry run |
| `nh os rollback` | Back one generation |
| `nh os info` | List generations |

The boot menu keeps three generations (`configurationLimit = 3`, sized for the 200 MiB ESP). Hyprland is the only session, so the boot menu is the rescue path.

## Updating

| Command | Does |
|---|---|
| `upall` | `nh os switch -u` — bump every input, then switch |
| `nh os switch -U chaotic` | Bump nixpkgs and the CachyOS bits together |
| `flakeup` | `nix flake update --flake ~/dots`, no switch |

`nixpkgs` follows `chaotic/nixpkgs`. `nix flake update nixpkgs` is therefore always a no-op — nixpkgs moves when chaotic moves.

The bar's update indicator comes from two shims: `dots-updates` compares the locked chaotic rev against chaotic-nyx's `HEAD` (cached for an hour), and `dots-update-available` flags a `flake.lock` older than seven days. Clicking it runs `dots-update`, which opens a floating terminal with `nh os switch` — it rebuilds, it does not bump inputs.

## Commit checks

`home/git-hooks.nix` points `core.hooksPath` at `scripts/git-hooks/` on every home-manager activation. The pre-commit hook runs:

1. Every `./….nix` path referenced from `flake.nix` exists **and is tracked**.
2. No legacy `hyprctl dispatch …` strings under `config/` — they exit 0 and silently do nothing under the Lua config.
3. `nix eval` of every output that produces an activation package: both NixOS hosts, all four home configurations, and the darwin system.
4. `statix check .` (config in `statix.toml`: `repeated_keys` and `empty_pattern` disabled, `templates/` ignored) and `deadnix --fail -L --exclude templates .`.

`git commit --no-verify` skips it when you're committing a known-broken WIP.

`nix fmt` runs nixfmt-tree over the repo.

## Cleanup that runs on its own

| What | Where |
|---|---|
| Store GC: keep 3 generations and anything newer than 4 days | `programs.nh.clean` in `modules/dev.nix` |
| Store dedup | `nix.optimise.automatic` |
| journald capped at 512 MiB / 1 month | `modules/performance.nix` |
| Coredumps capped at 1 GiB | `modules/cleanup.nix` |
| Thumbnails 60 d, Trash / mpv / nvidia / cpptools caches 30 d | `home/cleanup.nix` (user tmpfiles) |
| Unused flatpak runtimes, weekly | `home/cleanup.nix` |
| Quickshell picker thumbnails unused for 30 d, weekly | `home/quickshell-rise.nix` |
| Spotify cache pinned to 4 GiB | `home/cleanup.nix` activation |

`nix.gc.automatic` is deliberately absent on NixOS — two collectors racing is worse than one, and nh's understands boot and home-manager generations. (The Mac has no nh, so it uses `nix.gc`.)

## Declarative things that aren't Nix packages

| Thing | Declared in | Applied by |
|---|---|---|
| Flatpaks and remotes | `modules/flatpak.nix` | `flatpak-managed` user unit at login — installs what's listed, **uninstalls what isn't** |
| Obsidian vault, plugins, hotkeys | `home/obsidian.nix` | home-manager |
| VS Code `settings.json` | `config/themes/_templates/vscode-settings.json.in` | `themectl` links the rendered file over `~/.config/Code/User/settings.json` |
| Zen `userChrome.css` / `userContent.css` | `config/zen/` | `config/zen/zen-theme-link.sh`, run by hand once per profile |
| Git hooks | `scripts/git-hooks/` | `home/git-hooks.nix` activation |

## Docs, wiki and README assets

| Thing | Source | Regenerate |
|---|---|---|
| Wiki | `docs/*.md` | automatic — `.github/workflows/wiki.yml` runs on pushes touching `docs/`, and on demand from the Actions tab |
| Banner and theme gallery | `config/themes/*/colors.sh` | `python3 .github/scripts/gen-assets.py` after adding or editing a theme, then commit `.github/assets/*.svg` |
| Wiki preview, locally | `docs/*.md` | `python3 .github/scripts/wiki.py docs /tmp/wiki --repo Ziad0dev/dots` |

A new file in `docs/` becomes a wiki page named after its `# Title`; add it to `PAGES` and `SIDEBAR` in `.github/scripts/wiki.py` to control the name and where it sits in the sidebar. Relative links between docs become wiki links, links elsewhere in the repo become GitHub URLs.

