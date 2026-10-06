import QtQuick
import "../IconMap.js" as IconMap

// Leading tag of a bar pill: the short text label (CPU, MEM, …) or, with
// styleIconLabels, its Material Symbols glyph. One recipe for both styles.
Item {
    id: lbl
    required property var root
    property string label: ""
    property string glyph: ""
    property color tint: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)

    readonly property bool useIcon: root.styleIconLabels && glyph !== ""
    implicitWidth: useIcon ? glyphText.implicitWidth : labelText.implicitWidth
    implicitHeight: useIcon ? glyphText.implicitHeight : labelText.implicitHeight

    UiText {
        id: labelText
        anchors.verticalCenter: parent.verticalCenter
        visible: !lbl.useIcon
        text: lbl.label
        color: lbl.tint
        font.family: lbl.root.mono
        font.pixelSize: 12
        font.letterSpacing: 0.5
    }

    IconText {
        id: glyphText
        anchors.verticalCenter: parent.verticalCenter
        visible: lbl.useIcon
        text: IconMap.icon(lbl.glyph)
        color: lbl.tint
        font.pixelSize: 15
    }
}
