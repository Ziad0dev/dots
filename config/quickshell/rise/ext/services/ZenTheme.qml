pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.ext.colors

// rise: Zen in the desktop theme's look (after dhrruvsharma/shell's
// FirefoxTheme). Writes ~/.local/state/dots/theme/zen-desktop-theme.css,
// which config/zen/userChrome.css imports (zen-theme-link.sh links it into the
// profile as chrome/dots-desktop-theme.css): the colour roles the stylesheets
// use, then firefox/chrome.css and the theme's firefox/<id>.css. With no
// desktop theme on it is empty and Zen keeps the themectl palette alone.
// Zen reads chrome CSS when it starts, so a change shows on its next launch.
// Only the main shell sets `manage`.
Singleton {
    id: root

    property bool manage: false
    readonly property string sourceDir: Quickshell.shellPath("ext/firefox")
    readonly property string outPath: Quickshell.env("HOME") + "/.local/state/dots/theme/zen-desktop-theme.css"
    readonly property string theme: DesktopTheme.enabled ? DesktopTheme.theme : ""
    property string _written: ""

    function _colors() {
        const roles = {
            "bg": Colors.background, "surface": Colors.surface_container, "surface-low": Colors.surface_container_low,
            "surface-high": Colors.surface_container_high, "surface-highest": Colors.surface_container_highest,
            "fg": Colors.on_surface, "fg-dim": Colors.on_surface_variant, "primary": Colors.primary,
            "on-primary": Colors.on_primary, "primary-container": Colors.primary_container,
            "on-primary-container": Colors.on_primary_container, "tertiary": Colors.tertiary,
            "on-tertiary": Colors.on_tertiary, "outline": Colors.outline, "outline-variant": Colors.outline_variant,
            "error": Colors.error,
            // the desktop theme's accents as it tones them (neon, gilt, jewel…)
            "theme-accent": DesktopTheme.accent, "theme-accent2": DesktopTheme.accent2
        };
        let css = ":root {\n";
        for (const k in roles)
            css += "  --qs-" + k + ": " + roles[k] + ";\n";
        return css + "}\n";
    }

    function sync() {
        if (!manage || !DesktopTheme.ready)
            return;
        let text = "/* The desktop theme for Zen, written by rise (ext/services/ZenTheme.qml). */\n";
        if (theme) {
            if (!baseChrome.ready || !themeCss.ready)
                return;
            text += _colors() + "\n" + baseChrome.text() + "\n" + themeCss.text();
        }
        if (text === _written)
            return;
        out.setText(text);
        _written = text;
    }

    Timer {
        id: syncTimer
        interval: 400
        onTriggered: root.sync()
    }
    onManageChanged: syncTimer.restart()
    onThemeChanged: syncTimer.restart()
    Connections {
        target: Colors
        function onPrimaryChanged() { syncTimer.restart(); }
        function onBackgroundChanged() { syncTimer.restart(); }
        function onTertiaryChanged() { syncTimer.restart(); }
    }
    Connections {
        target: DesktopTheme
        function onReadyChanged() { syncTimer.restart(); }
    }

    component Source: FileView {
        property bool ready: false
        printErrors: false
        onLoaded: { ready = true; syncTimer.restart(); }
        onLoadFailed: { ready = false; syncTimer.restart(); }
    }
    Source {
        id: baseChrome
        path: root.sourceDir + "/chrome.css"
    }
    Source {
        id: themeCss
        path: root.theme ? root.sourceDir + "/" + root.theme + ".css" : ""
        onPathChanged: ready = false
    }
    FileView {
        id: out
        path: root.outPath
        blockWrites: true
        atomicWrites: true
        printErrors: false
    }
}
