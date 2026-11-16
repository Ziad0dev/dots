import QtQuick

// The dashboard's colour roles (Material 3 names, so every dash/ component and
// tab keeps working), set as a grimoire: black vellum, bone ink, blood red.
// Blood is the window-border colour (Theme.windowBorder: the theme's optional
// `border`, else color1), so the dashboard matches Hyprland and the frame rim.
QtObject {
    id: m3
    required property var root

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) { return Qt.tint(a, Qt.rgba(b.r, b.g, b.b, t)) }

    readonly property color blood: root.windowBorder
    // blood lifted until it reads on black
    readonly property color bloodText: Qt.lighter(blood, 1.35)
    readonly property color bone: mix(root.ink, Qt.rgba(0.86, 0.80, 0.70, 1), 0.35)
    // muted text: a dim bone, still clearly readable on the sheet
    readonly property color ash: mix(bone, root.paper, 0.3)
    // the card under these panels: near-opaque vellum, so text reads the same
    // over any wallpaper (Frost let bright ones wash it out)
    readonly property color sheet: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.93)

    readonly property color primary: bloodText
    readonly property color secondary: bone
    readonly property color tertiary: mix(blood, root.paper, 0.15)
    readonly property color error: root.color01
    // The text on primary / the containers is `inkOn…`, not M3's `on…`: QML
    // never sets a property `onX` while a property `x` exists (onPrimary beside
    // primary stayed black, which made unselected chips and the current
    // settings tab unreadable).
    readonly property color inkOnPrimary: root.paper
    readonly property color onSurface: bone
    readonly property color onSurfaceVariant: ash
    readonly property color outline: tint(bone, 0.45)
    readonly property color outlineVariant: tint(blood, 0.38)
    readonly property color surfaceContainer: tint(blood, 0.035)
    readonly property color surfaceContainerHigh: tint(blood, 0.07)
    readonly property color surfaceContainerHighest: tint(blood, 0.11)
    readonly property color primaryContainer: tint(blood, 0.32)
    readonly property color secondaryContainer: tint(blood, 0.13)
    readonly property color tertiaryContainer: tint(blood, 0.2)
    readonly property color inkOnPrimaryContainer: bone
    readonly property color inkOnSecondaryContainer: bone
    readonly property color inkOnTertiaryContainer: bloodText
}
