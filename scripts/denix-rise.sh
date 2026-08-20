RISE="${1:-$HOME/dots/config/quickshell/rise}"
[ -d "$RISE" ] || { echo "denix-rise: no such dir: $RISE" >&2; exit 1; }

files() {
    find "$RISE" -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' \
        -o -name '*.json' -o -name '*.targets' -o -name 'qs-*' \) \
        -not -path '*/.github/*'
}

sub() { files | xargs -r sed -i "s|$1|$2|g"; }

# ── paths ────────────────────────────────────────────────────────────────
# every theme/state path moves under the dots state dir
sub '\.config/omarchy/current'            '.local/state/dots/shell/current'
sub '\.config/omarchy/themes'             'dots/config/themes'
sub '\.local/share/omarchy/themes'        'dots/config/themes'
sub '\.config/omarchy/backgrounds'        'Pictures/wallpapers'
sub '\.local/share/omarchy/bin'           '.nix-profile/bin'
sub '\.local/share/omarchy'               'dots/config/quickshell/rise'
sub '\.config/omarchy/shell\.json'        '.local/state/dots/shell/shell.json'
sub '\.config/omarchy/hooks'              '.local/state/dots/shell/hooks'
sub '\.config/omarchy'                    '.local/state/dots/shell'

# the vendored config lives at quickshell/rise, not quickshell/bar
sub '\.config/quickshell/bar'             '.config/quickshell/rise'

# palettes are shell assignments, not toml
sub 'colors\.toml'                        'colors.sh'

# ── external binaries ────────────────────────────────────────────────────
sub '"makoctl"'                           '"dunstctl"'
sub 'omarchy-'                            'dots-'

# ── identifiers and branding ─────────────────────────────────────────────
sub 'OmarchyPower'                        'DotsPower'
sub 'omarchyCurrentRoot'                  'dotsStateRoot'
sub 'omarchyInstallRoot'                  'dotsShellRoot'
sub 'omarchyCurrentRootResolved'          'dotsStateRootResolved'
sub 'Omarchy is installed but its update command is unavailable' \
    'nh is unavailable'
sub 'Omarchy update available'            'NixOS rebuild available'
sub 'Omarchy updater missing'             'nh not found'
sub 'Open Omarchy update'                 'Open NixOS rebuild'
sub '"Omarchy"'                           '"NixOS"'
sub 'Omarchy'                             'NixOS'
sub 'omarchy'                             'dots'

# environment variable names
sub 'OMARCHY_SCREENRECORD_DIR'            'DOTS_SCREENRECORD_DIR'
sub 'OMARCHY_SCREENSHOT_DIR'              'DOTS_SCREENSHOT_DIR'
sub 'OMARCHY_PATH'                        'DOTS_SHELL_PATH'
sub 'OMARCHY'                             'DOTS'

# both variant trees carry their own copy; renaming only the top-level one
# leaves V2's BrightnessWidget importing a file that no longer exists
find "$RISE" -name 'OmarchyPower.js' -type f | while read -r f; do
    mv -f "$f" "$(dirname "$f")/DotsPower.js"
done

# ── Arch package manager -> nix ──────────────────────────────────────────
sub 'checkupdates'                        'dots-updates'
sub '\bpacman -Qu\b'                      'dots-updates'
sub '\bpacman -Sy\b'                      'true'
sub '\bpacman -Q\b'                       'dots-updates'
sub '\bpacman\b'                          'dots-updates'

# ── UI labels that named Arch concepts ───────────────────────────────────
sub '"Package"'                           '"Generation"'
sub '"Arch Updates"'                      '"NixOS Generations"'

# ── wallpapers ───────────────────────────────────────────────────────────
# upstream kept a per-theme background dir; you keep one flat wallpapers dir,
# so the rewritten path must not gain a /<themeName> suffix
sub '"/Pictures/wallpapers/" + currentThemeName' '"/Pictures/wallpapers"'

# ── launcher logo ────────────────────────────────────────────────────────
# The official NixOS wordmark, tinted to the theme accent by the existing
# logo-tint shader. assets/nixos-logo.svg must be downloaded first:
#   curl -Lo assets/nixos-logo.svg \
#     https://brand.nixos.org/logos/nixos-logo-white-flat-white-regular-horizontal-recommended.svg
for f in "$RISE/modules/LauncherWidget.qml" "$RISE/variants/V2/modules/LauncherWidget.qml"; do
    [ -f "$f" ] || continue
    grep -q 'nixosTextLogo' "$f" || sed -i \
        's|readonly property bool hyprlandLogo:|readonly property bool nixosTextLogo: !logoIconMode \&\& root.launcherLogoText === "nixos"\n    readonly property bool hyprlandLogo:|' "$f"
    # bob2.png was the "dots" fallback and denix deletes it, so point the
    # default at the NixOS mark instead of a file that no longer exists
    # PNG rather than SVG: upstream's own assets are all raster, so qtsvg may
    # not be in the quickshell closure. 647x192 tight crop of the wordmark.
    sed -i 's|Qt.resolvedUrl("../assets/bob2.png")|Qt.resolvedUrl("../assets/nixos-logo.png")|g' "$f"
    sed -i 's|hyprlandLogo ? (948 / 154) : (656 / 192)|hyprlandLogo ? (948 / 154) : (647 / 192)|' "$f"
done

for th in "$RISE/Theme.qml" "$RISE/variants/V2/Theme.qml"; do
    [ -f "$th" ] || continue
    sed -i 's|readonly property var launcherLogoTextOptions: \["dots", "hyprland", "arch", "omacom"\]|readonly property var launcherLogoTextOptions: ["nixos", "hyprland", "arch"]|' "$th"
done

# ── launcher logo: the bundled wordmark PNG is Omarchy branding ──────────
# icon mode + the nix glyph avoids shipping someone else's logo
sub 'property string launcherLogoMode: "icon"'   'property string launcherLogoMode: "text"'
sub 'property string launcherLogoText: "dots"'   'property string launcherLogoText: "nixos"'
sub 'property string launcherLogoIcon: "dots"'   'property string launcherLogoIcon: "nix"'

# the bundled nix glyph is a Nerd Font codepoint that moved between NF v2 and
# v3; Material Symbols is already a dependency and always has this one
files | xargs -r sed -i \
    -e 's|if (id === "nix") return "\xef\x8c\x8c"|if (id === "nix") return "ac_unit"|' \
    -e 's|return id === "dots" ? "dots" : mono|return id === "dots" ? "dots" : (id === "nix" ? "Material Symbols Rounded" : mono)|'


# drop the branded image assets entirely
rm -rf "$RISE/.github" "$RISE/.gitignore"
rm -f "$RISE/assets/omacom-text.png" "$RISE/assets/bob2.png" "$RISE/assets/bob3.png"

# ── app launcher ─────────────────────────────────────────────────────────
# upstream has no drun (zero DesktopEntries uses); AppLauncher.qml adds one.
# Mount it in both variant roots and give Theme a visibility property.
for vr in "$RISE/VariantRoot.qml" "$RISE/variants/V2/VariantRoot.qml"; do
    [ -f "$vr" ] || continue
    grep -q 'AppLauncher' "$vr" || sed -i \
        's|^\(\s*\)LazyLoader { active: theme.pickerStyle === "carousel";\(.*\)$|\1LazyLoader { active: theme.pickerStyle === "carousel";\2\n\1LazyLoader { active: true; AppLauncher { root: theme } }|' "$vr"
done

for th in "$RISE/Theme.qml" "$RISE/variants/V2/Theme.qml"; do
    [ -f "$th" ] || continue
    grep -q 'appLauncherVisible' "$th" || sed -i \
        's|^\(\s*\)property string launcherLogoMode:|\1property bool appLauncherVisible: false\n\1property string launcherLogoMode:|' "$th"
done

# expose it on the variant root so IpcRouter.invoke() can reach it
for vr in "$RISE/VariantRoot.qml" "$RISE/variants/V2/VariantRoot.qml"; do
    [ -f "$vr" ] || continue
    if grep -q 'toggleAppLauncher' "$vr"; then
        sed -i 's|function toggleAppLauncher() {.*}|function toggleAppLauncher() { if (!theme.appLauncherVisible) theme.activateFocusedPopupScreen(); theme.appLauncherVisible = !theme.appLauncherVisible }|' "$vr"
    else
        sed -i '0,/^\(\s*\)id: root$/s||\1id: root\n\n\1function toggleAppLauncher() { if (!theme.appLauncherVisible) theme.activateFocusedPopupScreen(); theme.appLauncherVisible = !theme.appLauncherVisible }|' "$vr"
    fi
done

# ipc target: qs -c rise ipc call launcher toggle
IPC="$RISE/core/IpcRouter.qml"
if [ -f "$IPC" ] && ! grep -q 'target: "launcher"' "$IPC"; then
    awk '
        /^}/ && !seen {
            print "    IpcHandler {"
            print "        target: \"launcher\""
            print "        function toggle(): void { router.invoke(\"toggleAppLauncher\") }"
            print "    }"
            print ""
            seen = 1
        }
        { print }
    ' "$IPC" >"$IPC.tmp" && mv -f "$IPC.tmp" "$IPC"
fi

# the widget cache stores the launcher logo choice and overrides the default
# above, so a stale cache keeps showing the old wordmark
rm -f "$HOME/.cache/quickshell_widgets" "$HOME/.cache/quickshell_splits"

# ── your own files outside the vendored tree ─────────────────────────────
DOTS="$(cd "$RISE/../../.." && pwd)"
if [ -d "$DOTS/config/themes" ]; then
    sed -i 's|# Auto-converted from Omarchy theme|# base16 palette|' "$DOTS"/config/themes/*/colors.sh
fi
if [ -f "$DOTS/config/hypr/hyprland.lua" ]; then
    sed -i -e '/omarchy does the same/d' -e '/require_optional.module("omarchy/d' \
        -e 's|-- Current theme overrides, loaded last so they win (|-- Current theme overrides, loaded last so they win.|' \
        "$DOTS/config/hypr/hyprland.lua"
fi
if [ -d "$DOTS/config/quickshell/picker" ]; then
    sed -i -e 's|Legacy Omarchy colorN keys|Legacy colorN keys|' \
        -e 's|Omarchy colors.toml values|Palette values|' \
        "$DOTS"/config/quickshell/picker/*.js
fi

echo "denix-rise: rewrote $(files | wc -l) files under $RISE"
echo "remaining mentions: $(grep -ril omarchy "$RISE" 2>/dev/null | wc -l) files"
