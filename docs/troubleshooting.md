# Troubleshooting

Grouped by where it breaks. Each entry is symptom → cause → fix.

## Evaluating and building

### "path … does not exist" / "not tracked by Git" / my edit has no effect

The flake is read from git. Untracked files don't exist and unstaged *new* files are invisible. `git add -A`, then retry. The pre-commit hook catches `flake.nix` references to untracked modules; it can't catch everything.

### An eval error with a wall of `lib/modules.nix` frames

`--show-trace` prints outermost frames first. The frames at the top (`system.build.toplevel`, `head`, `modules.nix:…`) are noise; the real message — often a `Failed assertions:` block — is at the **bottom**.

```fish
nh os build --show-trace 2>&1 | tail -40
```

### "attribute '…' already defined"

The same key appears twice in **one file** — a plain duplicate, not a module merge conflict. Search the file for the attribute path.

### `nix flake update nixpkgs` does nothing

`nixpkgs` follows `chaotic/nixpkgs`. Update chaotic: `nh os switch -U chaotic`.

### "Refusing to evaluate package … unfree" despite `allowUnfree = true`

Happened once when chaotic-nyx's overlay re-imported nixpkgs without the (newly deferred) config — upstream issue chaotic-cx/nyx#2276, fixed in #2304. If it recurs after an update: `nh os switch -U chaotic` first; as a temporary bridge, `NIXPKGS_ALLOW_UNFREE=1 nh os switch --impure`. The same variable is how you get unfree packages in `nix shell nixpkgs#…`, which never sees system config.

### nvidia-open reference-check failure

`output … is not allowed to refer to … linux-…-dev` while building the NVIDIA open module.

The CachyOS kernel compresses modules, so they install as `.ko.zst`, and nixpkgs' `nuke-refs` pass only looks at `.ko` — a reference to the kernel's dev output survives inside `nvidia-modeset.ko.zst`. It only bites when the driver is built locally (a cache miss on chaotic's cache).

The fix is `lib/nvidia-zstd-refs.nix`, applied in the host as `package = fixZstdRefs pkgs.nvidia_cachyos;`. Its `postFixup` decompresses each `.ko.zst`, strips references, recompresses. Things to know:

- It's a function, not a module — keep it out of `modules/` and out of `imports`, or NixOS calls it with module arguments and fails with "unexpected argument".
- It adds `nukeReferences` explicitly; the `open` derivation doesn't inherit it from nvidia-x11.
- If the `open` drv hash doesn't change after editing the fix, the override never reached the derivation: check `nix eval ~/dots#nixosConfigurations.nixos.config.hardware.nvidia.package.open.drvPath`.
- Don't "fix" it by pinning an older driver branch — the override is version-independent.

`sign-file` SSL warnings and "missing System.map. Skipping depmod." in that build log are normal.

### ananicy-cpp fails to build (`memset` / `int32_t` not declared)

libc++ header cleanup; nixpkgs has no patch. `modules/ananicy-fix.nix` prepends `<cstring>` and `<cstdint>` to every source file. Passing `-include` through `cmakeFlags` doesn't work — nixpkgs word-splits them. Delete the module once nixpkgs builds ananicy-cpp again.

### `stdenv.isx86_64` / `isLinux is deprecated` warnings

Not from this repo or any input's own `.nix` files. They're emitted once when chaotic's CachyOS kernel package set is constructed. Harmless.

### A `writeShellApplication` build fails on shellcheck

It runs shellcheck with warnings as errors. Sourcing a file by variable trips SC1090 — put the `source` in its own function with `# shellcheck source=/dev/null` above it (see `scripts/themectl.sh`). It also runs with `set -euo pipefail`: using a variable before it's assigned is fatal at runtime.

### Option renamed or removed on update

Already absorbed on the current pin — useful when reading older configs or upstream examples:

| Old | Now |
|---|---|
| `services.locate.localuser` | removed (plocate has no per-user mode) — hard assertion |
| `virtualisation.libvirtd.qemu.ovmf` | removed — hard assertion; OVMF is available by default |
| `programs.git.extraConfig` | `programs.git.settings` |
| `home.pointerCursor` | needs `enable = true` |
| `poppler_utils` | `poppler-utils` |
| `services.ollama.acceleration` / `models` | `package = pkgs.ollama-vulkan` / `modelsDir` |
| `services.llama-cpp.extraFlags` | `settings` (keys are `llama-server` long flags) |

### The closure suddenly got huge

Check for packages whose defaults pull everything: `tesseract` without `enableLanguages` pulls ~1 GiB of language data (the desktop pins five languages).

## Home-manager activation

### "Existing file '….backup' would be clobbered"

A `.backup` from an earlier collision is in the way. Delete the stale `.backup` and switch again. For files an app keeps rewriting (e.g. `mimeapps.list`), `xdg.configFile."…".force = true` — which means home-manager owns the file outright, so every association you want must be declared.

### "two given paths contain a conflicting subpath"

The same package reached `home-manager-path` twice — typically listed in `home.packages` *and* installed by an HM module (`programs.foo`, nixcord, …). Remove the `home.packages` entry.

### A config change under `config/` doesn't show up

Check who owns the path: `readlink ~/.config/<app>`. If it isn't a link into the repo, a home-manager module (or an app) owns it. One owner per path.

## Desktop

### `hyprctl dispatch …` / `hyprctl keyword …` does nothing, or a Lua parse error

The config is Lua. Dispatchers are namespaced (`hl.dsp.*`) and legacy strings exit 0 while doing nothing — the pre-commit hook rejects them under `config/`. Runtime monitor changes don't go through `hyprctl keyword` either: edit `hyprland.lua` and `hyprctl reload`. To leave the session from a shell: `loginctl terminate-session $XDG_SESSION_ID`.

### Nothing tied to the session starts (bar, OSD, idle, udiskie)

`graphical-session.target` isn't active. The `hyprland.start` handler starts `hyprland-session.target`, which binds it. Check `systemctl --user status hyprland-session.target`; if the handler failed, the environment import line in `hyprland.lua` is the first suspect.

### Hyprland uses a lot of CPU

Check in this order:

1. **Persistent HDR.** DP-1's profile pins 10-bit + `cm = "hdr"`, which keeps the colour-management pipeline running every frame on the desktop. Remove `bitdepth`, `cm` and the luminance keys from the profile when you're not watching HDR, and pin `cm = "srgb"` — left on auto it picks a wide-gamut preset and sRGB content looks washed out.
2. **Software cursors.** `hyprctl monitors | grep hardwareCursorsInUse` should say true on every output. On NVIDIA, the working combination is `no_hardware_cursors = false` + `use_cpu_buffer = true` (what's committed).
3. **Blur and animation cost** scale with resolution × refresh; at 1440p240 blur passes are expensive.
4. Known upstream issues with the same signature: hyprwm discussion #11411, issues #7156 and #9471.

### Periodic 30–45 s freezes in video, browsers, Discord

Was sched_ext: `scx_lavd` stalled media and browser threads (`sched_ext: BPF scheduler "lavd_…" disabled (runnable task stall)` in the journal) after a kernel bump outpaced scx-scheds. That's why `services.scx.enable = false` in `modules/gaming.nix`. If you re-enable it, keep `sudo systemctl stop scx` as the escape hatch — stopping the unit hands scheduling back to the kernel immediately, no reboot.

### `pkill -x foo` / `pgrep -x foo` matches nothing

Nix wrappers rename the process: `waybar` runs as `.waybar-wrapped`, `awww-daemon` as `.awww-daemon-wr` (15-char `comm` truncation). Drop `-x`, or ask the program itself (`awww query`).

### The screen never locks

Something holds an `org.freedesktop.ScreenSaver` inhibit and keeps resetting hypridle's timer — Electron apps do it for autoplaying media (animated emoji count). Watch `journalctl --user -u hypridle -f` while idle, and check the bar's idle toggle hasn't simply stopped hypridle.

### GeForce NOW: mouse aim stops at ~180°, cursor escapes

SDL picks Wayland because the desktop profile exports `SDL_VIDEODRIVER=wayland`, and SDL2's Wayland backend can't capture the mouse. `modules/flatpak.nix` applies `--env=SDL_VIDEODRIVER=x11` for it. Don't also set `--nosocket=wayland` — then SDL finds no Wayland socket and the client aborts (error `0x80F10000`).

### A flatpak I installed disappeared

`flatpak-managed` uninstalls user apps that aren't declared. Add it to `packages` in `modules/flatpak.nix`.

## Login screen

### SDDM shows the fallback theme

In order of likelihood:

1. `metadata.desktop` must contain `QtVersion=6`. Without it SDDM 0.21 looks for the Qt 5 greeter binary, which nixpkgs doesn't ship, and falls back — right *after* logging that it loaded `theme.conf`, so that line proves nothing.
2. `services.displayManager.sddm.theme` is the theme **directory** (always `dots`, forced by the module). The palette is `dots.sddm.theme`. Setting the former to a palette name gets "theme doesn't exist".
3. Colours don't follow themectl: the greeter reads `/var/lib/dots-theme/sddm.json` over `file://`, which Qt 6 blocks unless `QML_XHR_ALLOW_FILE_READ=1` is in `GreeterEnvironment` (the module sets it when `live = true`). Setting it on the display-manager unit doesn't reach the greeter.

Cheap checks:

```fish
grep QtVersion /run/current-system/sw/share/sddm/themes/dots/metadata.desktop
cat /etc/sddm.conf.d/00-nixos.conf        # there is no /etc/sddm.conf
sudo systemctl restart display-manager    # the only full test
```

`journalctl -b` shows the current boot only — after a switch without a restart you're re-reading the old failure. Check timestamps.

## Services

### A service wrote into an empty `/mnt/…` or fails at boot

Every unit that uses an external drive should have `unitConfig.RequiresMountsFor`. Drives are `nofail` + automount, so a missing drive doesn't block boot — the dependent service just waits or fails. `dots-mounts` lists unhealthy mounts. exFAT has no permissions: if a service can't write, the fix is the mount's `uid`/`gid`/`umask` options, not `chmod`.

### A llama unit fails to start

- The GGUF isn't world-readable — the units run as `DynamicUser`.
- The model file is missing from `/data/models`.
- Another unit stopped when you started this one: expected, they `Conflict`.

`journalctl -u llama-coder -e`.

### qBittorrent / Prowlarr unreachable

They live in the `wg` namespace. Check `systemctl status wg wg-dns qbittorrent`, that `/etc/wireguard/mullvad.conf` exists, and that you're coming from the tailnet (LAN is dropped by design) or from the host via `http://192.168.15.1:8081`.

### A devshell re-downloads everything after a few days

nh's GC runs with `--keep-since 4d` and reaps direnv GC roots older than that. nh ≥ 4.4 has `--keep-one` to keep one root per direnv project regardless of age — add it to `programs.nh.clean.extraArgs` in `modules/dev.nix`.

### Changes to `scripts/themectl.sh` (or any `scripts/*.sh`) don't apply

Packaged script — `git add -A && update`.

### A theme only half-applies

A key is missing from its `colors.sh`. themectl runs under `set -u`, aborts each template with `unbound variable`, and the previous theme's files stay. Compare against a complete palette — see [Theming](theming.md#palette-format).

## Known rough edges

Things in the repo today that are wrong or brittle, not yet fixed:

| Where | Issue |
|---|---|
| `home/quickshell-rise.nix` | Hardcodes `${homeDir}/dots` instead of `config.dots.repoPath` — the bar's PATH, `DOTS_SHELL_PATH` and stop hook break on a checkout elsewhere |
| `scripts/dots-compat.sh` | `dots-update`, `dots-update-available`, `dots-updates` hardcode `~/dots` |
| `scripts/themectl.sh`, `config/zen/zen-theme-link.sh`, `scripts/claude-vm.sh` | Default to `~/dots` (overridable via `DOTS_DIR` / `SRC` / `FLAKE`, but nothing sets them from `repoPath`) |
| `home/profiles/base.nix` | `update` / `upall` assume nh, which only the NixOS host installs; on darwin and standalone home-manager they fail. The rebuild command is chosen by *profile*, so `ziad0dev@linux-desktop` (standalone HM) gets `nh os switch` |
| `scripts/dots-compat.sh` | `dots-tz-select` runs `timedatectl set-timezone`, which NixOS refuses while `time.timeZone` is set declaratively |
| `scripts/dots-compat.sh`, `modules/recording.nix` | Capture output `DP-1` hardcoded in two places |
| `home/profiles/linux-desktop.nix` | `DOCKER_HOST` hardcodes uid 1001 |
| `modules/hello-page.nix` | `Restart = always` every 5 s when `~/the-page/app.py` doesn't exist |
| `modules/ollama.nix` | `gpu-free` stops llama units but leaves Ollama's loaded model in VRAM (`ollama stop <model>` or wait 5 min) |
| `config/hyprland-preview-share-picker/config.yaml` | Rendered `share-picker.css` isn't loaded — the stylesheet line is commented out |
| `config/nvim/README.md` | Still mentions waybar, rofi and hyprlock, all since replaced |
| `scripts/themectl.sh` | The unsubstituted-token warning doesn't catch the missing-key case above |
