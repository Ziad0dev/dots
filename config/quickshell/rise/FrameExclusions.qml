import QtQuick
import Quickshell
import Quickshell.Wayland

// Reserves the frame's space on every edge while it is on: BarSlot draws the
// whole frame and so ignores exclusive zones itself. Each zone is a 1×1,
// input-less layer window anchored to one edge.
Scope {
    id: zones

    required property var root
    required property var screen

    readonly property bool barOnTop: root.barPosition !== "bottom"
    // the bar strip (35) + 3, as before the frame; auto-hide keeps only the edge
    readonly property int barZone: root.styleAutoHide ? root.frameThickness : 38

    component Zone: PanelWindow {
        screen: zones.screen
        visible: zones.root.frameOn
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        mask: Region {}
        WlrLayershell.namespace: "quickshell-frame-exclusion"
    }

    Zone { anchors.top: true;    exclusiveZone: zones.barOnTop ? zones.barZone : zones.root.frameThickness }
    Zone { anchors.bottom: true; exclusiveZone: zones.barOnTop ? zones.root.frameThickness : zones.barZone }
    Zone { anchors.left: true;   exclusiveZone: zones.root.frameThickness }
    Zone { anchors.right: true;  exclusiveZone: zones.root.frameThickness }
}
