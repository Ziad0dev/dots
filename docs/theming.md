# Theming

One palette file per theme, a directory of templates, and `themectl` to render one into the other. Switching themes writes only to `~/.local/state/dots/` — never into the repo, so it never shows up in `git status`.

## Using it

```fish
themectl list                 # 46 themes
themectl set kanagawa
themectl set auto             # palette from the current wallpaper (matugen)
themectl set auto ~/x.jpg     # …or from a given image
                              # while auto is current, themectl bg … re-derives it
themectl next                 # / prev — alphabetical, wraps
themectl current
themectl reload               # re-render the current theme (after editing a template)
themectl render               # same files, but no app reloads and no wallpaper change

themectl bg                   # print current wallpaper
themectl bg next              # / prev — cycles ~/Pictures/wallpapers
themectl bg set ~/Pictures/wallpapers/x.jpg
```

Or: `SUPER + CTRL + SHIFT + Space` (theme picker), `SUPER + SHIFT + T` (next theme), `SUPER + E` (wallpaper picker), `SUPER + CTRL + E` (next wallpaper).

themectl is in every profile (`home/themectl.nix`), so the minimal one's prompt, fzf, tmux, Neovim and btop are themed too.

A fresh home gets `dots.theme` (oxocarbon) on its first activation, so nothing starts unstyled. With `dots.liveConfig = false` the rendered files and links point into the generation's store path, so every switch also runs `themectl render`.

## What `themectl set <name>` does

1. Sources `config/themes/<name>/colors.sh` (or `theme.sh`), computes five derived colours, and renders every `config/themes/_templates/*.in` into `~/.local/state/dots/theme/`.
2. Records the name in `~/.local/state/dots/theme/current`.
3. Points `~/.local/state/dots/shell/current/` at the palette, wallpaper directory, preview and background — what Quickshell and the lock screen read.
4. Writes `/var/lib/dots-theme/sddm.json` for the login greeter (if the directory is writable).
5. Links or copies the rendered Kvantum and GTK files into place, and concatenates `config/zen/sites/*.css` into `zen-sites.css`.
6. If the theme ships a `wallpaper.*`, sets it before reloading anything, so the wallpaper's reveal starts as the bar and apps recolour (the desktop changes in one motion, as in Omarchy 4.5). On a switch to another theme (not `reload`), its intro plays first if it has one (below).
7. Reloads: Ghostty (`SIGUSR2`), Quickshell (`theme reload` over IPC), GTK (theme name bounce), btop (`SIGUSR2`), tmux, dunst (sway only), Hyprland, swayosd. Zen reads its CSS only at startup.

## Palette format

`config/themes/<name>/colors.sh` — sourced by bash, so plain `key="#rrggbb"` lines. All 47 keys are expected:

| Group | Keys |
|---|---|
| Terminal | `background` `foreground` `cursor` `accent` `selection_foreground` `selection_background` |
| ANSI | `color0` … `color15` |
| Short aliases | `bg` `fg` |
| base16 | `base00` … `base0F` |
| Named | `red` `green` `yellow` `blue` `magenta` `cyan` `pink` |

Optional: `border` — the Hyprland active border becomes `color0 → border → color0` (fading out at both ends) instead of the default `color0 → color1`, and the Quickshell frame rim and lock-screen band use it blended 55 % toward `background` instead of `color1`.

The Quickshell bar and lock screen take their muted text from `color8` but lift it toward `foreground` until it reaches a 4.5:1 contrast against `background` (`Palette.js`) — terminal "bright black" is often far darker (oled: 1.85:1).

themectl adds five derived colours — `dim`, `muted` (foreground blended 35 % / 60 % toward background), `surface` (background 8 % toward foreground), `accent_dim` and `accent_container` (accent blended 25 % / 72 % toward background). Several palettes have `base03 == base04 == base05`; templates that need a readable grey ramp should use these instead.

Other files in a theme directory:

| File | Used by |
|---|---|
| `wallpaper.{jpg,jpeg,png,webp}` | set on `themectl set`; baked (blurred) into SDDM when this theme is `dots.sddm.theme` |
| `preview.png` / `preview.jpg` | theme picker, fastfetch's random art |

## Templates

Templates use `${key}` for `#rrggbb`, `${key_hex}` for the bare hex (Hyprland's `rgb()` wants that) and `${key_rgb}` for `r g b` decimals. Substitution is `envsubst` with an **explicit variable list**, so anything that isn't a palette key — `$TIME`, `$HOME`, shell variables in the target format — passes through untouched.

| Template | Rendered to | Consumed by |
|---|---|---|
| `hyprland.lua.in` | `hyprland.lua` | `pcall(dofile, …)` at the end of `config/hypr/hyprland.lua` — window borders |
| `ghostty.in` | `ghostty` | `config-file = ?…` in `config/ghostty/config` (the `?` makes it optional) |
| `nvim.lua.in` | `nvim.lua` | watched by Neovim's `config/nvim/lua/config/theme.lua`, re-applied live in every instance |
| `yazi.toml.in` | `yazi.toml` | linked as `~/.config/yazi/theme.toml` (`home/yazi.nix`) |
| `btop.theme.in` | `btop.theme` | linked as `~/.config/btop/themes/dots.theme` |
| `fzf.fish.in` | `fzf.fish` | sourced by fish at interactive start |
| `swayosd.css.in` | `swayosd.css` | linked as `~/.config/swayosd/style.css` |
| `gtk.css.in` | `gtk.css` | copied to `~/.config/gtk-3.0/` and `gtk-4.0/` |
| `kvantum.kvconfig.in` | `kvantum.kvconfig` | linked into `~/.config/Kvantum/KvGlass#/` |
| `zathura.in` | `zathura` | `include`d at the end of the zathurarc from `home/documents.nix` |
| `tmux.conf.in` | `tmux.conf` | `source-file -q` at the end of `config/tmux/tmux.conf`; re-sourced on switch |
| `cava.in` | `cava` | linked as `~/.config/cava/config` (`home/theming.nix`) |
| `zen-palette.css.in` | `zen-palette.css` | `--dots-*` custom properties, `@import`ed by `config/zen/userContent.css` for the per-site styles in `config/zen/sites/` |
| `share-picker.css.in` | `share-picker.css` | `stylesheets:` in `config/hyprland-preview-share-picker/config.yaml` |

Not template-driven but still themed:

| Thing | How |
|---|---|
| Quickshell Rise, lock screen | read `colors.sh` directly via `~/.local/state/dots/shell/current/theme/colors.sh` |
| SDDM | baked palette + live `sddm.json` — see [Desktop → login](desktop.md#login-sddm) |
| Obsidian | hardcoded oxocarbon |
| Websites in Zen | `config/zen/sites/<domain>.css` (from dusky), each wrapped in `@-moz-document domain(…)` and coloured from `--dots-*`; delete a file to stop theming that site |

## Adding a theme

```fish
cp -r ~/dots/config/themes/kanagawa ~/dots/config/themes/mytheme
$EDITOR ~/dots/config/themes/mytheme/colors.sh
# drop in wallpaper.jpg / preview.png if you have them
themectl set mytheme
```

No rebuild — themectl reads the working tree directly. `git add` it when you're happy.

Every key must be present. `themectl set` checks before rendering and refuses with `theme '<name>' is missing palette keys: …`, leaving the previous theme in place — copying an existing palette and editing values is the safe way to start.

A rebuild *is* needed if you make the new theme `dots.sddm.theme` or `dots.theme`, since those are baked.

## Adding a template

1. Write `config/themes/_templates/<name>.in` using `${key}` / `${key_hex}`.
2. `themectl reload` — every `*.in` is rendered automatically, no registration.
3. Point the app at `~/.local/state/dots/theme/<name>`: a `mkOutOfStoreSymlink` in a home module, an include line in the app's own config under `config/`, or a `*_compat` step in `scripts/themectl.sh` if it needs copying (that last one needs a rebuild — themectl is a packaged script).
4. If the app needs a nudge to pick up changes, add it to `reload_apps` in `scripts/themectl.sh`.

If a template references a name that isn't a palette key, it passes through unsubstituted and themectl warns `unsubstituted tokens remain in …` with the first few offenders. The check matches any `${name}` left in the output, so a target format that legitimately uses `${…}` will warn too.

## Wallpapers

- Pool: `~/Pictures/wallpapers` (top level only; jpg/jpeg/png/webp).
- `dots-set-wallpaper <file>` hands the file to Rise, which draws the wallpaper with the desktop theme's transition (`ext/shaders/wallpaper_transition.frag`; without a desktop theme, Omarchy 4.5's slanted band opening from the centre). It falls back to `awww img` when Rise isn't running or a wallpaper command is set. It records the file at `~/.local/state/dots/theme/wallpaper`.
- **Theme intros** (after Omarchy 4.5): a short clip that plays once when you switch to a theme, then settles on its wallpaper with no second transition. `themectl` looks for the theme's own `intro.{mp4,webm,mkv,mov,m4v}`, then `~/.local/share/dots/intros/<theme>.<ext>`; keep clips that aren't yours to publish in the second place, out of this public repo. Intros are silent, play even under windows, and never reach the lock screen's still. Reloading the current theme or changing only the wallpaper plays none, and a clip that stalls hands over after 30 s. Rebuild the transition shader with the `qsb` line in `config/quickshell/rise/ext/README.md`.
- `dots-current-wallpaper` reads that link (falling back to `awww query`).
- Setting a theme with its own `wallpaper.*` overrides the current wallpaper; setting one without leaves it alone.
- To give a theme a different wallpaper without changing the repo, put it at `~/.local/share/dots/wallpapers/<theme>.{jpg,jpeg,png,webp}`. It wins over the theme's own `wallpaper.*` when switching and in the theme drawer. The login greeter's build-time copy (`dots.sddm.theme`) still uses the repo's file; the live greeter copy follows the wallpaper on screen.
