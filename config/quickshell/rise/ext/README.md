# rise/ext

Features ported into rise from [dhrruvsharma/shell](https://github.com/dhrruvsharma/shell)
(and its standalone [qs-wallpaperpicker](https://github.com/dhrruvsharma/qs-wallpaperpicker),
which is the same picker), © dhrruvsharma, **GPL-3.0-or-later** (see `LICENSE`).
Every ported file says where it came from in its first lines; changes made for
rise are marked `rise:` in the code. Because of this folder, rise as a whole
is GPL-3.0-or-later if it is ever distributed.

Not ported: upstream's own bar, control center, launcher, media panel, OSD,
power menu and GitHub popout (rise has its own), the anime/manga/novel
readers, Aikira and Ollama chat.

## How it hangs together

- `../ExtRoot.qml` hosts everything; `VariantRoot.qml` loads it **by URL**, and
  it loads each feature by URL too, so a broken port fails alone and never
  takes the bar down. It sits at the root of rise (not in here) because
  Quickshell only builds `qs.` modules for directories imported from files it
  scans, and it scans from the root; ExtRoot imports every directory here for
  the same reason.
- Imports are `qs.ext.*`; paths are `Quickshell.shellPath("ext/…")`.
- Panels are part of rise's frame, Caelestia-style: `components/FrameDock.qml`
  pins a panel's card to a frame edge (the bar, or the left/bottom band) and
  hands its background to rise's `FrameCard`, so `FrameBlobs` draws it as a
  blob melting out of that edge. In frame mode the card is transparent with
  no border or `PanelDecor`. Docked: keybinds editor, themes, notepad,
  timer, network map (bar); Oracle (left band); notes, avatar (bottom band);
  pet hub (bar, under the pet). Only the wallpaper picker and the expose
  overview stand alone. `services/Rise.qml` carries rise's Theme (null in
  the lock screen instance, where panels float).
- `colors/Colors.qml` derives upstream's Material 3 roles from the dots theme's
  `colors.sh` (window-border red as primary, dimmed gilt tertiary), so every
  ported panel wears the current rise theme. `settings/SettingsConfig.qml`
  keeps the picker's settings.
- State lives in `~/.local/state/dots/shell/ext/` (settings, notes, notepad,
  calendar notes, pet, desktop theme, widgets, lock themes, lock engine);
  caches in `~/.cache/quickshell/` (wallpaper palettes, favourites, lock stats,
  keybind backups).

## Features

| Feature | Open | Notes |
|---|---|---|
| Swatch-deck wallpaper picker | SUPER+SHIFT+W, `wallpaper toggle` | Each card wears the matugen scheme it would give (dry run, as `themectl` auto). Folder chips for `~/Pictures/wallpapers/*` (D steps), colour sort, favourites (F), peek (Space), Wallhaven tab (downloads to `wallpapers/wallhaven/`). Setting one runs `themectl bg set`. |
| Wallpaper drawn by rise | — | `WallpaperLayer` draws it (theme transitions, videos, the desktop theme's layer). `dots-set-wallpaper` hands every change to `wallpaper display` and only uses awww when rise isn't drawing. Set a wallpaper command in the picker's settings (e.g. `awww img {}`) to hand drawing back. |
| Keybinds editor | SUPER+/, `keybinds toggle`, "edit" in the bar's keybind popout | Reads and rewrites `~/.config/hypr/**/*.lua` (Lua 5.5 sandbox, `luac -p`, dry run, backups in `~/.cache/quickshell/keybinds`). Writes `mod .. " + …"` like the config does. |
| Notes drawer | SUPER+SHIFT+N, `notes toggle`, Utilities | Categories with per-category commands (run in ghostty). |
| Notepad | SUPER+CTRL+N, `notepad toggle` | |
| Timer | `timer toggle`, Utilities | Keeps counting while closed. |
| Emoji / kaomoji | Tab in the clipboard panel (SUPER+SHIFT+V) | Lists in `files/`. |
| Calendar notes | the bar's calendar | Notes per day (⇧⏎: every year), a dot on days with notes. |
| Window switcher | ALT+TAB, `switcher toggle` | Live thumbnails, search, drag between workspaces. |
| Workspace exposé | SUPER+ALT+TAB, `expose toggle` | |
| Wi-Fi fan / Bluetooth orbits | SUPER+ALT+N, `networkMap changeVisible wifi\|bluetooth`, "map" in rise's network and bluetooth panels | Includes a BlueZ pairing agent (`scripts/bluetooth_agent.py`) for PIN/passkey pairing. |
| Bar pet | on the bar; SUPER+SHIFT+P for its hub | Grimalkin, a familiar in the grimoire's red on black. `pet hide\|appear\|say <text>`. |
| Workspace disc | `workspaceDisc toggle` (off by default) | Bottom-right corner. |
| Desktop widgets | `widgets toggle` (themes panel) | Clock, music, system, quote (from rise's `quotes.txt`), cava, on rise's bar monitor. They unmap while that workspace has a tiled or fullscreen window. |
| Desktop themes | SUPER+ALT+W (`themes desktop`), `desktopTheme set <id>\|disable` | 15 looks (Cathedral fits the grimoire best). Hyprland changes are runtime only (`hyprctl eval`); turning one off runs `hyprctl reload`. Screen effect is off by default so `dots-look`'s shader stays. |
| Lock themes | `themes lockscreen`; preview from the panel | Opt-in: `lockscreen engine themed` makes hypridle start them (`scripts/lock`); `lockscreen engine classic` goes back to `quickshell -c lock`. Avatar from `~/Pictures/avatars` (`avatarPicker toggle`). |
| The Oracle (local LLM chat) | SUPER+ALT+O, `oracle toggle` | Talks to whichever dots-llm backend is up (llama.cpp :8080 or Ollama :11434, OpenAI-compatible, streamed); wakes one if none is; shows a reasoning model's thinking folded. Scripting: `oracle wake <unit>`, `ask <text>`, `last`, `state`, `sleep`. |
| GitHub heatmap | the bar's GitHub popout | 28 weeks of contributions from `gh` (GraphQL `viewer`), total and streak. |
| Zen in the desktop theme | — | `ZenTheme` writes `~/.local/state/dots/theme/zen-desktop-theme.css` (imported by config/zen/userChrome.css): the theme's chrome from `firefox/<id>.css`; empty with no theme. Applies on Zen's next start. |
| Fullscreen visualizer | `visualizer toggle` | Off by default (it redraws every frame). |

All IPC is `qs -c rise ipc call <target> <function>` (no function is called
`show`: qs's CLI parses that as its own `ipc show`); `ipc-commands.json`
lists them for the bind editor, notes and pet (regenerate with
`scripts/gen-ipc-commands.py`).

## Shaders

`shaders/*.frag.qsb` are built from the `.frag` next to them with

    qsb --glsl "100 es,300 es,120,150" --hlsl 50 --msl 12 -o X.frag.qsb X.frag

The `300 es` variant matters here: Qt runs on an OpenGL ES context on this
NVIDIA setup and picks the GLSL ES variant, and GLSL ES 1.00 has neither
constant arrays nor integer `clamp`.
