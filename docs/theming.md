# Theming

One palette file per theme, a directory of templates, and `themectl` to render one into the other. Switching themes writes only to `~/.local/state/dots/` — never into the repo, so it never shows up in `git status`.

## Using it

```fish
themectl list                 # 46 themes
themectl set kanagawa
themectl next                 # / prev — alphabetical, wraps
themectl current
themectl reload               # re-render the current theme (after editing a template)

themectl bg                   # print current wallpaper
themectl bg next              # / prev — cycles ~/Pictures/wallpapers
themectl bg set ~/Pictures/wallpapers/x.jpg
```

Or: `SUPER + CTRL + SHIFT + Space` (theme picker), `SUPER + SHIFT + T` (next theme), `SUPER + E` (wallpaper picker), `SUPER + CTRL + E` (next wallpaper).

## What `themectl set <name>` does

1. Sources `config/themes/<name>/colors.sh` (or `theme.sh`), computes three derived colours, and renders every `config/themes/_templates/*.in` into `~/.local/state/dots/theme/`.
2. Records the name in `~/.local/state/dots/theme/current`.
3. Points `~/.local/state/dots/shell/current/` at the palette, wallpaper directory, preview and background — what Quickshell and the lock screen read.
4. Writes `/var/lib/dots-theme/sddm.json` for the login greeter (if the directory is writable).
5. Links or copies the rendered Kvantum, VS Code, GTK and Vencord files into place.
6. Reloads: Ghostty (`SIGUSR2`), Quickshell (`theme reload` over IPC), GTK (theme name bounce), dunst, Hyprland, swayosd.
7. If the theme ships a `wallpaper.*`, sets it with a random `awww` transition.

## Palette format

`config/themes/<name>/colors.sh` — sourced by bash, so plain `key="#rrggbb"` lines. All 47 keys are expected:

| Group | Keys |
|---|---|
| Terminal | `background` `foreground` `cursor` `accent` `selection_foreground` `selection_background` |
| ANSI | `color0` … `color15` |
| Short aliases | `bg` `fg` |
| base16 | `base00` … `base0F` |
| Named | `red` `green` `yellow` `blue` `magenta` `cyan` `pink` |

themectl adds three derived colours — `dim`, `muted` (foreground blended 35 % / 60 % toward background) and `surface` (background 8 % toward foreground). Several palettes have `base03 == base04 == base05`; templates that need a readable grey ramp should use these instead.

Other files in a theme directory:

| File | Used by |
|---|---|
| `wallpaper.{jpg,jpeg,png,webp}` | set on `themectl set`; baked (blurred) into SDDM when this theme is `dots.sddm.theme` |
| `preview.png` / `preview.jpg` | theme picker, fastfetch's random art |

## Templates

Templates use `${key}` for `#rrggbb` and `${key_hex}` for the bare hex (Hyprland's `rgb()` wants that). Substitution is `envsubst` with an **explicit variable list**, so anything that isn't a palette key — `$TIME`, `$HOME`, shell variables in the target format — passes through untouched.

| Template | Rendered to | Consumed by |
|---|---|---|
| `hyprland.lua.in` | `hyprland.lua` | `pcall(dofile, …)` at the end of `config/hypr/hyprland.lua` — window borders |
| `ghostty.in` | `ghostty` | `config-file = ?…` in `config/ghostty/config` (the `?` makes it optional) |
| `dunstrc.in` | `dunstrc` | layered over `config/dunst/dunstrc` via `dunstctl reload` |
| `nvim.lua.in` | `nvim.lua` | watched by Neovim's `config/nvim/lua/config/theme.lua`, re-applied live in every instance |
| `yazi.toml.in` | `yazi.toml` | linked as `~/.config/yazi/theme.toml` (`home/yazi.nix`) |
| `btop.theme.in` | `btop.theme` | linked as `~/.config/btop/themes/dots.theme` |
| `fzf.fish.in` | `fzf.fish` | sourced by fish at interactive start |
| `swayosd.css.in` | `swayosd.css` | linked as `~/.config/swayosd/style.css` |
| `gtk.css.in` | `gtk.css` | copied to `~/.config/gtk-3.0/` and `gtk-4.0/` |
| `kvantum.kvconfig.in` | `kvantum.kvconfig` | linked into `~/.config/Kvantum/KvGlass#/` |
| `vscode-settings.json.in` | `vscode-settings.json` | linked as `~/.config/Code/User/settings.json` — **the whole file**, so VS Code settings are edited here, not in VS Code |
| `vencord-quickcss.css.in` | `vencord-quickcss.css` | copied to Vencord's `quickCss.css` if Vencord's settings dir exists |
| `share-picker.css.in` | `share-picker.css` | rendered; the stylesheet include in `config/hyprland-preview-share-picker/config.yaml` is currently commented out |

Not template-driven but still themed:

| Thing | How |
|---|---|
| Quickshell Rise, lock screen | read `colors.sh` directly via `~/.local/state/dots/shell/current/theme/colors.sh` |
| SDDM | baked palette + live `sddm.json` — see [Desktop → login](desktop.md#login-sddm) |
| Spotify (Spicetify) | palette of `dots.theme` (home-manager option, default `oxocarbon`) parsed from `colors.sh` **at build time** |
| Zathura, Obsidian | hardcoded oxocarbon |

## Adding a theme

```fish
cp -r ~/dots/config/themes/kanagawa ~/dots/config/themes/mytheme
$EDITOR ~/dots/config/themes/mytheme/colors.sh
# drop in wallpaper.jpg / preview.png if you have them
themectl set mytheme
```

No rebuild — themectl reads the working tree directly. `git add` it when you're happy.

Every key must be present. themectl runs under `set -u`, so a missing key aborts each template with `unbound variable` and leaves the previous theme's rendered files where they were — copying an existing palette and editing values is the safe way to start.

A rebuild *is* needed if you make the new theme `dots.sddm.theme` or `dots.theme`, since those are baked.

## Adding a template

1. Write `config/themes/_templates/<name>.in` using `${key}` / `${key_hex}`.
2. `themectl reload` — every `*.in` is rendered automatically, no registration.
3. Point the app at `~/.local/state/dots/theme/<name>`: a `mkOutOfStoreSymlink` in a home module, an include line in the app's own config under `config/`, or a `*_compat` step in `scripts/themectl.sh` if it needs copying (that last one needs a rebuild — themectl is a packaged script).
4. If the app needs a nudge to pick up changes, add it to `reload_apps` in `scripts/themectl.sh`.

If a template references a name that isn't a palette key, it passes through unsubstituted and themectl warns `unsubstituted tokens remain in …` with the first few offenders. The check matches any `${name}` left in the output, so a target format that legitimately uses `${…}` will warn too.

## Wallpapers

- Pool: `~/Pictures/wallpapers` (top level only; jpg/jpeg/png/webp).
- `dots-set-wallpaper <file>` runs `awww img` with a random transition and records the file at `~/.local/state/dots/theme/wallpaper`.
- `dots-current-wallpaper` reads that link (falling back to `awww query`).
- Setting a theme with its own `wallpaper.*` overrides the current wallpaper; setting one without leaves it alone.
