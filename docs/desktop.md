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
            │     │                            └─ hypridle, cliphist, udiskie, mpdris2, …
            ├─ awww-daemon
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
| `SUPER + U` | Utilities corner (quick toggles, recent captures) |
| `SUPER + I` | Dashboard (dashboard · media · performance · weather tabs) |
| `SUPER + SHIFT + I` | Window info: preview, details, float / pin / fullscreen / center / move / close / kill (`1`–`9`, `F`, `P`, `Q`) |
| `SUPER + W` | Theme / wallpaper drawer |
| `SUPER + SHIFT + Escape` | Session menu (lock, suspend, log out, restart, shut down) |
| `SUPER + B` / `O` / `C` | Focus-or-launch Zen / Obsidian / Discord |
| `SUPER + SHIFT + O` | OpenRouter panel |
| `SUPER + period` | Emoji picker (bemoji) |
| `SUPER + SHIFT + V` | Clipboard history (cliphist → fuzzel) |
| `SUPER + V` | Dictation — start / stop (voxtype) |
| `SUPER + N` | Night light toggle |
| `SUPER + ALT + M` | Identify the song playing (`dots-songrec`) |
| `SUPER + ALT + G` | Region → Google Lens (`dots-lens`) |
| `SUPER + ALT + T` | Read the selection aloud / stop (`dots-say`) |
| `SUPER + ALT + I` | Live disk I/O monitor (`dots-diskio`) |

### Look

| Keys | Action |
|---|---|
| `SUPER + CTRL + SHIFT + Space` | Theme picker |
| `SUPER + SHIFT + T` | Next theme |
| `SUPER + E` | Wallpaper picker |
| `SUPER + CTRL + E` | Next wallpaper |
| `SUPER + CTRL + Z` / `SUPER + CTRL + ALT + Z` | Zoom in / reset zoom |
| `SUPER + ALT + A` | Animation preset picker |
| `SUPER + ALT + S` | Screen shader picker |
| `SUPER + ALT + B` | Blur on / off |

### Capture

| Keys | Action |
|---|---|
| `SUPER + S` | Flameshot |
| `Print` | Region (screen frozen while selecting) |
| `SUPER + Print` | Focused monitor |
| `SUPER + SHIFT + S` | Active window |

The last three go through `dots-shot`: saved as `~/Pictures/<date>_<time>.png`, copied to the clipboard, and announced with a preview notification; click it to open, or **Edit** to annotate in satty.
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
| `com.gabm.satty` (screenshot editor) | Floating |

Ghostty windows swallow what they launch (`enable_swallow`).

## Quickshell Rise

The bar, launcher, control panel, pickers and notifications UI. Vendored in `config/quickshell/rise/`, run by `programs.quickshell` (`home/quickshell-rise.nix`) as the `quickshell` user unit, bound to `hyprland-session.target`.

- `shell.qml` is the entry; `modules/` holds bar widgets, `panels/` the pop-outs, `core/` the IPC router and state, `scripts/` the helpers it shells out to (AI-quota fetchers, keybind scraper, bar control).
- It reads colours from `~/.local/state/dots/shell/current/theme/colors.sh` — a symlink themectl maintains to the active palette.
- `Theme.qml` is one object split across an inheritance chain for size: `ThemeTelemetry` ← `ThemeGithub` ← `ThemeAiUsage` ← `Theme`. Everything is still read as `theme.<name>`; ids don't cross files.
- Motion goes through `modules/Anim.qml` / `CAnim.qml` and the curve table in `modules/Motion.js` (Material 3 Expressive): `kind: "spatialFast"` for moves and scale (springy), `"size"` for width/height (no overshoot), `"effects"` for opacity and colour, `"spatial"`/`"exit"` for panel reveals. Use these instead of a bare `NumberAnimation`.
- **Frame** (STYLE → Frame, on by default): the bar is the thick edge of one rounded frame around each screen, and the 23 panels that hang off the bar register their card with `modules/FrameCard.qml`, so `FrameBlobs.qml` draws their background as a blob in the same group — they melt out of the bar and retract into it. The shapes come from Caelestia's `Caelestia.Blobs` QML module (SDF smooth-union, GPL-3.0, [caelestia-dots/shell](https://github.com/caelestia-dots/shell)), built on its own from a pinned upstream rev by `pkgs/caelestia-blobs` and put on the unit's `QML_IMPORT_PATH`; no Caelestia code is copied into this repo. `FrameExclusions.qml` reserves the frame's space with four 1×1 windows per screen. If the module can't load, the bar falls back to the classic island and logs `[frame] Caelestia.Blobs unavailable`. The frame has square inner corners; the widgets sit flat on its top band (no pill fill, border or shadow of their own). With Frost on, the frame layer is 55% opaque so Hyprland's blur reads through the bar and the panels. Next to the Frame tile: **Edge** draws a 2px rim in the window-border colour (`color1`, the bright end of Hyprland's active border gradient) along the frame's inner edge and around every panel (a second blob group, grown by 2px, behind the fill), and **Auto-hide** shrinks the bar band to the frame edge until you hover it — windows then only reserve the edge. With the frame on, the frame's edges open things on hover: the bottom-left corner (the left band's bottom 160px and the bottom band's left end) the dashboard, the right band the notification sidebar, the middle of the bottom band the theme / wallpaper drawer, and pushing into the bottom-right corner (the bottom band's last 140px, where the cursor rests even when another monitor sits to the right) opens the utilities corner; panels opened that way close when the pointer leaves and never take keyboard focus. The frame layer follows Frost, which is what lets the layer blur show through.
- **Utilities corner** (`panels/UtilitiesPanel.qml`, `SUPER + U`): quick toggles — Wi-Fi and Bluetooth when the hardware exists, silence, stay awake, caffeine, night light, screen recording — each running the same command as its bar widget, plus the four latest screenshots. Grows out of the bottom-right frame corner.
- **Dashboard** (`panels/DashboardPanel.qml` + `panels/dash/`, `SUPER + I`, or hover the lower-left frame corner): laid out after Caelestia's dashboard (new code, none of its GPL source): Material 3 shapes and type (Google Sans Flex, Rubik clock; packaged in `pkgs/google-sans-flex`), colour roles derived from the active palette. Four tabs (click, scroll the tab bar, `1`–`4`, Tab / Shift+Tab); the card keeps the largest tab's size so the tab bar never moves under the pointer. **Dashboard**: weather, a user card (`~/.face`, else a monogram; greeting, uptime, host), a stacked clock, the month (scroll or chevrons to page, middle-click for today), CPU / RAM / GPU or disk / temperature rings (hover for values), now playing under a wavy progress arc, Lock / Shot / Themes / Settings / Power and a quote from `quotes.txt`. **Media**: the cover in a cookie shape ringed by a cava visualiser, a draggable wavy seek bar, shuffle / previous / play / next / repeat, synced lyrics. **Performance**: CPU and GPU cards over their usage history, storage, network rates from `/proc/net/dev`, memory, kernel and uptime. **Weather** (wttr.in, fetched while open, at most every 10 min): conditions, sunrise / sunset, six details and a 3-day forecast. Its motion (wave, drifting shapes, visualiser) runs on 30 Hz timers and only on the visible tab, since the dashboard is a fullscreen layer. Grows out of the bottom-left frame corner.
- **Theme / wallpaper drawer** (`panels/StyleDrawer.qml`, `SUPER + W`): previews of every theme and wallpaper in two tabs (Tab switches), the current one ringed, scrolled sideways with the wheel; click applies with `dots-theme-set` / `dots-theme-bg-set` and the drawer stays open. Grows out of the bottom band's centre.
- **Session menu** (`panels/SessionMenu.qml`, `SUPER + SHIFT + Escape`, dashboard Power, launcher `>`): lock, suspend, log out, restart, shut down, docked mid-height on the right frame edge. The last three arm on the first press and run on a second press within 4s. Never opened by hover.
- **Launcher** (`SUPER + D`): apps as before; maths in the query shows `= result` first and Enter copies it (`modules/Calc.js`, a small parser — never `eval`); `>` lists shell actions (lock, suspend, dashboard, themes, wallpapers, clipboard, screenshot, night light, …; restart / shut down go through the session menu).
- **Desk clock** (`DeskClock.qml`, STYLE → Desk clock): large time and date bottom-left on the wallpaper, on the Bottom layer so windows cover it; no input.
- Resource use: the frame's shadow blur only runs with STYLE → Shadow, the rim shapes only with Edge, and a panel's blob shapes exist only while it's open. The dashboard, theme drawer, utilities and session menu are loaded on open and unloaded after their exit animation, so their images don't stay in memory; their graph history lives in telemetry. Toasts and the OSD use content-sized windows (their blobs are offset to the window's screen position).
- With the frame on, notification toasts melt out of the right frame edge (each card a blob, stacked cards flow into one column) and the volume / mic / caps-lock OSD rises out of the bottom band; with input limited to the cards.
- **Lock screen** (`config/quickshell/lock/LockSurface.qml`) has the same look — blurred wallpaper, the rounded frame with its accent rim (the bar's accent, read from `settings.json`), light clock, a glass card with the password field — in plain QtQuick, without the blob plugin, so it always loads.
- **Synced lyrics** in the media panel (`modules/SyncedLyrics.qml`): fetched from [LRCLIB](https://lrclib.net) only while the panel is open — that sends the playing track's artist and title there — and cached in `~/.cache/dots-lyrics` (misses too; network errors retry).
- Settings live in `~/.local/state/dots/shell/settings.json` (one key per control-panel toggle, validated on load) — add a setting by adding its property to `_settingsSchema` in `Theme.qml`.
- Compositor side: `config/hypr/modules/71-layers.lua` blurs the bar (`quickshell`) and panels (`dots-*`) and turns off Hyprland's own layer animation for panels, which animate themselves.
- The unit's PATH is pinned: the `dots-*` shims, wallpaper helpers and a fixed tool set come first, so the bar behaves the same regardless of your login environment. `DOTS_SHELL_PATH` points at the repo copy.
- Bar widgets include workspaces, clock/calendar, media (MPRIS), audio, network, CPU/GPU/memory/temps, storage and mount health, power profile, weather, VPN, night light, idle inhibitor, notification silencing, dictation state, LLM unit, qBittorrent speeds, update indicator, screen recording, tray, and AI usage (Codex / OpenCode / OpenRouter quotas refreshed every 10 minutes by `dots-ai-usage.timer`).

### IPC

```fish
qs -c rise ipc call <target> <function>
```

| Target | Functions |
|---|---|
| `launcher` | `toggle` |
| `overview` | `toggle` |
| `notifications` | `toggle`, `clear` |
| `utilities` | `toggle` |
| `session` | `toggle` |
| `dashboard` | `toggle` |
| `windowinfo` | `toggle` |
| `drawer` | `toggle` |
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

- **Notifications** — Quickshell is the notification daemon (`rise/NotificationService.qml`): popups under the bar on the focused monitor (`panels/NotificationPopups.qml`, hover pauses, click runs the default action, right click dismisses) and a persisted history in the notification centre — a right-hand sidebar that, with the frame on, grows out of the right frame edge; grouped by app (fold or dismiss a whole app), with each notification's action buttons. `qs -c rise ipc call notifications toggle|clear`; do-not-disturb is `dots-toggle-notification-silencing`, which flips `~/.local/state/dots/notifications.json`.
- **OSD** — `panels/OsdPanel.qml` shows volume, mic mute, output-device switches and caps lock, driven by PipeWire and the capslock LEDs, so any source of change shows it. swayosd is still used for brightness; style is the rendered `swayosd.css`.
- **Polkit** — Quickshell is the authentication agent under Hyprland (`panels/PolkitPanel.qml`, a dimmed prompt on the focused monitor); sway still starts `hyprpolkitagent`.
- **Clipboard** — cliphist records history (user service); `SUPER + SHIFT + V` opens the Quickshell clipboard panel (`panels/ClipboardPanel.qml`): search, image thumbnails, Enter to copy, Delete to remove, wipe with a second click.

## Recording

`modules/recording.nix` sets up gpu-screen-recorder with its capability wrapper and a `gsr-replay` user unit:

- Captures `DP-1` at 60 fps, HEVC, very-high quality, desktop audio **plus** the EasyEffects source, into a 300 s rolling buffer.
- Not started automatically. `SUPER + ALT + R` arms/disarms; `SUPER + SHIFT + R` sends `SIGUSR1` (via `systemctl reload`) to dump the buffer to `/data/replays`.
- `gpu-screen-recorder-gtk` for ad-hoc recording; the bar's record widget drives `dots-capture-screenrecording`.

## Dictation

`voxtype` (from `scripts/voxtype.sh`): `SUPER + V` starts recording from the default PipeWire source (16 kHz mono); press again to transcribe with whisper.cpp and type the result into the focused window with `wtype` (falls back to the clipboard). Models are `ggml-*.bin` files in `/data/models/whisper`; pick one with `voxtype models` / `voxtype set-model <path>` or from the bar.

## Night light

`dots-nightlight [on|off|toggle|status]` controls the `dots-gammastep` user unit (fixed 2700 K; config in `config/gammastep/`). `SUPER + N` toggles.

## Animations, shaders, blur

`dots-look` (`scripts/dots-look.sh`) switches three things and remembers them in `~/.local/state/dots/hypr/`, which `config/hypr/modules/45-animations.lua` and `46-look.lua` read on every load:

- **Animation presets** — `config/hypr/animations/*.lua`. `snap` is the default (the old `45-animations.lua`); the rest come from dusky, switched to vertical workspace slides. `dots-look anim [pick|list|<name>]`, then a `hyprctl reload`.
- **Screen shaders** — `config/hypr/shaders/*.glsl` (dusky). `dots-look shader [pick|list|off|<name>]`. A shader forces a full composite every frame, so direct scanout is gone while one is active, and they are written for SDR output — expect them to look wrong on DP-1 while HDR is engaged.
- **Blur** — `dots-look blur [on|off|toggle|status]`.

Shader and blur changes go through `hyprctl eval "hl.config(...)"` and fall back to `hyprctl reload` if that request isn't supported.

## Extra tools

From `home/desktop-tools.nix`:

- **`dots-songrec [desktop|mic|history]`** — records 10 s of the default sink's monitor (or the mic), identifies it with SongRec, notifies, copies `artist - title`, and appends to `~/.local/state/dots/songrec/history.tsv`. Needs the network (Shazam's API).
- **`dots-lens`** — slurp a region, copy it as PNG, open lens.google.com; paste with `Ctrl+V`. Nothing is uploaded to a third-party host.
- **`dots-say [toggle|stop] [text…]`** — Kokoro text to speech. With no text it reads stdin, then the primary selection, then the clipboard; streams to `pw-play`. `DOTS_SAY_VOICE` (default `af_heart`) and `DOTS_SAY_SPEED` change the voice. The first run downloads `hexgrad/Kokoro-82M` into `~/.cache/huggingface`. Off by default (it pulls in torch and spaCy); set `dots.tts.enable = true` to install it.
- **`dots-mono [on|off|toggle|status]`** — puts a mono `pw-loopback` sink in front of the current output and makes it the default; `off` restores the previous sink.
- **`dots-usb-sound [on|off|toggle|status]`** — the `dots-usb-sound` user unit says "USB device plugged in" / "USB device unplugged" on USB plug events — clips rendered at build time by Piper (`en_US-amy-medium`); this mutes or unmutes it.
- **`dots-diskio`** — per-disk read/write rates and busy %, with mount points, plus the kernel's dirty and writeback totals: when those reach zero a copy has actually landed.
- **`dots-screentime [today|yesterday|week|month|YYYY-MM-DD]`** — the `dots-screentime` user unit logs focused-app time from Hyprland's event socket into `~/.local/state/dots/screentime.db`, skipping time while the lock screen runs.
- **`dots-gif <video> [-s start] [-t seconds] [-f fps] [-w width] [-o out.gif]`** — two-pass palette GIF; defaults 15 fps, 720 px wide, written next to the input.
- **`dots-wallpapers sync [dark|light|all]`** — shallow, sparse clone of dusky's wallpaper repo into `~/.local/share/dots/dusky-images`, linked in as `~/Pictures/wallpapers/dusky-dark` / `dusky-light` so the pickers see them. Re-run to update; `status`, `remove`. Not vendored: the images carry no licence.
- **`dots-timemachine [back|status|<commit>]`** — fzf over the repo's history, stashes uncommitted work (untracked included), detaches onto the chosen commit; `back` returns to the branch and pops the stash.

## Waydroid

`modules/waydroid.nix` enables Waydroid (the `cachyos-bore` kernel has binder and binderfs built in) and installs `waydroid-helper` for ARM translation and extensions. The images are fetched imperatively with `sudo waydroid init`. The NixOS module trusts `waydroid0` outright; `dots-waydroid` (an iptables chain inserted ahead of that rule) narrows it to DHCP, DNS and replies, so Android apps reach the internet but none of the host's services — an Android Jellyfin client can't see the local server unless you add a port there. On the NVIDIA card it has to render in software (SwiftShader) — see [Troubleshooting](troubleshooting.md).

## Screen sharing

xdg-desktop-portal-hyprland with [hyprland-preview-share-picker](https://github.com/WhySoBad/hyprland-preview-share-picker) as its picker (`config/hypr/xdph.conf`), capped at 120 fps. Picker layout in `config/hyprland-preview-share-picker/`.

## Login (SDDM)

`modules/sddm.nix` builds a greeter theme called `dots` from `config/sddm/dots/`:

- A centred card with the NixOS mark tinted in the theme accent, clock, password field, user/session cyclers and power buttons. Plain QtQuick — no Controls, no runtime shaders.
- Colours are baked from `config/themes/<dots.sddm.theme>/colors.sh` at build time (the host sets `demon`), and the theme wallpaper is pre-blurred with ImageMagick **inside the derivation**. The logo is baked white and tinted with the accent in QML (`MultiEffect`), so it follows live colours too.
- With `dots.sddm.live = true` (default), `themectl set` also writes `/var/lib/dots-theme/sddm.json` and the greeter reads colours from it — so the greeter follows your theme without a rebuild. The greeter runs as `sddm` and can't read your home, so `dots-set-wallpaper` also renders a blurred, dimmed copy of every new wallpaper to `/var/lib/dots-theme/wallpaper.jpg` and points `sddm.json` at it; the baked wallpaper is the fallback.

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
