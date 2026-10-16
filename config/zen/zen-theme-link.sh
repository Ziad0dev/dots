#!/usr/bin/env bash

set -euo pipefail

# the directory this script lives in: the checkout or the store, whichever is linked
SRC="${SRC:-$(dirname "$(readlink -f "$0")")}"
THEME="${XDG_STATE_HOME:-$HOME/.local/state}/dots/theme"

roots=()
if [[ -n "${ROOT:-}" ]]; then
  roots=("$ROOT")
else
  # newer Zen keeps profiles under XDG config; older ones in ~/.zen*
  for c in "${XDG_CONFIG_HOME:-$HOME/.config}/zen" \
           "$HOME/.zen-beta" "$HOME/.zen" "$HOME/.zen-twilight" \
           "$HOME/.var/app/io.github.zen_browser.zen/.zen" \
           "$HOME/.mozilla/zen"; do
    [[ -f "$c/profiles.ini" ]] && roots+=("$c")
  done

  if (( ${#roots[@]} == 0 )); then
    while IFS= read -r p; do roots+=("$(dirname "$p")"); done < <(
      find "$HOME" -maxdepth 5 -name profiles.ini -ipath "*zen*" 2>/dev/null)
  fi
fi

if (( ${#roots[@]} == 0 )); then
  echo "!! No Zen profiles.ini found. Checked:"
  echo "     ~/.config/zen  ~/.zen-beta  ~/.zen  ~/.zen-twilight  flatpak  ~/.mozilla/zen"
  echo "   Launch Zen once and quit it fully, then re-run."
  echo "   Or locate it yourself and pass it:"
  echo "     find \$HOME -maxdepth 5 -name profiles.ini"
  echo "     ROOT=/that/dir bash \$0"
  exit 1
fi

linked=0
for root in "${roots[@]}"; do
  echo "==> $root"
  ini="$root/profiles.ini"

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if [[ "$path" = /* ]]; then prof="$path"; else prof="$root/$path"; fi
    [[ -d "$prof" ]] || { echo "   skip (missing): $path"; continue; }

    mkdir -p "$prof/chrome"
    ln -sfn "$SRC/userChrome.css"  "$prof/chrome/userChrome.css"
    ln -sfn "$SRC/userContent.css" "$prof/chrome/userContent.css"
    ln -sfn "$THEME/zen-palette.css" "$prof/chrome/dots-palette.css"
    ln -sfn "$THEME/zen-sites.css"   "$prof/chrome/dots-sites.css"
    ln -sfn "$THEME/zen-desktop-theme.css" "$prof/chrome/dots-desktop-theme.css"

    touch "$prof/user.js"
    grep -q 'toolkit.legacyUserProfileCustomizations.stylesheets' "$prof/user.js" \
      || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$prof/user.js"
    # transparent window so Hyprland's blur shows through the chrome
    grep -q 'zen.widget.linux.transparency' "$prof/user.js" \
      || echo 'user_pref("zen.widget.linux.transparency", true);' >> "$prof/user.js"
    # web content may be transparent too: Zen Internet clears a page's
    # backgrounds so the themed browser background shows through. Off, those
    # pages fall back to a white canvas (what the Transparent Zen mod's
    # "Allow zen browser to be transparent" turns on)
    grep -q 'browser.tabs.allow_transparent_browser' "$prof/user.js" \
      || echo 'user_pref("browser.tabs.allow_transparent_browser", true);' >> "$prof/user.js"

    echo "   linked  $path"
    linked=$((linked + 1))
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
