// Ported from dhrruvsharma/shell (quickshell/components/StyledText.qml), GPL-3.0-or-later.
import QtQuick
import qs.ext.colors
import qs.ext.services as Services

// Base text element for the shell. The colour is defaulted, and the family
// follows the desktop theme (the default font when none is on); size stays
// whatever Text gives you. Set font.family to opt out.
Text {
    color: Colors.on_surface
    // rise: in the grimoire look (no desktop theme), headings (19px and up)
    // are blackletter. The size is read once: reading it inside the family's
    // binding is a binding loop (both live in `font`).
    property bool heading: false
    Component.onCompleted: heading = font.pixelSize >= 19
    font.family: Services.DesktopTheme.grimoire && heading ? Services.DesktopTheme.look.headingFont
        : Services.DesktopTheme.font || Qt.application.font.family
    font.weight: Services.DesktopTheme.grimoire ? Font.Medium : Font.Normal
}
