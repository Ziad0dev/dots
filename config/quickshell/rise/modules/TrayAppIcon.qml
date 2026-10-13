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

    implicitWidth: size
    implicitHeight: size

    Image {
        id: image
        anchors.fill: parent
        source: trayIcon.symbol === "" ? trayIcon.imageSource : ""
        sourceSize: Qt.size(trayIcon.size * 2, trayIcon.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: !trayIcon.root.trayRecolour
    }

    MultiEffect {
        anchors.fill: image
        source: image
        colorization: 1
        colorizationColor: trayIcon.root.seal
        visible: trayIcon.root.trayRecolour && trayIcon.symbol === ""
    }

    IconText {
        anchors.fill: parent
        visible: trayIcon.symbol !== ""
        text: trayIcon.symbol
        color: trayIcon.root.trayRecolour ? trayIcon.root.seal : trayIcon.root.ink
        font.pixelSize: trayIcon.size
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
