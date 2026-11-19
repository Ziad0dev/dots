import QtQuick

// One quick-group tool that folds away while it's inactive, unless the group
// is hovered (Omarchy 4.5's bar: active indicators stay, the rest show on
// hover). Its child keeps running while folded, so the state stays live.
Item {
    id: r
    property bool active: false
    property bool revealed: false
    property bool available: true          // false hides it even when revealed
    default property alias content: holder.data
    readonly property bool shown: available && (active || revealed)
    // the tool's width, passed by the caller (contentWidth: tool.implicitWidth):
    // childrenRect only counts visible children and this item hides itself at
    // zero width, and a binding on holder.children doesn't follow late children
    property real contentWidth: 0

    implicitWidth: shown ? contentWidth : 0
    implicitHeight: 28
    // visible as soon as it should show: an invisible item gets no frames,
    // so its width animation would barely advance (the CapsLockWidget pattern)
    visible: shown || width > 0.5
    clip: true
    opacity: shown ? 1 : 0
    Behavior on implicitWidth { Anim { kind: "size"; ms: 200 } }
    Behavior on opacity { Anim { kind: "effects"; ms: 140 } }

    Item {
        id: holder
        width: r.contentWidth
        height: parent.height
    }
}
