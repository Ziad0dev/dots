# dots

NixOS flake for `nixos` (x86_64-linux): Hyprland on a Lua config, a vendored
Quickshell bar, and the module set behind them.

## Layout

| Path | What lives there |
| --- | --- |
| `flake.nix` | Two outputs: `nixos` (the desktop) and `claude-vm`. `system`, `hostname` and `username` are defined here and passed to every module via `specialArgs`. |
| `hosts/` | Per-host `configuration.nix` and `hardware-configuration.nix`. |
| `modules/` | System-level concerns, one file each: `recording.nix`, `audio.nix`, `gaming.nix`, `virt.nix`, `llm.nix`, and so on. |
| `home/` | Home-manager. `home.nix` is the root; `quickshell-rise.nix` builds the bar's shim layer and pins its PATH. |
| `config/` | Live application config. Symlinked into `~/.config` out of the store, so edits here take effect without a rebuild. |
| `scripts/` | Shell entry points. `dots-compat.sh` is packaged; the rest are hand-run. |
| `templates/`, `zen/` | Theme templates and Zen browser assets. |

## Rebuilding

```sh
git add -A          # untracked files are invisible to the flake
nh os switch
```

The `git add` is not optional. A file the flake needs but git does not know
about will not be copied into the store, and the failure is silent.

`PATHS +0, -0` in the output is normal when only `config/` changed, because
those paths are symlinks out of the store rather than store contents.

## Hyprland is Lua, not hyprlang

`config/hypr/hyprland.lua` uses the `hl.*` API introduced in Hyprland 0.55.
The classic syntax does not work and mostly fails silently:

- Dispatchers are `hl.dsp.*`. `hyprctl dispatch exec ...` is parsed as Lua and
  errors; use `hl.dsp.exec_cmd("...")`, and `hl.dsp.focus({ workspace = N })`
  rather than `workspace N`.
- Window rules are `hl.window_rule({ match = { class = "..." }, float = true })`.
  Props go inside `match`, effects outside it. The `[float; size 900 600]`
  prefix form is a syntax error here.
- `exec-once` is `hl.on("hyprland.start", ...)`.

## The bar

`config/quickshell/rise/` is HANCORE-linux/quickshell-dots vendored verbatim
(MIT, LICENSE retained) and then rewritten in place. `activeConfig = "rise"`,
and V2 is the running variant. Both variant trees carry their own copies of the
shared JS, so a change to the top-level copy alone will not take.

Quickshell hot-reloads QML on save. Prefer that over restarting the unit:
`systemctl --user restart quickshell` drops the D-Bus names the bar owns and
disrupts anything that depends on them.

### Re-vendoring

Two scripts mutate tracked files in place. Neither is called from any `.nix` —
the committed output is what the flake consumes. Order matters:

```sh
# 1. re-vendor upstream into config/quickshell/rise/
./scripts/denix-rise.sh     # de-Omarchy rewrite, mounts AppLauncher
./scripts/dots-finalize.sh  # widget buttons, logo sizing
git add -A && nh os switch
```

Both need `python3` and `imagemagick` on PATH.

### The shim layer

`scripts/dots-compat.sh` is a single script symlinked to roughly two dozen
`dots-*` names, with `$0` selecting the branch. It is read into the store by
`builtins.readFile`, so unlike QML it **does not** hot-reload — editing it
requires a rebuild.

Some shims are queries whose stdout is consumed by the shell (`dots-hw-display`
returns a backlight device name); others are actions. Confusing the two is a
silent failure.

## Screen recording

Two independent GSR instances, and neither is found by matching process names:

- **Replay buffer** — `gsr-replay.service`, declared in `modules/recording.nix`,
  holding 300 seconds to `/data/replays`. Save a clip with
  `systemctl --user reload gsr-replay`, which the unit maps to `SIGUSR1`.
  It is `wantedBy` `graphical-session.target`, and `Restart = "on-failure"`
  does not cover a clean exit, so a manual kill stays dead until you start it.
- **On-demand recording** — the bar starts a transient unit, `dots-gsr`, with
  `KillSignal=SIGINT` so GSR finalises the mp4 rather than being killed
  mid-write. Stop is `systemctl --user stop dots-gsr`.

Bar widget: left-click toggles recording, right-click saves a replay clip.

## Gotchas worth knowing before debugging

- **Nix wraps binaries.** `comm` becomes `.quickshell-wra` or `.waybar-wrapped`
  and is truncated at 15 characters, so `pgrep -x`, `pkill -x` and `ps -C` all
  miss. Match on the full command line, or better, use a named systemd unit and
  skip process matching entirely.
- **Processes inherit the launcher's cgroup.** Anything spawned from the bar
  lands in `quickshell.service` unless wrapped in `systemd-run --user --scope`,
  and stopping that unit would take them with it. `KillMode = "process"` is the
  backstop. `systemd-cgls --user-unit <unit>` shows the truth.
- **`writeShellApplication` implies `set -euo pipefail`.** A bare `x=$(fn)`
  where `fn` returns non-zero aborts the whole script; write `x=$(fn || true)`.
- **`ln -sfn X dir`** on a real directory creates the link *inside* it rather
  than replacing it.
- **grep-guarded `sed` inserts** can never upgrade what they already inserted.
  Rewrite unconditionally.
