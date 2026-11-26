# Desktop

Hyprland with a Lua config, a Quickshell bar/launcher/control panel ("Rise"), a Quickshell lock screen, an SDDM greeter, and themectl colouring all of it.

## How a session starts

```
SDDM (kwin greeter, dots theme)
  └─ Hyprland
       └─ hyprland.start handler (config/hypr/hyprland.lua)
            ├─ import WAYLAND_DISPLAY, HYPRLAND_INSTANCE_SIGNATURE, … into dbus + systemd --user
            ├─ reset-failed on the session's units and the portals, then stop the portals
            ├─ systemctl --user start hyprland-session.target ── BindsTo graphical-session.target
            │     ├─ quickshell (rise)         ├─ swayosd-server
            │     │                            └─ hypridle, cliphist, udiskie, mpdris2, …
            ├─ awww-daemon
            └─ apps: zen, sideterm, sysmon, discord
```

`hyprland-session.target` is defined in `home/profiles/linux-desktop.nix`. Without it `graphical-session.target` never activates and nothing that hangs off it starts. On exit, the `hyprland.shutdown` handler stops the target. Between two sessions, apps still wake the portals and restart session units against the dead compositor until systemd's start limit blocks them; the block survives a stop, so the next session's units (the bar, hypridle, …) and the screen-capture portal wouldn't start. The `reset-failed` step clears it on every start, crash or clean exit.

## Monitors and workspaces

Defined at the top of `config/hypr/hyprland.lua` in `monitorProfiles`:

Monitor profiles (exact mode, position, rotation, HDR calibration) belong to one machine, so they stay out of the repo: `config/hypr/modules/10-monitors.lua` loads them from `~/.config/dots-local/hypr/monitors.lua`, a Lua file returning a list of `hl.monitor()` tables. An output without a profile gets its preferred mode, placed automatically. The sway session reads its `output` lines from `~/.config/dots-local/sway/outputs.conf` the same way.

A `monitor.added` handler re-applies the matching profile when a display reconnects.

Workspaces 1–8 and 10 live on DP-1; 9 is pinned to HDMI-A-1 and persistent.

### Workspace layouts

Each workspace tiles (dwindle), scrolls or floats, after Omarchy 4.5's workspace modes (`config/hypr/lib/workspace_modes.lua`, ported without its title bars and dock). `SUPER + T` cycles the focused workspace; the layout tool in the bar's quick group (shown while a workspace scrolls or floats) opens a picker for this workspace and for the default. From a terminal: `dots-layout current|next|back|set <tiling|scrolling|floating> [ws]|default [mode]`.

- **Floating:** every tiled window there floats at a comfortable size, centred and stepped from the last; new windows open that way. Focus follows clicks there instead of the pointer. Leaving the mode tiles again only the windows it floated, so dialogs and windows floated by hand stay floating; a window carried to a tiled workspace tiles.
- **A new default** applies to empty and new workspaces; workspaces with windows keep the layout they have.
- Choices live in `~/.local/state/dots/workspace-layouts` as `default=<mode>` / `<ws>=<mode>` lines, read as data and restored at every Hyprland (re)load.

HDR: a profile with `bitdepth = 10` and `cm = "hdr"` keeps that output in HDR permanently. That costs compositor CPU on the desktop; if Hyprland starts pegging a core, drop `bitdepth` / `cm` / luminance from the local profile and pin `cm = "srgb"` — see [Troubleshooting](troubleshooting.md#hyprland-uses-a-lot-of-cpu).

## Input

- Layouts `us, se, ara, fr, de` — **Right Ctrl** cycles. **Caps Lock** is Compose.
- Repeat 40/s after 250 ms, flat acceleration, numlock on.
- Focus follows mouse; the cursor warps on workspace change and hides while typing.
- Hardware cursors on with `use_cpu_buffer` (the NVIDIA-safe combination).

## Keybinds

A switch reloads Hyprland at the end of home-manager's activation (`home/profiles/linux-desktop.nix`, `hyprlandReload`): the config moves to a new store path, which Hyprland doesn't notice on its own, so new binds and rules would otherwise wait for a manual reload.

`SUPER` is the modifier. `hjkl` and arrows are interchangeable everywhere they appear, except plain `SUPER + L`, which locks (focus right is `SUPER + →`).

### Windows

| Keys | Action |
|---|---|
| `SUPER + Return` | Ghostty |
| `SUPER + SHIFT + Return` | Ghostty attached to tmux session `main` |
| `SUPER + SHIFT + Q` | Close window |
| `SUPER + h j k` / arrows | Focus (right is `SUPER + →`: `SUPER + L` locks) |
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
| `SUPER + T` / `SUPER + CTRL + T` | This workspace's layout: tiling → scrolling → floating (and back) |

### Launch

| Keys | Action |
|---|---|
| `SUPER + D` | App launcher (Rise) |
| `SUPER + ALT + Space` | The menu (`dots-menu`, after Omarchy's): the launcher's menu mode, sections for apps, learn, capture, share, toggles, style, setup, web apps, update and system. Enter opens a section, `Backspace` goes back, typing searches every entry. Without the bar running it falls back to fuzzel |
| `SUPER + M` | Music scratchpad (Tauon; started if it isn't running) |
| `SUPER + CTRL + C` | Chat scratchpad (Discord) |
| `SUPER + CTRL + M` | System monitor scratchpad (btop over nvtop; its own copy, the one on workspace 9 stays on the second monitor) |
| `SUPER + A` | Overview |
| `SUPER + U` | Utilities corner (quick toggles, recent captures) |
| `SUPER + I` | Dashboard (dashboard · media · performance · weather tabs) |
| `SUPER + CTRL + I` | Settings app (`Nexus.qml`, after Caelestia's Nexus): wallpaper & style (themes, wallpapers), network and Tailscale, Bluetooth devices, audio devices and per-app volume, notifications, bar switches, about. A centred floating window; the bar's full settings stay in the Settings panel |
| `SUPER + SHIFT + D` | Discover: artists similar to the one playing, artists to try picked from the whole library, new releases from library artists, and (after `music-scout spotify my_spotify_data.zip`) the most-played Spotify albums the library lacks with Bandcamp / Qobuz links (`buy list` opens them all as a page; bought zips dropped in `~/Downloads` import themselves, `music-buy-import`), and ListenBrainz's weekly exploration playlist once a user token is in `~/.config/music-scout/listenbrainz-token` (`music-scout`). The `slsk` buttons, `other versions`, and a right click on a similar artist open that search in Nicotine+ (`slsk-search`) |
| `SUPER + ,` | Settings: every bar setting by page (bar, widgets, style, general), links to the network / Bluetooth / audio / theme panels, versions |
| `SUPER + SHIFT + I` | Window info: preview, details, float / pin / fullscreen / center / move / close / kill (`1`–`9`, `F`, `P`, `Q`) |
| `SUPER + W` | Theme / wallpaper drawer |
| `SUPER + SHIFT + Escape` | Session menu (lock, suspend, log out, restart, shut down) |
| `SUPER + B` / `O` / `C` | Focus-or-launch Zen / Obsidian / Discord |
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
| `SUPER + CTRL + G` | Game mode on / off: no animations, window blur or see-through, shadows, rounding or gaps, notifications silenced; the bar, frame and panels keep their blur (`dots-look game`; also a Utilities tile). It only lifts a silence it set itself |
| `SUPER + ALT + V` | Glass on / off: rounder borderless windows, a soft haze blur (`haze` variant, no colour boost), more see-through GTK / ghostty / Zen (`dots-look glass`) |

### Capture

| Keys | Action |
|---|---|
| `SUPER + S` | Flameshot |
| `Print` | Area picker: screens freeze, hover offers the window under the pointer, drag picks any region, click takes what's offered, `Esc` cancels |
| `SUPER + Print` | Focused monitor |
| `SUPER + SHIFT + S` | Active window |
| `SUPER + SHIFT + C` | Colour picker: click anywhere, the hex code goes to the clipboard (`hyprpicker`) |

The area picker is Rise's (`AreaPicker.qml`, after Caelestia's; it cuts the pick from the frozen frame and hands it to `dots-shot import`); without Rise running, `Print` falls back to `slurp` on a frozen screen. The last three go through `dots-shot`: saved as `~/Pictures/<date>_<time>.png`, copied to the clipboard, and announced with a preview notification; click it to open, or **Edit** to annotate in satty.
| `SUPER + ALT + R` | Arm / disarm the replay buffer |
| `SUPER + SHIFT + R` | Save the last 5 minutes |

### Session

| Keys | Action |
|---|---|
| `SUPER + L`, `SUPER + Escape`, `SUPER + CTRL + L` | Lock |
| `SUPER + CTRL + R` | Reload Hyprland |
| `SUPER + SHIFT + E` | Exit Hyprland |
| Volume keys | ±5 % / mute (work while locked) |

## Named scratchpads

After Caelestia's special workspaces (`config/hypr/modules/64-keys-scratch.lua`): music, chat and a system monitor each live on a special workspace of their own (the monitor's is a second copy; the first stays on workspace 9, the second monitor) and slide in over whatever you're doing with one key (`SUPER + M`, `SUPER + CTRL + C`, `SUPER + CTRL + M`), and away with the same key. A key whose app isn't running starts it there, and one whose app is open somewhere else brings it over. Only those launches (and Discord's at login) go to a scratchpad: the same app opened from the launcher or the dock opens where you are. `SUPER + C` still focuses Discord, which brings its scratchpad up. `SUPER + minus` stays the plain scratchpad.

## Web apps

`dots-webapp` (also **Menu → Web apps**, which asks for the name, address and icon in a small terminal) turns a site into an app, as in Omarchy: its own launcher entry, icon and window (Helium's app mode, no tabs or address bar; `DOTS_WEBAPP_BROWSER` picks another Chromium).

```sh
dots-webapp install "YouTube Music" https://music.youtube.com https://…/youtube-music.png
dots-webapp install "Maps" http://127.0.0.1:8090/maps     # the offline hub
dots-webapp list | open NAME | remove NAME
```

Addresses are https, or http on this machine only. The icon is optional (an https PNG or SVG, checked by content, 2 MB at most; [dashboard-icons](https://github.com/homarr-labs/dashboard-icons) has most sites); without one it's the theme's browser icon. Entries are `~/.local/share/applications/dots-webapp-*.desktop`.

## Sharing

LocalSend (**Menu → Share**) sends files and text to phones and computers on the LAN; its port (53317, TCP and UDP) is open on the LAN interface only (`modules/lan.nix`).

## Window rules

| Match (class) | Rule |
|---|---|
| `com.dots.float{,.sm,.md,.lg}` | Floating, centred, 1200×750 / 900×600 / 1100×700 / 1200×750. Every `dots-*` popup terminal uses these |
| `zen-beta`, `dev.dots.sideterm` | Workspace 1 |
| `org.qbittorrent.qBittorrent` | Workspace 3 (silent) |
| `dev.dots.sysmon` | Workspace 9, the second monitor (silent, no focus) — tmux session `sysmon` with btop over nvtop |
| `dev.dots.sysmon.pad` | The `monitor` scratchpad (silent) — its own tmux session, `sysmon-pad` |
| `discord` | Opaque, no blur, dim or shadow. Autostart opens it on the `chat` scratchpad |
| `org.pwmt.zathura` | Opaque, no blur, inhibits idle when fullscreen |
| `flameshot` | Floating, pinned |
| `com.gabm.satty` (screenshot editor) | Floating |

Ghostty windows swallow what they launch (`enable_swallow`).

Hyprland blurs behind a GTK 4.24+ window only when the window asks for it
through CSS `backdrop-filter`. GTK always attaches an `ext-background-effect`
object, and an empty blur region tells Hyprland not to blur. Ghostty asks
through `config/ghostty/blur.css` (`gtk-custom-css`).

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
- Resource use: the frame's shadow blur only runs with STYLE → Shadow, the rim shapes only with Edge, and a panel's blob shapes exist only while it's open. The dashboard, theme drawer, utilities and session menu are loaded on open and unloaded after their exit animation, so their images don't stay in memory; their graph history lives in telemetry. Toasts and the OSD use content-sized windows (their blobs are offset to the window's screen position). The desktop visualiser (Settings → Style, off by default) is a 160px strip on the Bottom layer: cava at 30 fps, only while something plays and the workspace on that screen is empty. The bar is a 48px window over its own fullscreen frame window (`FrameWindow.qml`), so bar animations only re-composite the strip.
- With the frame on, notification toasts melt out of the right frame edge (each card a blob, stacked cards flow into one column) and the volume / mic / caps-lock OSD rises out of the bottom band; with input limited to the cards.
- **Lock screen** (`config/quickshell/lock/LockSurface.qml`) has the same look — blurred wallpaper, the rounded frame with its accent rim (the bar's accent, read from `settings.json`), light clock, a glass card with the password field — in plain QtQuick, without the blob plugin, so it always loads.
- **Synced lyrics** in the media panel (`modules/SyncedLyrics.qml`): fetched from [LRCLIB](https://lrclib.net) only while the panel is open — that sends the playing track's artist and title there — and cached in `~/.cache/dots-lyrics` (misses too; network errors retry).
- Settings live in `~/.local/state/dots/shell/settings.json` (one key per control-panel toggle, validated on load) — add a setting by adding its property to `_settingsSchema` in `Theme.qml`.
- Compositor side: `config/hypr/modules/71-layers.lua` blurs the bar (`quickshell`) and panels (`dots-*`) and turns off Hyprland's own layer animation for panels, which animate themselves.
- The unit's PATH is pinned: the `dots-*` shims, wallpaper helpers and a fixed tool set come first, so the bar behaves the same regardless of your login environment. `DOTS_SHELL_PATH` points at the repo copy.
- Bar widgets include workspaces, clock/calendar, media (MPRIS), audio, network, CPU/GPU/memory/temps, storage and mount health, power profile, weather, VPN, night light, idle inhibitor, notification silencing, dictation state, LLM unit, qBittorrent speeds, update indicator, screen recording, tray, and AI usage (Claude Code quota refreshed every 10 minutes by `dots-ai-usage.timer`).
- The quick group folds like Omarchy 4.5's indicators (`modules/QuickReveal.qml`): tools that are on (stay-awake, night light, VPN, Tailscale connected, pending reminders, a running LLM, qBittorrent transferring) always show; the rest appear while you hover the group or one of its popouts is open, and fold away shortly after. With nothing on, a ⋯ handle marks the group. The whole group is still the `modQuick` setting.
- **Dock** (`Dock.qml`, after Omarchy 4.5's and macOS's): on the left edge, part of the frame. With the frame on, its shelf is a frame card, so it grows out of the left band like Caelestia's drawers and swells with the icons as they magnify under the pointer; without the frame it's a glass shelf. An apps button (the launcher), your pinned apps, then everything running, in the theme's icons. The whole bar (dock, tray, launcher, panels) takes its icon theme from `dots-appearance` when it starts (`QS_ICON_THEME`: WhiteSur-dark on oled); a theme switch changes them at the next bar restart. With many apps the icons shrink to fit between the bar and the dashboard's corner. A mark on the frame side shows a running app, longer and in the accent while it has focus; an app bounces while it starts. Click opens the app, focuses it, or cycles its windows; middle-click opens a new window; right-click keeps it in the dock, removes it, or quits it. Pins are desktop ids, one per line, in `~/.local/state/dots/dock-pins`. Settings → Bar → Dock (or the settings app's Bar page): **Auto-hide** (default: every workspace, out of the left band when the pointer touches it; the band's bottom end still opens the dashboard), **Floating only** (as in Omarchy), **Always** (reserves its width) or **Off**. It steps aside for fullscreen windows.
- Readings fold too (`modules/DetailFold.qml`, Settings → Bar → Readings on hover, on by default): at rest the bar shows glyphs only, and hovering either side unfolds that side's numbers (CPU, memory, volume, Claude usage, GPU, temperature, storage, network speed and graph, keyboard layout). A reading in trouble stays out: CPU at 80 °C or more, storage or GPU memory at 90 % or more, a blocked Claude limit.
- One colour rule across the bar: glyphs in the accent, readings in the text colour (`barValue` in `Theme.qml`), and a reading in trouble in `barAlert`. Symbolic tray icons are filled with the accent; colour app icons are washed in it, keeping their shading (Settings → System tray → Tint tray icons).
- Tools after Omarchy 4.5's bar (`ThemeBarTools.qml`, `scripts/dots-bar-tools.sh`; new code, ideas from basecamp/omarchy, MIT), hover to open and click to pin like the other popouts:
  - **Tailscale** (quick group, lit when connected; hidden if `tailscaled` isn't running): state, this machine and the tailnet's machines (online first). Click a machine to copy its IP, right-click for its MagicDNS name. Connect / Disconnect starts the root oneshots `tailscale-connect` / `tailscale-disconnect` (`tailscale up` / `down`, `modules/media.nix`), which a polkit rule lets your user start. Your user is deliberately not the Tailscale operator, which would also allow `tailscale serve` / `funnel`. If `up` fails (e.g. it wants flags you set earlier), see `journalctl -u tailscale-connect`.
  - **World clock** (globe): the time, offset and day in each zone listed in `~/.local/state/dots/worldclock` (one IANA zone per line); add zones in the panel, hover a row for ✕.
  - **Reminders** (alarm, with a count while any are pending): a preset (5 m–1 h) or `20`, `1h30`, `at 15:30`; each is a transient systemd user timer (`dots-reminder-*`) that sends a critical notification, so it survives a bar restart. ✕ cancels.
  - **Disk speed test** (Storage popout, pinned only): a 1 GiB direct-I/O write then read in the chosen writable mount (click the mount name to cycle), deleted afterwards. Needs 2 GiB free.
  - **Cached sudo** (status row): shown for ~5 min after `sudo` opened a session, read from sudo's journal lines rather than by running sudo. Click runs `sudo -K` to forget every cached credential.
  - **Remote login** (status row): shown while a remote logind session (SSH, Tailscale SSH) exists; the tooltip says who and from where.

### Mouse on the bar

Every module opens its panel on a left click, or on hover with STYLE → Hover
popouts (on by default; a click pins a hovered panel). The other buttons and
the wheel do the module's next most common things:

| Module | Right click | Middle click | Wheel |
|---|---|---|---|
| Workspaces | workspace panel | overview | next / previous workspace |
| Notifications | Do Not Disturb | clear all | — |
| Clock (left: 12 / 24 h) | time-zone picker | calendar | — |
| Media (left: play / pause) | media panel | play / pause | next / previous track |
| Volume | mute | mute the microphone | volume |
| Brightness | night light | — | brightness |
| Battery | power profiles | — | — |
| Network | Wi-Fi settings app | Wi-Fi radio on / off | — |
| Power profile | next profile | — | more / less performance |
| Keyboard layout | — | — | next / previous layout |

The wheel moves one step per notch; a touchpad's small scrolls add up to one.

### Desktop widgets

Widgets sit on the wallpaper, under the windows, each draggable to where you
want it (the place is kept). Add them from the gallery in the themes panel's
**Widgets** tab (`SUPER + ALT + W`): each card shows the widget live, and a
click puts it on the desktop or takes it off. With no desktop theme they use
the expressive look (tonal cards in the wallpaper's colours, a scalloped
clock, wavy progress rings, after lucid); a desktop theme gives them its own
frames. Code: `ext/modules/desktopwidgets/` (the looks are in
`WidgetStyle.qml`), the list in `ext/services/DesktopWidgets.qml`.

| Widget | What it shows |
|---|---|
| Clock | the theme's clock face |
| Music player | now playing, with controls |
| System monitor | CPU (with history), memory, temperature, disk |
| Quote | a line from the quotes every ten minutes |
| Visualizer | the cava spectrum |
| Calendar | the month (wheel or arrows to turn it), days with calendar notes dotted, today's notes |
| Progress | how much of the day, week, month and year has gone |
| Timer | countdown (presets, the wheel sets minutes), pomodoro, stopwatch; notifies at the end |
| Lyrics | the song's timed lyrics from LRCLIB, the sung line lit |
| Weather | now, three days, sunrise and sunset (wttr.in, like the bar's panel) |
| At a glance | the date, the next of today's notes, what's playing |
| Network | download and upload speed, the last minute as lines |
| Devices | battery of wireless mice, headsets and controllers |
| Note | a sticky note (click and type; saved as you go) |
| To-do | a checklist: add, tick, clear the done ones |
| Quick toggles | do not disturb, night light, Wi-Fi, microphone, stay awake |
| Shortcuts | app icons that launch them (the list is `apps` in `ShortcutsWidget.qml`) |

The calendar, progress, timer, lyrics, weather, glance, network, devices,
note, to-do, toggles and shortcuts widgets are written after
[lucid](https://github.com/Sn3akyy1/lucid)'s (MIT).

### Overview

`SUPER + A`, or a middle click on the workspaces, shows every workspace as a
miniature of its screen: the wallpaper, and each window as a live picture
where it really sits, its app's icon on it. Click a window to go to it,
middle-click it to close it, click a card's empty space for the workspace.
Keys: arrows or `hjkl` move, `1`–`9` jump, `Enter` goes, `Escape` leaves.
Code: `panels/OverviewPanel.qml` (after lucid's workspaces overview).

### System tray icons

Settings (`SUPER + ,`) → **Bar → System tray** controls tinting, compact spacing, and the tray's own background. Tinting is on by default and uses the active palette accent; turn it off to keep each application's original icon colors. Tray icons appear directly on the bar; hovering an app with a DBus menu opens that menu, while clicking activates the app. There is no overflow dots button or separate AppMenu button.

For Caelestia-style per-app icon substitutions or to hide specific tray items, add these optional keys to the root of `~/.local/state/dots/shell/settings.json` (use the exact `SystemTrayItem.id`):

```json
{
  "trayIconSubs": [
    { "id": "steam", "icon": "sports_esports" },
    { "id": "some-tray-app", "image": "~/Pictures/icons/my-tray-icon.svg" }
  ],
  "trayHiddenIcons": ["unwanted-tray-app"]
}
```

`icon` is a Material Symbols name; `image` is a file path or image URL and wins if both are set. The configuration reloads with the shell. Icon substitutions and hidden IDs are global, while tint/compact/background are normal Rise settings. The tray options follow [Caelestia's tray controls](https://github.com/caelestia-dots/shell), adapted to Rise's settings file and overflow panel.

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
| `discover` | `toggle` |
| `session` | `toggle` |
| `dashboard` | `toggle` |
| `windowinfo` | `toggle` |
| `settings` | `toggle` |
| `drawer` | `toggle` |
| `picker` | `theme`, `wallpaper`, `screenshots`, `videos` |
| `theme` | `reload`, `apply <json>`, `applyLauncher <json>` |
| `layout` | `lock`, `unlock` |
| `dots.system-update` | `refresh` |
| `variant` | `current`, `state`, `error`, `activate <version>` |
| `lifecycle` | `version`, `ready` |

`dots-shell restart` restarts the unit; stopping it also kills any of its helper scripts still running.

## Lock and idle


- Lock screen: `quickshell -c lock` (`config/quickshell/lock/`) — blurred current wallpaper, clock, date, password field, themed from the same palette as the bar. It authenticates through the `quickshell-lock` PAM service (`modules/lockscreen.nix`).
- On screens at least 1500 px wide, side columns after Caelestia's lock (`LockCentre.qml`): the weather (wttr.in, as the bar fetches it; no card when offline) and what's playing with previous / play-pause / next on the left, CPU, memory, disk and uptime, and the latest notifications on the right. Notifications come from the bar's saved history and show only the app and the title, never the message body, since anyone at the desk can read a lock screen; ones that arrived after locking are marked and counted.
- `hypridle` (`config/hypr/hypridle.conf`): screensaver at **5 min** (`dots-screensaver`, drawn by the bar: `rise/Screensaver.qml`, after Omarchy's — the NixOS logo (`rise/NixosArt.js`, fastfetch's block-character art) played through terminal-text-style effects on black (decrypt, rain, beams, print, expand, slide; one after another), in a gradient through the theme's palette, with a small clock under it; the same picture on every monitor, sized to fit each, wandering a little every two minutes against burn-in; any key, click or pointer movement ends it, and the key doesn't reach the app underneath; it skips game mode; `qs -c rise ipc call screensaver start|stop|active`. It is a layer overlay rather than windows because Hyprland resets idle timers whenever a window opens or takes focus, see troubleshooting), lock at **10 min** (stopping the screensaver first), displays off at **15 min** (`wlopm`). `lock_cmd` refuses to start a second lock instance.
- The idle toggle in the bar stops/starts the `hypridle` user unit; the unit's start/stop hooks maintain `~/.local/state/dots/indicators/stay-awake` for the widget.
- The machine never suspends — sleep targets are disabled system-wide.

## Notifications, OSD, clipboard

- **Notifications** — Quickshell is the notification daemon (`rise/NotificationService.qml`): popups under the bar on the focused monitor (`panels/NotificationPopups.qml`, hover pauses, click runs the default action, right click dismisses) and a persisted history in the notification centre — a right-hand sidebar that, with the frame on, grows out of the right frame edge; grouped by app (fold or dismiss a whole app), with each notification's action buttons. `qs -c rise ipc call notifications toggle|clear`; do-not-disturb is `dots-toggle-notification-silencing`, which flips `~/.local/state/dots/notifications.json`.
- **OSD** — `panels/OsdPanel.qml` shows volume, mic mute, output-device switches and caps lock, driven by PipeWire and the capslock LEDs, so any source of change shows it. swayosd is still used for brightness; style is the rendered `swayosd.css`.
- **Polkit** — Quickshell is the authentication agent under Hyprland (`panels/PolkitPanel.qml`, a dimmed prompt on the focused monitor); sway still starts `hyprpolkitagent`.
- **Clipboard** — cliphist records history (user service); `SUPER + SHIFT + V` opens the Quickshell clipboard panel (`panels/ClipboardPanel.qml`): search, image thumbnails, Enter to copy, Delete to remove, wipe with a second click.

## Recording

`modules/recording.nix` sets up gpu-screen-recorder with its capability wrapper and a `gsr-replay` user unit:

- Captures `dots.recording.monitor` (`DP-1`, set in the host) at 60 fps, HEVC, very-high quality, desktop audio into a 300 s rolling buffer.
- Not started automatically. `SUPER + ALT + R` arms/disarms; `SUPER + SHIFT + R` sends `SIGUSR1` (via `systemctl reload`) to dump the buffer to `~/Videos/Replays`.
- `gpu-screen-recorder-gtk` for ad-hoc recording; the bar's record widget drives `dots-capture-screenrecording`.

## Dictation

`voxtype` (from `scripts/voxtype.sh`): `SUPER + V` starts recording from the default PipeWire source (16 kHz mono); press again to transcribe with whisper.cpp and type the result into the focused window with `wtype` (falls back to the clipboard). Put `ggml-*.bin` files in `~/.local/share/voxtype/models`; pick one with `voxtype models` / `voxtype set-model <path>` or from the bar. Install a model manually after reinstalling, e.g. `ggml-large-v3-turbo-q5_0.bin` (550 MB, multilingual) from `huggingface.co/ggerganov/whisper.cpp`, checked against the SHA-256 shown there. whisper.cpp is the CUDA build (`modules/media-extras.nix`), so transcription runs on the GPU.

Superwhisper (proprietary, `flakes/superwhisper`) runs next to it as the `superwhisper` user unit: hold **Right Alt** to dictate, let go to paste, **Escape** cancels. Open **Superwhisper** from the launcher (or `superwhisper`) to sign in, pick Cloud or Offline under Configuration → Processing, and download the offline models; settings, models and history live in `~/.config/superwhisper` and `~/.local/share/superwhisper`. Its shortcuts are a Lua file it writes itself, `~/.local/state/superwhisper/hyprland.lua`, which `config/hypr/modules/65-superwhisper.lua` loads (the Hyprland config is read-only, so it can't edit `bindings.lua` as upstream does). On its first start it also links `~/.config/wireplumber/wireplumber.conf.d/superwhisper-keep-inputs-ready.conf` (keeps microphones from suspending, so dictation starts at once; applies from the next login). `superwhisper doctor` checks its dependencies; `journalctl --user -u superwhisper` for logs. The in-app updater is refused; updates come as a monthly `superwhisper: <version>` PR from `.github/workflows/superwhisper-update.yml` instead (merge it on a passing comment, pull, switch), and the bar's upstream-watch lights up (`dots-upstream-watch status`) once a newer release is out. `python3 -I scripts/superwhisper-bump.py` (with `minisign` on PATH) does the same bump locally: it verifies both archives' SHA-256 and minisign signature before it rewrites `version` and the hashes.

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
