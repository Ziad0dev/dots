import Quickshell.Hyprland
import QtQuick

Item {
    id: wsWidget
    required property var root
    property string gid: "G2"

    implicitWidth: wsRow.implicitWidth
    implicitHeight: 28

    property real _lastPulse: 0
    readonly property int focusedId: Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.name) : 0
    onFocusedIdChanged: {
        var now = Date.now()
        if (now - wsWidget._lastPulse < 450) return
        wsWidget._lastPulse = now
        root.barPulse("workspace")
    }

    // The focused workspace's number ONLY when it's a real workspace beyond
    // the persist range — else 0. An int signals on value change only, so switching
    // between in-range workspaces does NOT renotify → workspaceList stays identical
    // → the Repeater model is stable → the per-delegate width/colour Behaviors keep
    // animating instead of the whole model rebuilding (B2). Number(name) is NaN for
    // special/scratchpad workspaces, so they fail `> n` and stay excluded (B3).
    readonly property int extraWs: {
        if (root.workspaceMode === "active") return 0
        var n = root.workspaceMode === "5" ? 5 : 10
        var f = Hyprland.focusedWorkspace
        var fid = f ? Number(f.name) : 0
        return (fid > n) ? fid : 0
    }

    readonly property var workspaceList: {
        if (root.workspaceMode === "active") {
            var ids = {}
            var ws = Hyprland.workspaces.values
            for (var i = 0; i < ws.length; i++) {
                var k = Number(ws[i].name)               // F13: NaN for special workspaces → skipped
                if (k > 0) ids[k] = true
            }
            if (Hyprland.focusedWorkspace) {
                var fk = Number(Hyprland.focusedWorkspace.name)
                if (fk > 0) ids[fk] = true
            }
            return Object.keys(ids).map(Number).sort(function(a, b) { return a - b })
        }
        var n = root.workspaceMode === "5" ? 5 : 10
        var list = []; for (var j = 1; j <= n; j++) list.push(j)
        if (extraWs > 0) list.push(extraWs)   // focused-beyond-range, stable per id
        return list
    }

    Rectangle {
        x: -root.wsPillPad; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(wsRow.width) + 2 * root.wsPillPad
        height: root.pillH
        radius: root.pillRadius
        color: root.widgetFillColor(wsWidget.gid)
        border.color: root.widgetBorderColor(wsWidget.gid)
        border.width: root.widgetBorderWidth(wsWidget.gid)
        PillShadow { theme: root }
    }

    // right-click anywhere opens the workspace panel
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.workspaceVisible = !root.workspaceVisible
    }

    property real cometX: 0
    property real cometW: 0
    property bool cometFwd: true
    function aimComet(nx, nw) {
        if (nx !== wsWidget.cometX) wsWidget.cometFwd = nx > wsWidget.cometX
        wsWidget.cometX = nx
        wsWidget.cometW = nw
    }

    Item {
        id: cometLayer
        visible: root.workspaceStyle === "comet"
        anchors.fill: wsRow

        property real lead: wsWidget.cometX + wsWidget.cometW
        property real tail: wsWidget.cometX
        property real ghostLead: wsWidget.cometX + wsWidget.cometW
        property real ghostTail: wsWidget.cometX

        Behavior on lead      { NumberAnimation { duration: wsWidget.cometFwd ? 190 : 430; easing.type: Easing.OutCubic } }
        Behavior on tail      { NumberAnimation { duration: wsWidget.cometFwd ? 430 : 190; easing.type: Easing.OutCubic } }
        Behavior on ghostLead { NumberAnimation { duration: wsWidget.cometFwd ? 320 : 620; easing.type: Easing.OutCubic } }
        Behavior on ghostTail { NumberAnimation { duration: wsWidget.cometFwd ? 620 : 320; easing.type: Easing.OutCubic } }

        Rectangle {
            x: cometLayer.ghostTail
            width: Math.max(2, cometLayer.ghostLead - cometLayer.ghostTail)
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            radius: root.styleRadiusSmall ? 5 : height / 2
            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.10)
        }

        Rectangle {
            x: cometLayer.tail
            width: Math.max(2, cometLayer.lead - cometLayer.tail)
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            radius: root.styleRadiusSmall ? 5 : height / 2
            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.26)
            border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.55)
            border.width: 1
        }
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: wsWidget.workspaceList

            delegate: Item {
                id: wsCell
                required property int modelData
                readonly property int wsId: modelData

                // hover feedback works in every style (the old code scaled the
                // default-only `dot`, invisible in numbers/magic)
                Behavior on scale { NumberAnimation { duration: 120 } }

                readonly property bool isFocused: Hyprland.focusedWorkspace !== null
                                               && Number(Hyprland.focusedWorkspace.name) === wsId

                readonly property bool isOccupied: {
                    var ws = Hyprland.workspaces.values
                    for (var i = 0; i < ws.length; i++)
                        if (Number(ws[i].name) === wsId) return !isFocused
                    return false
                }

                readonly property bool isEmpty: !isFocused && !isOccupied

                onXChanged:         if (wsCell.isFocused) wsWidget.aimComet(wsCell.x, wsCell.width)
                onWidthChanged:     if (wsCell.isFocused) wsWidget.aimComet(wsCell.x, wsCell.width)
                onIsFocusedChanged: if (wsCell.isFocused) wsWidget.aimComet(wsCell.x, wsCell.width)
                Component.onCompleted: if (wsCell.isFocused) wsWidget.aimComet(wsCell.x, wsCell.width)

                implicitWidth: root.workspaceStyle === "numbers" ? 22
                             : root.workspaceStyle === "comet"   ? 24
                             : root.workspaceStyle === "magic"   ? (isFocused ? 20 : 18)
                             : (isFocused ? 32 : 16)
                implicitHeight: 28

                Behavior on implicitWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // ── DEFAULT style: glow + dot ──
                // glow — alle states, nur opacity variiert
                Rectangle {
                    visible: root.workspaceStyle === "default"
                    anchors.centerIn: parent
                    width:  isFocused ? 34 : 16
                    height: isFocused ? 16 : 16
                    radius: isFocused ?  8 :  8
                    color: isFocused
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                        : isOccupied
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                        : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.06)

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // pill / kreis
                Rectangle {
                    id: dot
                    visible: root.workspaceStyle === "default"
                    anchors.centerIn: parent
                    width:  isFocused  ? 26 : 8
                    height: 8
                    radius: 4
                    color:  isFocused
                        ? root.seal
                        : isOccupied
                        ? root.seal
                        : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // ── NUMBERS style: a digit on a rounded badge (radius follows
                //    the bar radius switch: round/12 ⇄ 5) ──
                Rectangle {
                    visible: root.workspaceStyle === "numbers"
                    anchors.centerIn: parent
                    width:  20
                    height: 20
                    radius: root.styleRadiusSmall ? 5 : height / 2
                    color: isFocused  ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.30)
                         : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                                      : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.04)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        anchors.centerIn: parent
                        text: wsId
                        // focused = the only BRIGHT digit (lightened seal + bold + bigger);
                        // others dimmed so the active workspace is unmistakable
                        color: isFocused  ? Qt.lighter(root.seal, 1.3)
                             : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.5)
                                          : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.28)
                        font.family: root.mono
                        font.pixelSize: isFocused ? 13 : 12
                        font.weight: isFocused ? Font.Bold : Font.Normal
                    }
                }

                Text {
                    visible: root.workspaceStyle === "comet"
                    anchors.centerIn: parent
                    text: wsCell.wsId
                    color: wsCell.isFocused  ? Qt.lighter(root.seal, 1.35)
                         : wsCell.isOccupied ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
                                             : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                    font.family: root.mono
                    font.pixelSize: 12
                    font.weight: wsCell.isFocused ? Font.Bold : Font.Normal
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // ── MAGIC style: the 3 ORIGINAL sparkle glyphs (filled / hollow / dot),
                //    all forced into ONE font (Adwaita Mono has all three) so they share
                //    a metric → no cross-font fallback misalignment ──
                Text {
                    visible: root.workspaceStyle === "magic"
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: isFocused ? 0 : 1   // active lifted vs occupied/empty
                    text: isFocused  ? String.fromCodePoint(0x2726)    // ✦ filled four-point star (active)
                         : isOccupied ? String.fromCodePoint(0x2727)    // ✧ hollow four-point star (occupied)
                                      : String.fromCodePoint(0x00B7)    // · middle dot (empty)
                    color: isFocused  ? root.seal
                         : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.7)
                                      : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3)
                    font.family: "Adwaita Mono"   // all 3 sparkle glyphs live here → one consistent metric
                    font.pixelSize: isFocused ? 22 : 18
                    renderType: Text.NativeRendering   // crisp hinted raster (default QtRendering softens small symbols)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.gotoWorkspace(wsId)
                    onEntered: wsCell.scale = 1.15
                    onExited:  wsCell.scale = 1.0
                }
            }
        }
    }

}
