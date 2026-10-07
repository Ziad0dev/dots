import QtQuick

// Material 3 colour roles derived from the active palette (Caelestia-style
// panels: the dashboard, window info). The dash/ components take one of these
// (or the dashboard, which aliases them) as `dash`.
QtObject {
    id: m3
    required property var root

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) { return Qt.tint(a, Qt.rgba(b.r, b.g, b.b, t)) }
    function hueGap(a, b) {
        var d = Math.abs(a.hslHue - b.hslHue)
        return Math.min(d, 1 - d)
    }

    readonly property color primary: root.seal
    readonly property color secondary: mix(root.seal, root.ink, 0.42)
    readonly property color tertiary: hueGap(root.seal, root.color05) > 0.08 ? root.color05 : root.color04
    readonly property color error: root.color01
    readonly property color onPrimary: root.paper
    readonly property color onSurface: root.ink
    readonly property color onSurfaceVariant: root.sumi
    readonly property color outline: tint(root.sumi, 0.8)
    readonly property color outlineVariant: tint(root.ink, 0.14)
    readonly property color surfaceContainer: tint(root.ink, 0.055)
    readonly property color surfaceContainerHigh: tint(root.ink, 0.09)
    readonly property color surfaceContainerHighest: tint(root.ink, 0.13)
    readonly property color primaryContainer: tint(primary, 0.40)
    readonly property color secondaryContainer: tint(secondary, 0.24)
    readonly property color tertiaryContainer: tint(tertiary, 0.38)
    readonly property color onPrimaryContainer: mix(root.ink, primary, 0.45)
    readonly property color onSecondaryContainer: mix(root.ink, secondary, 0.3)
    readonly property color onTertiaryContainer: mix(root.ink, tertiary, 0.45)
}
