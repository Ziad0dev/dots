#!/usr/bin/env bash
# Reorganize ~/dots from a flat root into folders.
#
#   hosts/nixos/   configuration.nix + hardware-configuration.nix
#   modules/       NixOS system modules (imported by flake.nix)
#   home/          home-manager modules (home.nix + its imports)
#   config/        dotfile dirs symlinked into ~/.config
#   templates/     unchanged
#
# Uses `git mv` for tracked files so history follows them, plain `mv` for
# untracked ones (storage.nix and yazi/ are untracked on this machine).
# Then patches every path reference in flake.nix, home/home.nix, home/emacs.nix.
#
# Run from inside ~/dots. Idempotent-ish: skips anything already moved.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
echo "==> repo: $(pwd)"

# ---------------------------------------------------------------- safety
if [ -n "$(git status --porcelain)" ]; then
    echo
    echo "!! Working tree is not clean:"
    git status --short | sed 's/^/     /'
    echo
    echo "   The move itself is safe, but commit first if you want a clean"
    echo "   before/after diff. Ctrl-C to bail, Enter to continue."
    read -r _
fi

BEFORE_COUNT=$(git ls-files | wc -l)

mkdir -p hosts/nixos modules home config

# ------------------------------------------------------------------ move
move() {  # move <src> <dstdir>
    local src="$1" dst="$2"
    [ -e "$src" ] || { echo "    skip (absent): $src"; return 0; }
    [ -e "$dst/$(basename "$src")" ] && { echo "    skip (already there): $src"; return 0; }
    if git ls-files --error-unmatch "$src" >/dev/null 2>&1; then
        git mv "$src" "$dst/"
        echo "    git mv  $src -> $dst/"
    else
        mv "$src" "$dst/"
        echo "    mv      $src -> $dst/   (untracked)"
    fi
}

echo "==> hosts/"
for f in configuration.nix hardware-configuration.nix; do move "$f" hosts/nixos; done

echo "==> modules/"
for f in audio.nix davinci.nix dev.nix gaming.nix gaming-extras.nix llm.nix \
         media.nix mullvad.nix recording.nix storage.nix virt.nix \
         waybar-lua-fix.nix; do
    move "$f" modules
done

echo "==> home/"
for f in home.nix dev-home.nix emacs.nix gaming-home.nix virt-home.nix; do
    move "$f" home
done

echo "==> config/"
for d in hypr waybar dunst rofi ghostty nvim flameshot gammastep ranger \
         broot rmpc yazi emacs mpd mpdscribble; do
    move "$d" config
done

# ----------------------------------------------------------------- patch
echo "==> patching path references"
python3 - <<'PYEOF'
import re, sys, pathlib

def patch(path, subs, required=True):
    p = pathlib.Path(path)
    if not p.exists():
        print(f"    skip (absent): {path}")
        return
    s = orig = p.read_text(encoding="utf-8")
    for old, new in subs:
        if old not in s:
            if required and new not in s:
                print(f"    !! not found in {path}: {old!r}")
            continue
        s = s.replace(old, new)
    if s != orig:
        p.write_text(s, encoding="utf-8")
        print(f"    patched {path}")
    else:
        print(f"    unchanged {path}")

# ---- flake.nix: module paths ----
mods = ["audio", "davinci", "dev", "gaming", "gaming-extras", "llm", "media",
        "mullvad", "recording", "storage", "virt", "waybar-lua-fix"]
subs = [("./configuration.nix", "./hosts/nixos/configuration.nix"),
        ("./hardware-configuration.nix", "./hosts/nixos/hardware-configuration.nix"),
        ("import ./home.nix", "import ./home/home.nix")]
# longest first so ./gaming.nix doesn't eat ./gaming-extras.nix
for m in sorted(mods, key=len, reverse=True):
    subs.append((f"./{m}.nix", f"./modules/{m}.nix"))
patch("flake.nix", subs, required=False)

# ---- home/home.nix: the symlink helper now points into config/ ----
patch("home/home.nix", [
    ('link = sub: config.lib.file.mkOutOfStoreSymlink "${dotsPath}/${sub}"',
     'link = sub: config.lib.file.mkOutOfStoreSymlink "${dotsPath}/config/${sub}"'),
])

# ---- home/emacs.nix: absolute path to init.el ----
patch("home/emacs.nix", [("/dots/emacs/init.el", "/dots/config/emacs/init.el")])

# ---- config/emacs/init.el: custom-theme-load-path is a REAL path, not a comment
patch("config/emacs/init.el", [('"~/dots/emacs/themes/"', '"~/dots/config/emacs/themes/"')])
PYEOF

# ------------------------------------------------- duplicate import fix
python3 - <<'PYEOF'
import pathlib
p = pathlib.Path("home/home.nix")
if p.exists():
    s = p.read_text(encoding="utf-8")
    dup = "    ./virt-home.nix\n"
    if s.count(dup) > 1:
        head, sep, tail = s.partition(dup)
        s = head + sep + tail.replace(dup, "", 1)
        p.write_text(s, encoding="utf-8")
        print("    removed duplicate ./virt-home.nix import")
PYEOF

# ------------------------------------------------------------------ done
git add -A
echo
echo "==> tracked files: $BEFORE_COUNT -> $(git ls-files | wc -l)  (should match)"
echo "==> new layout:"
find . -maxdepth 2 -not -path './.git*' -not -name '.' | sort | sed 's/^/    /'
echo
echo "Next:"
echo "    git status --short          # renames, not delete+add"
echo "    nh os switch                # or: sudo nixos-rebuild switch --flake ~/dots#nixos"
echo "    git commit -m 'reorganize into folders'"
