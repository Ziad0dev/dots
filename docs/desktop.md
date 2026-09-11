# Desktop

Hyprland with a Lua config, a Quickshell bar/launcher/control panel ("Rise"), a Quickshell lock screen, an SDDM greeter, and themectl colouring all of it.

## How a session starts

```
SDDM (kwin greeter, dots theme)
  └─ Hyprland
       └─ hyprland.start handler (config/hypr/hyprland.lua)
            ├─ import WAYLAND_DISPLAY, HYPRLAND_INSTANCE_SIGNATURE, … into dbus + systemd --user
            ├─ systemctl --user start hyprland-session.target ── BindsTo graphical-session.target
            │     ├─ quickshell (rise)         ├─ swayosd-server
            │     ├─ dotsDunstTheme            └─ hypridle, cliphist, udiskie, mpdris2, …
            ├─ hyprpolkitagent (user unit — the binary is in libexec, not on PATH)
            ├─ dunst, awww-daemon
            └─ apps: zen, sideterm, sysmon, discord, spotify, easyeffects
```

`hyprland-session.target` is defined in `home/profiles/linux-desktop.nix`. Without it `graphical-session.target` never activates and nothing that hangs off it starts. On exit, the `hyprland.shutdown` handler stops the target.

## Monitors and workspaces

Defined at the top of `config/hypr/hyprland.lua` in `monitorProfiles`:

| Output | Mode | Position | Notes |
|---|---|---|---|
| `DP-1` | 2560×1440 @ 239.97 | `0x0` | ASUS XG27AQDMG OLED; 10-bit, `cm = "hdr"`, panel luminance values |
| `HDMI-A-1` | 1920×1080 @ 60 | right of DP-1 | portrait (`transform = 3`) |
| anything else | preferred | auto | fallback rule |

A `monitor.added` handler re-applies the matching profile when a display reconnects.

Workspaces 1–8 and 10 live on DP-1; 9 is pinned to HDMI-A-1 and persistent.

HDR: the profile runs DP-1 in 10-bit HDR permanently. That costs compositor CPU on the desktop; if Hyprland starts pegging a core, drop `bitdepth` / `cm` / luminance from the profile and pin `cm = "srgb"` — see [Troubleshooting](troubleshooting.md#hyprland-uses-a-lot-of-cpu).

## Input

- Layouts `us, se, ara, fr, de` — **Right Ctrl** cycles. **Caps Lock** is Compose.
- Repeat 40/s after 250 ms, flat acceleration, numlock on.
- Focus follows mouse; the cursor warps on workspace change and hides while typing.
- Hardware cursors on with `use_cpu_buffer` (the NVIDIA-safe combination).

## Keybinds

`SUPER` is the modifier. `hjkl` and arrows are interchangeable everywhere they appear.

### Windows

| Keys | Action |
|---|---|
| `SUPER + Return` | Ghostty |
| `SUPER + SHIFT + Return` | Ghostty attached to tmux session `main` |
| `SUPER + SHIFT + Q` | Close window |
| `SUPER + h j k l` | Focus |
| `SUPER + SHIFT + h j k l` | Move window |
| `SUPER + F` | Fullscreen |
| `SUPER + SHIFT + Space` | Toggle floating |
| `SUPER + Space` | Focus previous window |
| `SUPER + R` | Resize mode — `hjkl` resize, `Esc`/`Return` leaves |
| `SUPER + LMB` / `RMB` drag | Move / resize |
| `SUPER + G` | Toggle group |
| `SUPER + ALT + L` / `H` | Next / previous in group |
| `SUPER + ALT + SHIFT + h j k l` | Move into (or create) group in that direction |
| `SUPER + SHIFT + G` | Move out of group |

### Workspaces

| Keys | Action |
|---|---|
| `SUPER + 1…0` | Go to workspace 1–10 |
| `SUPER + SHIFT + 1…0` | Send window to workspace |
| `SUPER + Tab` / `SUPER + SHIFT + Tab` | Next / previous occupied workspace |
| `SUPER + scroll` | Next / previous occupied workspace |
| `SUPER + minus` | Toggle scratchpad |
| `SUPER + SHIFT + minus` | Send window to scratchpad |

### Launch

| Keys | Action |
|---|---|
| `SUPER + D` | App launcher (Rise) |
| `SUPER + A` | Overview |
| `SUPER + B` / `O` / `C` | Focus-or-launch Zen / Obsidian / Discord |
| `SUPER + SHIFT + O` | OpenRouter panel |
| `SUPER + period` | Emoji picker (bemoji) |
| `SUPER + SHIFT + V` | Clipboard history (cliphist → fuzzel) |
| `SUPER + V` | Dictation — start / stop (voxtype) |
| `SUPER + N` | Night light toggle |

### Look

| Keys | Action |
|---|---|
| `SUPER + CTRL + SHIFT + Space` | Theme picker |
| `SUPER + SHIFT + T` | Next theme |
| `SUPER + E` | Wallpaper picker |
| `SUPER + CTRL + E` | Next wallpaper |
| `SUPER + CTRL + Z` / `SUPER + CTRL + ALT + Z` | Zoom in / reset zoom |

### Capture

| Keys | Action |
|---|---|
| `Print` | Region → satty annotator → `~/Pictures/screenshot-<timestamp>.png` |
| `SUPER + Print` | Full screen → clipboard |
| `SUPER + S` | Flameshot |
| `SUPER + ALT + R` | Arm / disarm the replay buffer |
| `SUPER + SHIFT + R` | Save the last 5 minutes |

### Session

| Keys | Action |
|---|---|
| `SUPER + Escape`, `SUPER + CTRL + L` | Lock |
| `SUPER + CTRL + R` | Reload Hyprland |
| `SUPER + SHIFT + E` | Exit Hyprland |
| Volume keys | ±5 % / mute (work while locked) |

## Window rules

| Match (class) | Rule |
|---|---|
| `com.dots.float{,.sm,.md,.lg}` | Floating, centred, 1200×750 / 900×600 / 1100×700 / 1200×750. Every `dots-*` popup terminal uses these |
| `zen-beta`, `dev.dots.sideterm` | Workspace 1 |
| `org.qbittorrent.qBittorrent` | Workspace 3 (silent) |
| `dev.dots.sysmon` | Workspace 9 (silent, no focus) — tmux session `sysmon` with btop over nvtop |
| `discord`, `spotify` | Workspace 10 (silent), 0.98 opacity |
| `org.pwmt.zathura` | Opaque, no blur, inhibits idle when fullscreen |
| `flameshot` | Floating, pinned |

Ghostty windows swallow what they launch (`enable_swallow`).

## Quickshell Rise

The bar, launcher, control panel, pickers and notifications UI. Vendored in `config/quickshell/rise/`, run by `programs.quickshell` (`home/quickshell-rise.nix`) as the `quickshell` user unit, bound to `hyprland-session.target`.

- `shell.qml` is the entry; `modules/` holds bar widgets, `panels/` the pop-outs, `core/` the IPC router and state, `scripts/` the helpers it shells out to (AI-quota fetchers, keybind scraper, bar control).
- It reads colours from `~/.local/state/dots/shell/current/theme/colors.sh` — a symlink themectl maintains to the active palette.
- The unit's PATH is pinned: the `dots-*` shims, wallpaper helpers and a fixed tool set come first, so the bar behaves the same regardless of your login environment. `DOTS_SHELL_PATH` points at the repo copy.
- Bar widgets include workspaces, clock/calendar, media (MPRIS), audio, network, CPU/GPU/memory/temps, storage and mount health, power profile, weather, VPN, night light, idle inhibitor, notification silencing, dictation state, LLM unit, qBittorrent speeds, update indicator, screen recording, tray, and AI usage (Claude / Codex / OpenCode / OpenRouter quotas refreshed every 10 minutes by `dots-ai-usage.timer`).

### IPC

```fish
qs -c rise ipc call <target> <function>
```

| Target | Functions |
|---|---|
| `launcher` | `toggle` |
| `overview` | `toggle` |
| `openrouter` | `toggle` |
| `picker` | `theme`, `wallpaper`, `screenshots`, `videos` |
| `theme` | `reload`, `apply <json>`, `applyLauncher <json>` |
| `layout` | `lock`, `unlock` |
| `dots.system-update` | `refresh` |
| `variant` | `current`, `state`, `error`, `activate <version>` |
| `lifecycle` | `version`, `ready` |

`dots-shell restart` restarts the unit; stopping it also kills any of its helper scripts still running.

## Lock and idle

- Lock screen: `quickshell -c lock` (`config/quickshell/lock/`) — blurred current wallpaper, clock, date, password field, themed from the same palette as the bar. It authenticates through the `quickshell-lock` PAM service (`modules/lockscreen.nix`).
- `hypridle` (`config/hypr/hypridle.conf`): lock at **10 min**, displays off at **15 min** (`wlopm`). `lock_cmd` refuses to start a second lock instance.
- The idle toggle in the bar stops/starts the `hypridle` user unit; the unit's start/stop hooks maintain `~/.local/state/dots/indicators/stay-awake` for the widget.
- The machine never suspends — sleep targets are disabled system-wide.

## Notifications, OSD, clipboard

- **dunst** — base config in `config/dunst/dunstrc`, colours layered on top from the rendered theme (`dunstctl reload <base> <themed>`, applied by the `dotsDunstTheme` unit at session start and by every `themectl set`).
- **swayosd** — volume/brightness OSD; style is the rendered `swayosd.css`.
- **cliphist** — history daemon as a user service; `SUPER + SHIFT + V` to pick.

## Recording

`modules/recording.nix` sets up gpu-screen-recorder with its capability wrapper and a `gsr-replay` user unit:

- Captures `DP-1` at 60 fps, HEVC, very-high quality, desktop audio **plus** the EasyEffects source, into a 300 s rolling buffer.
- Not started automatically. `SUPER + ALT + R` arms/disarms; `SUPER + SHIFT + R` sends `SIGUSR1` (via `systemctl reload`) to dump the buffer to `/data/replays`.
- `gpu-screen-recorder-gtk` for ad-hoc recording; the bar's record widget drives `dots-capture-screenrecording`.

## Dictation

`voxtype` (from `scripts/voxtype.sh`): `SUPER + V` starts recording from the default PipeWire source (16 kHz mono); press again to transcribe with whisper.cpp and type the result into the focused window with `wtype` (falls back to the clipboard). Models are `ggml-*.bin` files in `/data/models/whisper`; pick one with `voxtype models` / `voxtype set-model <path>` or from the bar.

## Night light

`dots-nightlight [on|off|toggle|status]` controls the `dots-gammastep` user unit (fixed 2700 K; config in `config/gammastep/`). `SUPER + N` toggles.

## Screen sharing

xdg-desktop-portal-hyprland with [hyprland-preview-share-picker](https://github.com/WhySoBad/hyprland-preview-share-picker) as its picker (`config/hypr/xdph.conf`), capped at 120 fps. Picker layout in `config/hyprland-preview-share-picker/`.

## Login (SDDM)

`modules/sddm.nix` builds a greeter theme called `dots` from `config/sddm/dots/`:

- A centred card with the NixOS mark tinted in the theme accent, clock, password field, user/session cyclers and power buttons. Plain QtQuick — no Controls, no runtime shaders.
- Colours are baked from `config/themes/<dots.sddm.theme>/colors.sh` at build time (the host sets `demon`). The logo is tinted and the wallpaper pre-blurred with ImageMagick **inside the derivation**.
- With `dots.sddm.live = true` (default), `themectl set` also writes `/var/lib/dots-theme/sddm.json` and the greeter reads colours from it — so the greeter follows your theme without a rebuild. The wallpaper stays baked; the greeter runs as `sddm` and can't read your home.

| Option | Default | |
|---|---|---|
| `dots.sddm.theme` | `"kanagawa"` | palette to bake |
| `dots.sddm.wallpaper` | `true` | bake the theme's blurred wallpaper |
| `dots.sddm.live` | `true` | allow themectl's JSON override |
| `dots.sddm.compositor` | `"kwin"` | or `"weston"` (kiosk, lights one output) |

Preview without logging out:

```fish
sddm-greeter-qt6 --test-mode --theme /run/current-system/sw/share/sddm/themes/dots
```

Test mode checks the QML only — it bypasses the greeter-binary selection and environment SDDM applies for real. `sudo systemctl restart display-manager` is the real test.

## Look outside the theme system

| | |
|---|---|
| GTK | adw-gtk3-dark, `prefer-dark`, candy-icons (patched to inherit Papirus-Dark → Adwaita → hicolor) |
| Qt | qt6ct/qt5ct → Kvantum `KvGlass`, candy-icons |
| Cursor | Bibata Modern Classic 24 — same in the greeter |
| Fonts | FiraCode Nerd Font Mono (monospace), Noto Sans/Serif |

GTK and Kvantum colours also get themectl overrides — see [Theming](theming.md).

## Terminal

**Ghostty** (`config/ghostty/config`): fish shell integration, 0.85 opacity + blur, palette from the rendered theme. `Ctrl+Shift+S` / `Ctrl+Shift+Z` type `` `s `` / `` `z `` — tmux's session tree and pane zoom.

**tmux** (`config/tmux/tmux.conf`): prefix is backtick (`` ` ``; `` ` ` `` jumps to the last window, `` ` e `` sends a literal backtick). Vi mode. Most navigation is prefix-less on `Alt`, mirroring Hyprland:

| Keys | Action |
|---|---|
| `Alt + h j k l` | Focus pane |
| `Alt + SHIFT + h j k l` | Swap pane |
| `Ctrl + Alt + h j k l` | Resize pane |
| `Alt + Return` / `Alt + v` | Split right |
| `Alt + s` | Split down |
| `Alt + z` | Zoom pane |
| `Alt + SHIFT + Q` | Kill pane |
| `Alt + 1…9` | Go to (or create) window |
| `Alt + SHIFT + 1…5` | Send pane to window |
| `Alt + c` / `Alt + Tab` | New window / last window |
| `Alt + Space` / `Alt + t` | Next layout / tiled |
| `Alt + SHIFT + E` | Detach |
| `` ` Escape `` | Copy mode — `v` select, `Ctrl+v` block, `y` copies to the Wayland clipboard |
| `` ` r `` | Reload config |
