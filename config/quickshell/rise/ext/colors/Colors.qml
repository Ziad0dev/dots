pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Palette.js" as Palette

// The Material 3 roles the ported dhrruvsharma/shell code reads (upstream
// fills them from matugen's Colors.json), derived here from the dots theme's
// colors.sh instead, so every ported panel wears the current rise theme: the
// window-border red is the primary, color3 a dimmed gilt tertiary, and the
// surfaces are the background lifted a little towards the foreground.
// Read straight from the file (not from Theme.qml) so the separate lock
// screen instance gets the same colours.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/state/dots/shell/current/theme/colors.sh"
    readonly property var raw: Palette.parseAll(colorsFile.text())

    function pick(keys, fallback) {
        for (let i = 0; i < keys.length; i++) {
            const v = raw[keys[i]];
            if (Palette.validColor(v))
                return v.substring(0, 7);
        }
        return fallback;
    }
    function mix(a, b, t) {
        const x = Qt.color(a), y = Qt.color(b);
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1).toString();
    }
    function onColor(c) {
        const l = Palette.luminance(Palette.hexRgb(Qt.color(c).toString()));
        return l > 0.32 ? mix(bg, "#000000", 0.4) : fg;
    }

    readonly property string bg: pick(["background", "bg"], "#0b0a0a")
    readonly property string fg: pick(["foreground", "fg"], "#d8d2c4")
    readonly property string red: pick(["border", "color1", "red"], "#c42b2b")
    readonly property string gold: mix(pick(["color3", "yellow"], "#c8a24a"), bg, 0.28)
    readonly property string bone: pick(["color7"], mix(fg, bg, 0.18))
    readonly property string muted: {
        const m = pick(["color8"], "");
        return m ? Palette.readable(m, bg, fg, 4.5) : mix(fg, bg, 0.4);
    }

    property string background:                bg
    property string surface:                   bg
    property string surface_dim:               bg
    property string surface_container_lowest:  mix(bg, "#000000", 0.35)
    property string surface_container_low:     mix(bg, fg, 0.035)
    property string surface_container:         mix(bg, fg, 0.06)
    property string surface_container_high:    mix(bg, fg, 0.09)
    property string surface_container_highest: mix(bg, fg, 0.13)
    property string surface_bright:            mix(bg, fg, 0.17)
    property string surface_variant:           mix(bg, fg, 0.13)
    property string surface_tint:              red

    property string on_background:      fg
    property string on_surface:         fg
    property string on_surface_variant: muted
    property string outline:            mix(bg, fg, 0.38)
    property string outline_variant:    mix(bg, fg, 0.18)
    property string inverse_surface:    fg
    property string inverse_on_surface: bg
    property string inverse_primary:    mix(red, bg, 0.45)
    property string scrim:              "#000000"
    property string shadow:             "#000000"
    property string source_color:       red

    property string primary:                  red
    property string on_primary:               onColor(red)
    property string primary_container:        mix(bg, red, 0.32)
    property string on_primary_container:     mix(red, fg, 0.65)
    property string primary_fixed:            mix(red, fg, 0.55)
    property string primary_fixed_dim:        red
    property string on_primary_fixed:         mix(bg, "#000000", 0.4)
    property string on_primary_fixed_variant: mix(bg, red, 0.45)

    property string secondary:                  bone
    property string on_secondary:               onColor(bone)
    property string secondary_container:        mix(bg, bone, 0.2)
    property string on_secondary_container:     mix(bone, fg, 0.5)
    property string secondary_fixed:            mix(bone, fg, 0.5)
    property string secondary_fixed_dim:        bone
    property string on_secondary_fixed:         mix(bg, "#000000", 0.4)
    property string on_secondary_fixed_variant: mix(bg, bone, 0.45)

    property string tertiary:                  gold
    property string on_tertiary:               onColor(gold)
    property string tertiary_container:        mix(bg, gold, 0.3)
    property string on_tertiary_container:     mix(gold, fg, 0.6)
    property string tertiary_fixed:            mix(gold, fg, 0.5)
    property string tertiary_fixed_dim:        gold
    property string on_tertiary_fixed:         mix(bg, "#000000", 0.4)
    property string on_tertiary_fixed_variant: mix(bg, gold, 0.45)

    property string error:              pick(["color1", "red"], "#d0453b")
    property string on_error:           onColor(error)
    property string error_container:    mix(bg, error, 0.3)
    property string on_error_container: mix(error, fg, 0.6)

    // Semantic aliases used by the workspace disc (zesis-style naming)
    readonly property string accent:      primary
    // not `onAccent`: QML never sets a property `onX` beside a property `x`
    readonly property string accentInk: on_primary
    readonly property string surfaceHigh: surface_container_high
    readonly property string text:        on_surface

    // Return a copy of `base` with its alpha multiplied by `a` (0..1)
    function withAlpha(base, a) {
        if (!base)
            return "transparent";
        const c = Qt.color(base);
        return Qt.rgba(c.r, c.g, c.b, c.a * a);
    }

    // themectl replaces colors.sh by rename, which a file watch can miss;
    // ExtRoot also calls this whenever rise's Theme reloads its palette.
    function reload() {
        reloadTimer.restart();
    }

    Timer {
        id: reloadTimer
        interval: 100
        onTriggered: colorsFile.reload()
    }

    // rise's own type (assets/fonts), for the grimoire look; rise's Theme
    // loads it too, but the lock screen runs as an instance of its own.
    property list<FontLoader> fonts: [
        FontLoader { source: "file://" + Quickshell.shellPath("assets/fonts/GrenzeGotisch.ttf") },
        FontLoader { source: "file://" + Quickshell.shellPath("assets/fonts/CormorantGaramond.ttf") },
        FontLoader { source: "file://" + Quickshell.shellPath("assets/fonts/CormorantGaramond-Italic.ttf") }
    ]

    FileView {
        id: colorsFile
        path: root.path
        printErrors: false
        blockLoading: true
        watchChanges: true
        onFileChanged: reloadTimer.restart()
    }
}
