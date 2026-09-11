# Scripts & commands

Most commands here are packaged from `scripts/` with `writeShellApplication` (strict mode, shellcheck at build time). **Editing the `.sh` does nothing until you rebuild** — the copy on PATH is in the store. The exceptions, which run straight from the repo, are marked.

## themectl

Full reference in [Theming](theming.md).

```
themectl set <name> | current | list | next | prev | reload
themectl bg [set <path> | next | prev]
```

`DOTS_DIR` overrides where it looks for the repo (default `~/dots`).

## `dots-*` shims

Every `dots-*` name below is a symlink to one script, `scripts/dots-compat.sh`, which dispatches on `$0`. They exist so the vendored Quickshell bar has a stable command vocabulary. An unknown name exits 127.

### State and toggles

| Command | Does |
|---|---|
| `dots-theme-set <name>` | `themectl set <name>` |
| `dots-theme-bg-set <path>` | `themectl bg set <path>` |
| `dots-toggle-idle` | Stop/start the `hypridle` user unit; prints `on`/`off` |
| `dots-toggle-notification-silencing` | Pause/resume dunst; writes `~/.local/state/dots/notifications.json` |
| `dots-audio-input-mute` | Toggle mute on the default PipeWire source |
| `dots-llm [status\|next\|off]` | Which LLM unit is running / cycle to the next / stop all (order: `llama-cpp llama-sec llama-agent llama-gemma llama-coder llama-fim ollama`) |
| `dots-shell lock` | `quickshell -c lock` |
| `dots-shell restart` | Restart the bar |
| `dots-shell notifications status` / `idle status` | JSON / on-off for the bar |

### Status (print, never fail)

| Command | Prints |
|---|---|
| `dots-updates` | `1` if the locked chaotic rev differs from chaotic-nyx `HEAD`, else `0` (cached 1 h in `~/.cache/dots-updates`) |
| `dots-update-available` | `1` if `flake.lock` is older than 7 days, else nothing |
| `dots-mounts` | Space-separated names of unhealthy mounts among `/data /mnt/media /mnt/backup /mnt/newvolume`; empty means all fine |
| `dots-qbt` | `<downloading> <dl B/s> <up B/s>` from the qBittorrent API, or `off` |
| `dots-weather`, `dots-weather-status` | One-line wttr.in summary |
| `dots-brightness-display` | Backlight percent (100 on a desktop with no backlight) |
| `dots-hw-display` | Backlight device name, if any |
| `dots-voxtype-model` | Current whisper model |
| `dots-screenrecord-filename` | Next `~/Videos/recording-<timestamp>.mp4` path |

### Launchers

These open a floating terminal (`$DOTS_TERMINAL`, default ghostty) with window class `com.dots.float`, as a transient systemd scope so it outlives the bar.

| Command | Opens |
|---|---|
| `dots-update` | `nh os switch` in `~/dots`, waits for Enter |
| `dots-launch-wifi` | impala |
| `dots-launch-bluetooth` | bluetui |
| `dots-launch-audio` | wiremix |
| `dots-launch-or-focus-tui <cmd>` | `<cmd>` (always launches; doesn't focus an existing one) |
| `dots-launch-floating-terminal-with-presentation <cmd>` | `<cmd>` |
| `dots-tz-select` | fzf over timezones → `sudo timedatectl set-timezone` |
| `dots-voxtype-config` | fzf over whisper models → `voxtype set-model` |

### Capture and OSD

| Command | Does |
|---|---|
| `dots-capture-screenrecording` | Start recording DP-1 (HEVC, desktop + EasyEffects audio) to `~/Videos` as transient unit `dots-gsr`; `DOTS_GSR_ARGS` replaces the capture flags |
| `dots-capture-screenrecording --stop` | Stop `dots-gsr` (SIGINT, so the mp4 is finalised) |
| `dots-capture-screenrecording --save-replay` | Dump the replay buffer if `gsr-replay` is armed |
| `dots-swayosd-client`, `dots-swayosd-brightness` | Pass through to `swayosd-client` (no-op if missing) |

### Adding a shim

1. Add a `case` branch to `scripts/dots-compat.sh`.
2. Add the name to `shimNames` in `home/quickshell-rise.nix` — without this the symlink isn't created.
3. `git add -A && update`.

## Other packaged commands

| Command | From | Usage |
|---|---|---|
| `voxtype` | `scripts/voxtype.sh` | `toggle` · `start` · `stop` · `status [json]` · `model` · `models` · `set-model <path>`. Models: `ggml-*.bin` in `$VOXTYPE_MODEL_DIR` (default `/data/models/whisper`) |
| `dots-nightlight` | `home/quickshell-rise.nix` | `on` · `off` · `toggle` · `status` |
| `dots-vpn` | `home/quickshell-rise.nix` | `on` · `off` · `toggle` · `status` — Mullvad on the host |
| `dots-set-wallpaper <file>` | `scripts/dots-set-wallpaper.sh` | awww with a random transition; records the choice |
| `dots-current-wallpaper` | `scripts/dots-current-wallpaper.sh` | Print the current wallpaper path |
| `dots-thumb-prune` | `home/quickshell-rise.nix` | Prune picker thumbnails (weekly timer) |
| `nvim-synctex <line> <file>` | `home/documents.nix` | Zathura → Neovim inverse search |
| `fhs` | `modules/foreign.nix` | FHS bash — see [Development](development.md#foreign-binaries) |

## Run from the repo

| Script | Usage |
|---|---|
| `scripts/claude-vm.sh` | `build` · `run` (default, ephemeral) · `persist` · `ssh [args]` · `reset`. `FLAKE` overrides the repo path. See [Development](development.md#agent-vm) |
| `scripts/git-hooks/pre-commit` | Run by git; see [Workflow](workflow.md#commit-checks) |
| `config/zen/zen-theme-link.sh` | Link `config/zen/*.css` into every Zen profile's `chrome/`. `SRC` / `ROOT` env override source and profile root. Launch Zen once first so a profile exists |
| `config/quickshell/rise/scripts/*` | Bar helpers: `claude-usage`, `codex-usage`, `opencode-usage`, `openrouter`, `qs-barctl`, `qs-kb-*`, `qs-proj` |

## Fish

| Abbrev | Expands to |
|---|---|
| `update` | `nh os switch` (desktop) · `nh darwin switch` (mac) · `nh home switch` (minimal) |
| `upall` | the above + `-u` |
| `flakeup` | `nix flake update --flake <repoPath>` |
| `g` `gst` `gco` `gp` `gl` | git, status, checkout, push, pull |
| `tw` `tc` `tf` | `typst watch`, `typst compile`, `typstyle -i` |
| `lmk` `lmc` | `latexmk -pdf -pvc -interaction=nonstopmode`, `latexmk -C` |
| `o` `oo` `brewup` | macOS only: `open`, `open .`, brew update + upgrade |

| Alias / function | |
|---|---|
| `ll`, `la`, `edit` | `ls -l`, `ls -la`, `sudo -e` |
| `dnx <files…>` | Transcode to DNxHR HQ `.mov` for DaVinci Resolve |
| `y` | yazi, `cd`s to where you quit |
| `gpu-check` | running `llama-*` units + `ollama ps` |
| `gpu-free` | stop every `llama-*` unit |
| `yolo` | agent VM only: `claude --dangerously-skip-permissions` |

Fish starts in vi mode and sources the themed fzf colours.

## Units worth knowing

| Unit | Scope | |
|---|---|---|
| `quickshell` | user | the bar; bound to `hyprland-session.target` |
| `hypridle` | user | idle → lock → DPMS |
| `swayosd`, `dotsDunstTheme`, `cliphist` | user | session plumbing |
| `dots-gammastep` | user | night light (on demand) |
| `gsr-replay` | user | replay buffer (on demand) |
| `dots-gsr` | user, transient | manual screen recording |
| `flatpak-managed` | user | flatpak reconciler, at login |
| `mpd`, `mpdris2` | user | music |
| `dots-ai-usage.timer`, `dots-thumb-prune.timer`, `flatpak-prune.timer` | user | housekeeping |
| `llama-cpp`, `llama-sec`, `llama-agent`, `llama-gemma`, `llama-coder`, `llama-fim`, `ollama` | system | LLMs, startable without sudo |
| `wg`, `wg-dns`, `qbittorrent`, `prowlarr`, `flaresolverr` | system | VPN namespace |
| `jellyfin`, `radarr`, `sonarr`, `audiobookshelf`, `calibre-web` | system | media |
| `restic-backups-home` | system | backup (daily timer) |
| `hello-page`, `hello-page-serve` | system | tailnet site |
| `cpu-epp`, `cpu-power-limit` | system | CPU tuning oneshots |
