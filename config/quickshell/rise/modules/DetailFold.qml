import QtQuick

// A widget's reading that folds away until its side of the bar is hovered,
// so the bar at rest shows glyphs only (Omarchy 4.5's quiet bar; QuickReveal
// does the same for whole tools). The reading keeps updating while folded.
Item {
    id: f
    property bool shown: true
    // passed by the caller (contentWidth: value.implicitWidth): childrenRect
    // only counts visible children, and this item hides itself at zero width
    property real contentWidth: 0
    property real contentHeight: 16
    default property alias content: holder.data

    implicitWidth: shown ? contentWidth : 0
    implicitHeight: contentHeight
    // visible as soon as it should show: an invisible item gets no frames, so
    // its width animation would barely advance (the QuickReveal pattern)
    visible: shown || width > 0.5
    clip: true
    opacity: shown ? 1 : 0
    Behavior on implicitWidth { Anim { kind: "size"; ms: 220 } }
    Behavior on opacity { Anim { kind: "effects"; ms: 160 } }

    Item {
        id: holder
        width: f.contentWidth
        height: f.height
    }
}
