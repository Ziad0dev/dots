import QtQuick

// Shared hover-tooltip controller. Encapsulates the 320ms hover delay plus the
// show/hide calls that every bar widget previously duplicated (~10 lines each).
// Each widget keeps its own MouseArea (click/wheel logic differs) and just calls
// tip.show() / tip.hide(); show() is a no-op while `text` is empty.
Item {
    id: mixin
    required property var root      // Theme — provides showTooltip()/hideTooltip()
    required property var owner     // the widget Item: anchor + tooltip owner key
    property string text: ""
    property int    delay: 320
    // the Theme flag of the popout this widget opens on hover (PopoutMorph);
    // its tooltip stays hidden while that popout is up. Driven by the pointer
    // itself, not show()/hide(): widgets also call hide() on click.
    property string popout: ""

    function show() { if (text) delayTimer.restart() }
    function hide() { delayTimer.stop(); root.hideTooltip(owner) }

    // spans the widget (it is declared inside it) to watch the pointer
    anchors.fill: popout !== "" ? parent : undefined
    HoverHandler {
        enabled: mixin.popout !== ""
        onHoveredChanged: {
            if (!mixin.root.popout) return
            if (hovered) mixin.root.popout.hoverOpen(mixin.popout, mixin.owner)
            else mixin.root.popout.hoverLeave()
        }
    }

    // live-update the visible tooltip while THIS widget owns it (e.g. volume %
    // changing under the cursor) — showTooltip() only captures a snapshot.
    onTextChanged: if (root && root.tooltipOwner === owner) root.tooltipText = text

    Timer {
        id: delayTimer
        interval: mixin.delay
        onTriggered: {
            if (!mixin.text) return
            if (mixin.popout && mixin.root[mixin.popout]) return
            var top = mixin.owner.mapToItem(null, mixin.owner.width / 2, 0)
            var bottom = mixin.owner.mapToItem(null, mixin.owner.width / 2, mixin.owner.height)
            mixin.root.showTooltip(mixin.text, top.x, top.y, bottom.y, mixin.owner)
        }
    }
}
