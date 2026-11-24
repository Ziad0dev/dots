import QtQuick
import QtQuick.Effects
import Quickshell

// One renderer for the system tray icon row and its overflow panel. A tray
// substitution may provide a Material Symbols name (`icon`) or an image path
// (`image`); image takes precedence, matching Caelestia's tray config.
Item {
    id: trayIcon
    required property var root
    required property var item
    property int size: 16

    readonly property var substitution: root.trayIconSub(item)
    readonly property string symbol: substitution && !substitution.image && substitution.icon
        ? String(substitution.icon) : ""
    readonly property string imageSource: {
        var source = substitution && substitution.image
            ? String(substitution.image) : String(item && item.icon || "")
        if (source.indexOf("~/") === 0)
            return "file://" + Quickshell.env("HOME") + source.substring(1)
        if (source.length > 0 && source.charAt(0) === "/")
            return "file://" + source
        return source
    }

    // icons meant to be one colour (symbolic/panel icons) get a flat accent
    // fill; full-colour ones are washed instead (`washed`), since a flat fill
    // would turn them into a blob
    readonly property bool monochrome: symbol !== ""
        || /symbolic|-panel|-tray|indicator|-mono/i.test(imageSource)
    readonly property bool tinted: root.trayRecolour && monochrome
    // no icon, or one the theme doesn't have: the app's initial instead of a gap
    readonly property bool failed: symbol === ""
        && (imageSource === "" || image.status === Image.Error)

    implicitWidth: size
    implicitHeight: size

    // a full-colour app icon with recolouring on: drained of its own hue and
    // washed with the accent, so its shading survives but it sits in the
    // palette instead of standing out as the one green or blue thing on the bar
    readonly property bool washed: root.trayRecolour && !monochrome

    Image {
        id: image
        anchors.fill: parent
        source: trayIcon.symbol === "" ? trayIcon.imageSource : ""
        sourceSize: Qt.size(trayIcon.size * 2, trayIcon.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: !trayIcon.tinted && !trayIcon.washed && !trayIcon.failed
        // the mask for the tinted fill below (a layer only while it's needed)
        layer.enabled: trayIcon.tinted && trayIcon.symbol === ""
    }

    // Symbolic icons are drawn dark grey; colorizing keeps that lightness and
    // gave a muddy dark red. Fill the icon's shape with the accent instead.
    Rectangle {
        id: tintFill
        anchors.fill: image
        color: trayIcon.root.seal
        visible: false
        layer.enabled: trayIcon.tinted && trayIcon.symbol === ""
    }
    MultiEffect {
        anchors.fill: image
        source: tintFill
        maskEnabled: true
        maskSource: image
        // follow the icon's alpha smoothly; the default threshold made every
        // faint pixel solid and filled in the icons' inner detail
        // (the ramp is centred on the threshold, so 0.5 ± 0.5 spans all of it)
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        visible: trayIcon.tinted && trayIcon.symbol === "" && !trayIcon.failed
    }

    MultiEffect {
        anchors.fill: image
        source: image
        // colorization keeps each pixel's lightness, so the shading stays;
        // (a saturation step here runs after it and greyed the tint out)
        colorization: 1
        colorizationColor: trayIcon.root.seal
        visible: trayIcon.washed && !trayIcon.failed
    }

    UiText {
        anchors.centerIn: parent
        visible: trayIcon.failed
        text: String(trayIcon.root.trayDisplayName(trayIcon.item) || "?").charAt(0).toUpperCase()
        color: trayIcon.root.ink
        font.family: trayIcon.root.mono
        font.pixelSize: Math.round(trayIcon.size * 0.8)
        font.weight: Font.Bold
    }

    IconText {
        anchors.fill: parent
        visible: trayIcon.symbol !== ""
        text: trayIcon.symbol
        color: trayIcon.tinted ? trayIcon.root.seal : trayIcon.root.ink
        font.pixelSize: trayIcon.size
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
