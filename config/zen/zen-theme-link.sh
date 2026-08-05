#!/usr/bin/env bash
# Link the oxocarbon chrome into every Zen profile and enable custom CSS.
#
# Zen profile roots differ per channel (.zen, .zen-beta, .zen-twilight, flatpak
# paths) and profile DIRECTORY names are generated, so nothing here is
# hardcoded: candidate roots are probed, then profiles.ini is parsed for the
# authoritative Path= entries. Re-runnable.
#
#   ROOT=/explicit/path bash zen-theme-link.sh    # override discovery
set -euo pipefail

SRC="${SRC:-$HOME/dots/config/zen}"

# ── 1. locate the profile root ──────────────────────────────────────────────
roots=()
if [[ -n "${ROOT:-}" ]]; then
  roots=("$ROOT")
else
  for c in "$HOME/.zen-beta" "$HOME/.zen" "$HOME/.zen-twilight" \
           "$HOME/.var/app/io.github.zen_browser.zen/.zen" \
           "$HOME/.mozilla/zen"; do
    [[ -f "$c/profiles.ini" ]] && roots+=("$c")
  done
  # Last resort: search for any zen-ish profiles.ini
  if (( ${#roots[@]} == 0 )); then
    while IFS= read -r p; do roots+=("$(dirname "$p")"); done < <(
      find "$HOME" -maxdepth 5 -name profiles.ini -ipath "*zen*" 2>/dev/null)
  fi
fi

if (( ${#roots[@]} == 0 )); then
  echo "!! No Zen profiles.ini found. Checked:"
  echo "     ~/.zen-beta  ~/.zen  ~/.zen-twilight  flatpak  ~/.mozilla/zen"
  echo "   Launch Zen once and quit it fully, then re-run."
  echo "   Or locate it yourself and pass it:"
  echo "     find \$HOME -maxdepth 5 -name profiles.ini"
  echo "     ROOT=/that/dir bash \$0"
  exit 1
fi

# ── 2. parse profiles.ini for real profile paths ────────────────────────────
linked=0
for root in "${roots[@]}"; do
  echo "==> $root"
  ini="$root/profiles.ini"

  # Path= may be relative to root (IsRelative=1) or absolute.
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if [[ "$path" = /* ]]; then prof="$path"; else prof="$root/$path"; fi
    [[ -d "$prof" ]] || { echo "   skip (missing): $path"; continue; }

    mkdir -p "$prof/chrome"
    ln -sfn "$SRC/userChrome.css"  "$prof/chrome/userChrome.css"
    ln -sfn "$SRC/userContent.css" "$prof/chrome/userContent.css"

    # user.js is re-applied at every startup; prefs.js gets rewritten on exit.
    touch "$prof/user.js"
    grep -q 'toolkit.legacyUserProfileCustomizations.stylesheets' "$prof/user.js" \
      || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$prof/user.js"

    echo "   linked  $path"
    ((linked++))
  done < <(grep -i '^Path=' "$ini" | cut -d= -f2-)
done

if (( linked == 0 )); then
  echo "!! profiles.ini found but no profile directories exist yet."
  echo "   Launch Zen once and quit it fully, then re-run."
  exit 1
fi

echo
echo "Linked $linked profile(s). Fully quit and relaunch Zen — chrome CSS is"
echo "read once at startup, so a window reload will not pick it up."
