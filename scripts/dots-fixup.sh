#!/usr/bin/env bash
# One-shot, idempotent. Safe to re-run; each fix checks its own precondition.
#   bash scripts/dots-fixup.sh [~/dots]
set -uo pipefail

DOTS="${1:-$HOME/dots}"
cd "$DOTS" || { echo "dots-fixup: no such dir: $DOTS" >&2; exit 1; }

n=0
did() { printf '  \033[32mfixed\033[0m %s\n' "$1"; n=$((n + 1)); }
skip() { printf '  \033[90mskip \033[0m %s\n' "$1"; }
sec() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# ── ghostty ──────────────────────────────────────────────────────────────
sec "ghostty"
f=config/ghostty/config
if grep -q 'config-file = ?"' "$f"; then
    sed -i 's|config-file = ?"\(.*\)"|config-file = ?\1|' "$f"
    did "$f: unquoted the optional config-file path (quotes are the ?-escape)"
else
    skip "$f: config-file already unquoted"
fi
if grep -q 'Oxcarbon' "$f"; then
    sed -i 's/Oxcarbon/Oxocarbon/' "$f"
    did "$f: Oxcarbon -> Oxocarbon"
else
    skip "$f: spelling ok"
fi
if grep -q '[[:space:]]$' "$f"; then
    sed -i 's/[[:space:]]*$//' "$f"
    did "$f: stripped trailing whitespace"
else
    skip "$f: no trailing whitespace"
fi

# ── hyprland ─────────────────────────────────────────────────────────────
sec "hyprland"
f=config/hypr/hyprland.lua
if grep -q 'hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))' "$f"; then
    sed -i 's|hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))|hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("hyprctl reload"))|' "$f"
    did "$f: SUPER+SHIFT+R was bound twice; reload moved to SUPER+CTRL+R"
else
    skip "$f: SUPER+SHIFT+R not double-bound"
fi
if grep -q 'hyprctl keyword general:layout' "$f"; then
    sed -i '/hyprctl keyword general:layout/d' "$f"
    did "$f: dropped SUPER+S / SUPER+W (hyprctl keyword is unavailable under the Lua config)"
else
    skip "$f: no hyprctl keyword binds"
fi
if grep -q 'swallow_regex *= *"\^(ghostty)\$"' "$f"; then
    sed -i 's|swallow_regex\( *\)= "\^(ghostty)\$"|swallow_regex\1= "^(com\\\\.mitchellh\\\\.ghostty)$"|' "$f"
    did "$f: swallow_regex -> com.mitchellh.ghostty (the real Wayland app-id)"
else
    skip "$f: swallow_regex already correct"
fi
if grep -q 'sligshot' "$f"; then
    sed -i 's/sligshot/slingshot/' "$f"
    did "$f: curve sligshot -> slingshot"
else
    skip "$f: curve names ok"
fi

# ── ranger ───────────────────────────────────────────────────────────────
sec "ranger"
if grep -q '^set colorscheme pywal_dynamic' config/ranger/rc.conf; then
    sed -i 's/^set colorscheme pywal_dynamic/set colorscheme default/' config/ranger/rc.conf
    did "rc.conf: colorscheme -> default (pywal_dynamic.py is an unrendered template)"
else
    skip "rc.conf: colorscheme already default"
fi
if [ -f config/ranger/colorschemes/pywal_dynamic.py ]; then
    git rm -q --ignore-unmatch config/ranger/colorschemes/pywal_dynamic.py 2>/dev/null \
        || rm -f config/ranger/colorschemes/pywal_dynamic.py
    did "removed config/ranger/colorschemes/pywal_dynamic.py (NameError on every import)"
else
    skip "pywal_dynamic.py already gone"
fi
if [ -d config/ranger/colorschemes/__pycache__ ]; then
    git rm -rq --ignore-unmatch config/ranger/colorschemes/__pycache__ 2>/dev/null
    rm -rf config/ranger/colorschemes/__pycache__
    did "removed committed __pycache__ (7 .pyc across cpython-312/313/314)"
else
    skip "__pycache__ already gone"
fi

# ── .gitignore ───────────────────────────────────────────────────────────
sec ".gitignore"
if grep -qx 'mpd/database' .gitignore; then
    sed -i 's|^mpd/|config/mpd/|' .gitignore
    did ".gitignore: mpd/* -> config/mpd/* (mid-pattern slash anchors to repo root)"
else
    skip ".gitignore: mpd paths already anchored"
fi
if ! grep -q '__pycache__' .gitignore; then
    printf '__pycache__/\n*.pyc\n' >>.gitignore
    did ".gitignore: added __pycache__/ and *.pyc"
else
    skip ".gitignore: pycache already ignored"
fi

# ── stale unreferenced config dirs ───────────────────────────────────────
sec "stale config dirs"
for d in config/mpd config/mpdscribble; do
    if [ -d "$d" ]; then
        git rm -rq --ignore-unmatch "$d" 2>/dev/null
        rm -rf "$d"
        did "removed $d (home-manager generates this; nothing links it)"
    else
        skip "$d already gone"
    fi
done

# ── dots-compat shims ────────────────────────────────────────────────────
sec "dots-compat"
f=scripts/dots-compat.sh
if ! grep -q '^    dots-updates)' "$f"; then
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "    dots-weather | dots-weather-status)"
block = """    dots-updates)
        # pending-update count, same signal dots-update-available reports
        lock="$HOME/dots/flake.lock"
        if [ -f "$lock" ]; then
            age=$(( ( $(date +%s) - $(stat -c %Y "$lock") ) / 86400 ))
            [ "$age" -gt 7 ] && echo 1 || echo 0
        else
            echo 0
        fi
        exit 0
        ;;

"""
s = s.replace(anchor, block + anchor, 1)
open(p, "w").write(s)
PY
    did "$f: added the dots-updates branch (shim existed but fell through to exit 0)"
else
    skip "$f: dots-updates branch present"
fi
if grep -q 'pkill hypridle' "$f"; then
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """        if pgrep hypridle >/dev/null 2>&1; then
            pkill hypridle
            echo "off"
        else
            hypridle &
            echo "on"
        fi"""
new = """        if systemctl --user is-active --quiet hypridle.service; then
            systemctl --user stop hypridle.service
            echo "off"
        else
            systemctl --user start hypridle.service
            echo "on"
        fi"""
s = s.replace(old, new, 1)
open(p, "w").write(s)
PY
    did "$f: dots-toggle-idle now drives the systemd unit instead of racing its Restart="
else
    skip "$f: dots-toggle-idle already unit-based"
fi

# ── quickshell-rise.nix ──────────────────────────────────────────────────
sec "quickshell-rise.nix"
f=home/quickshell-rise.nix
if ! grep -q '^      fzf$' "$f"; then
    sed -i '0,/^      curl$/s//      curl\n      fzf/' "$f"
    did "$f: added fzf to compatBase runtimeInputs (dots-tz-select pipes through it)"
else
    skip "$f: fzf present"
fi
if grep -q '"dots-cli"' "$f"; then
    sed -i '/^    "dots-cli"$/d' "$f"
    did "$f: dropped the dots-cli shim (no branch, no caller)"
else
    skip "$f: dots-cli already gone"
fi

# ── qs-barctl path ───────────────────────────────────────────────────────
sec "qs-barctl"
OLDBARCTL='config/quickshell/'"bin"'/qs-barctl'
NEWBARCTL='config/quickshell/rise/scripts/qs-barctl'
# only config/quickshell is rewritten: scripts/denix-rise.sh and this file both
# carry the old path as a literal PATTERN and must keep it.
if grep -rqlF "$OLDBARCTL" config/quickshell 2>/dev/null; then
    grep -rlF "$OLDBARCTL" config/quickshell \
        | xargs -r sed -i "s|$OLDBARCTL|$NEWBARCTL|g"
    did "repointed qs-barctl to rise/scripts/ (there is no bin/ dir; the switcher was dead)"
else
    skip "qs-barctl path already correct"
fi
if ! grep -q 'quickshell/bin/qs-barctl' scripts/denix-rise.sh; then
    python3 - <<'PY'
p = "scripts/denix-rise.sh"
s = open(p).read()
anchor = "# palettes are shell assignments, not toml"
old = ".config/quickshell/" + "bin" + "/qs-barctl"
add = ("# upstream ships qs-barctl in scripts/, but references it under bin/\n"
       "sub '\\" + old + "'  '.config/quickshell/rise/scripts/qs-barctl'\n\n")
if add not in s:
    s = s.replace(anchor, add + anchor, 1)
    open(p, "w").write(s)
PY
    did "denix-rise.sh: added the qs-barctl sub so a re-vendor keeps the fix"
else
    skip "denix-rise.sh: qs-barctl sub present"
fi

# ── dead ArchUpdater leftover ────────────────────────────────────────────
sec "dead vendored code"
f=config/quickshell/rise/core/qs-system-update.sh
if [ -f "$f" ]; then
    git rm -q --ignore-unmatch "$f" 2>/dev/null || rm -f "$f"
    did "removed $f (ArchUpdater backend; no caller, and 'local dots-updates' is not a valid identifier)"
else
    skip "qs-system-update.sh already gone"
fi

# ── configuration.nix ────────────────────────────────────────────────────
sec "hosts/nixos/configuration.nix"
f=hosts/nixos/configuration.nix
if grep -A3 'services.flaresolverr' "$f" | grep -q 'openFirewall = true'; then
    python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"(services\.flaresolverr = \{[^}]*?openFirewall = )true", r"\1false", s, count=1, flags=re.S)
open(p, "w").write(s)
PY
    did "$f: flaresolverr openFirewall -> false (unauthenticated fetch-any-URL proxy)"
else
    skip "$f: flaresolverr not exposed"
fi
if grep -q '^  services.resolved.enable = true;$' "$f"; then
    sed -i '0,/^  services.resolved.enable = true;$/{/^  services.resolved.enable = true;$/d}' "$f"
    did "$f: dropped duplicate services.resolved.enable (modules/mullvad.nix owns it)"
else
    skip "$f: no duplicate resolved"
fi
if grep -qn '^ $' "$f"; then
    sed -i 's/^[[:space:]]\+$//' "$f"
    did "$f: cleared whitespace-only line"
else
    skip "$f: no whitespace-only lines"
fi

# ── claude-vm ────────────────────────────────────────────────────────────
sec "hosts/claude-vm"
f=hosts/claude-vm/default.nix
if ! grep -q 'host.address' "$f"; then
    sed -i 's|^\( *\)host\.port = \([0-9]*\);|\1host.address = "127.0.0.1";\n\1host.port = \2;|' "$f"
    did "$f: forwarded ports bound to 127.0.0.1 (QEMU defaults to 0.0.0.0; guest is dev/dev + NOPASSWD sudo)"
else
    skip "$f: ports already bound to loopback"
fi

# ── storage.nix uid ──────────────────────────────────────────────────────
sec "modules/storage.nix"
f=modules/storage.nix
if grep -q '"uid=1001"' "$f"; then
    sed -i 's|^{ pkgs, \.\.\. }:|{\n  config,\n  pkgs,\n  username,\n  ...\n}:|' "$f"
    # shellcheck disable=SC2016  # the ${...} is nix syntax, not shell
    sed -i 's|"uid=1001"|"uid=${toString config.users.users.${username}.uid}"|' "$f"
    did "$f: uid derived from the user like media.nix does, instead of a hardcoded 1001"
else
    skip "$f: uid already derived"
fi

# ── dev-home.nix duplicate linters ───────────────────────────────────────
sec "home/dev-home.nix"
f=home/dev-home.nix
if grep -q '^    statix$' "$f" && grep -q 'statix' home/git-hooks.nix; then
    sed -i '/^    statix$/d;/^    deadnix$/d' "$f"
    did "$f: dropped statix/deadnix (home/git-hooks.nix already installs them)"
else
    skip "$f: no duplicate linters"
fi

# ── dots-audit.sh module check ───────────────────────────────────────────
sec "scripts/dots-audit.sh"
f=scripts/dots-audit.sh
# shellcheck disable=SC2016  # matching a literal shell snippet inside dots-audit.sh
if grep -q 'case "$f" in home/home.nix|modules/\*) continue ;; esac' "$f"; then
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '''    case "$f" in home/home.nix|modules/*) continue ;; esac
    if ! grep -qF "$base" home/home.nix 2>/dev/null; then
        warn "$f is not imported by home/home.nix (dead module?)"
    fi'''
new = '''    case "$f" in home/home.nix) continue ;; esac
    case "$f" in
        modules/*)
            grep -qF "./$f" flake.nix 2>/dev/null \\
                || warn "$f is not imported by flake.nix (dead module?)" ;;
        *)
            grep -qF "$base" home/home.nix 2>/dev/null \\
                || warn "$f is not imported by home/home.nix (dead module?)" ;;
    esac'''
s = s.replace(old, new, 1)
open(p, "w").write(s)
PY
    did "$f: module-wiring check no longer skips modules/ entirely"
else
    skip "$f: module check already covers modules/"
fi

# ── emacs theme typo ─────────────────────────────────────────────────────
sec "typos"
f=config/emacs/themes/oxocarbon-theme.el
if grep -q 'selction' "$f"; then
    sed -i 's/selction/selection/' "$f"
    did "$f: selction -> selection"
else
    skip "$f: spelling ok"
fi
f=home/home.nix
if grep -q 'source  = link' "$f"; then
    sed -i 's/source  = link/source = link/' "$f"
    did "$f: collapsed double space in the quickshell link"
else
    skip "$f: no double space"
fi

# ── dots-finalize.sh SC2015 ──────────────────────────────────────────────
sec "scripts/dots-finalize.sh"
f=scripts/dots-finalize.sh
if grep -qF 'h:-}" ] || { w=647' "$f"; then
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '    [ -n "${w:-}" ] && [ -n "${h:-}" ] || { w=647; h=192; }'
new = '    if [ -z "${w:-}" ] || [ -z "${h:-}" ]; then w=647; h=192; fi'
open(p, "w").write(s.replace(old, new, 1))
PY
    did "$f: A && B || C rewritten as if/then (SC2015 — C also runs when A is true)"
else
    skip "$f: no SC2015 pattern"
fi

printf '\n\033[1mdots-fixup: %d change(s) applied\033[0m\n' "$n"
[ "$n" -gt 0 ] && echo "next: git add -A && nh os switch"
exit 0
