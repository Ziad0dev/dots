import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// AI usage panel: Claude Code usage. Opened from the AI pill (AiWidget);
// renders the same parsed cache the bar pill reads.
PanelWindow {
    id: aiPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-ai-usage"

    readonly property int barBottom: 35
    readonly property int gap: 8

    // usage data: read straight from root.aiCl* (parsed once in ThemeAiUsage.qml,
    // shared with the bar pill)

    property real reveal: root.aiUsageVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: "effects" }
    }
    visible: reveal > 0.001
        || (root.popout.last === "aiUsageVisible" && root.popout.shown)
    WlrLayershell.keyboardFocus: root.aiUsageVisible && !root.popout.hoverMode
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        readonly property bool hover: aiPanel.root.popout.hoverMode
        readonly property int gap: aiPanel.root.popout.gap
        x: hover ? popClip.x : 0
        y: hover ? popClip.y - (aiPanel.root.popout.barOnTop ? gap : 0) : 0
        width: hover ? popClip.width : aiPanel.width
        height: hover ? popClip.height + gap : aiPanel.height
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.aiUsageVisible = false
    }

    // ── reusable label · bar · % row ──
    component UsageRow: Item {
        property string label: ""
        property int pct: 0
        property bool dim: false
        width: parent ? parent.width : 0
        height: 16
        UiText {
            id: rowLbl
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: label; color: aiPanel.root.sumiHi
            font.family: aiPanel.root.mono; font.pixelSize: 11; font.letterSpacing: 1
        }
        UiText {
            id: rowVal
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: pct + "%"
            color: dim ? aiPanel.root.sumi : aiPanel.root.seal
            font.family: aiPanel.root.mono; font.pixelSize: 11; font.weight: Font.Medium
        }
        Rectangle {
            anchors.left: rowLbl.right; anchors.leftMargin: 8
            anchors.right: rowVal.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 8; radius: 4
            color: Qt.rgba(aiPanel.root.seal.r, aiPanel.root.seal.g, aiPanel.root.seal.b, 0.15)
            Rectangle {
                width: parent.width * Math.min(100, parent ? pct : 0) / 100
                height: parent.height; radius: 4
                color: pct >= 90 ? aiPanel.root.sealRaw : aiPanel.root.seal
                Behavior on width { Anim { kind: "size"; ms: 300 } }
            }
        }
    }

    // ── reusable key/value detail row ──
    component DetailRow: Row {
        property string k: ""
        property string v: ""
        width: parent ? parent.width : 0
        UiText {
            text: k; color: aiPanel.root.sumiHi
            font.family: aiPanel.root.mono; font.pixelSize: 11
            width: parent.width * 0.45
        }
        UiText {
            text: v; color: aiPanel.root.ink
            font.family: aiPanel.root.mono; font.pixelSize: 11
            width: parent.width * 0.55; horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    PopoutClip {
        id: popClip
        root: aiPanel.root
        flag: "aiUsageVisible"
        card: card
        Rectangle {
            id: card
            width: 360
            height: Math.min(col.implicitHeight + 24, aiPanel.height - 2 * (barBottom + gap))
            radius: reveal > 0.001 ? root.pillRadius : 0
            color: "transparent"
            border.color: root.pillBorder
            border.width: 0

            x: popClip.cardX
            y: popClip.cardY
            opacity: aiPanel.reveal
            focus: root.aiUsageVisible

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.aiUsageVisible = false;
                    event.accepted = true;
                }
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Flickable {
                id: scroller
                anchors.fill: parent
                anchors.margins: 12
                contentWidth: width
                contentHeight: col.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: col
                    width: scroller.width
                    spacing: 8

                    // ── header ──
                    Item {
                        width: parent.width
                        height: 24
                        UiText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Ai Usage"
                            color: root.ink
                            font.family: root.gothic
                            font.pixelSize: 20
                            font.letterSpacing: 0.5
                            font.weight: Font.Medium
                        }
                        UiText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"
                            color: closeMa.containsMouse ? root.seal : root.sumi
                            font.pixelSize: 12
                            Behavior on color { CAnim { ms: 120 } }
                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.aiUsageVisible = false
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.sep }

                    // ── Claude Code ──
                    Item {
                        width: parent.width; height: 16
                        UiText {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            text: "Claude Code"; color: root.ink
                            font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                        }
                        UiText {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: root.aiClFresh ? "live" : "stale"
                            color: root.aiClFresh ? root.sumi : root.sealRaw
                            font.family: root.mono; font.pixelSize: 10
                        }
                    }
                    UiText {
                        visible: !root.aiClHas
                        width: parent.width
                        text: "no data — run claude"
                        color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    }
                    UsageRow { visible: root.aiClHas; label: "5h"; pct: root.aiClPct5h; dim: !root.aiClFresh }
                    UsageRow { visible: root.aiClHas; label: "7d"; pct: root.aiClPct7d; dim: !root.aiClFresh }
                    DetailRow { visible: root.aiClHas; k: "5h resets in"; v: root.aiFmtResetDetail(root.aiClReset5hTs) || "—" }
                    DetailRow { visible: root.aiClHas; k: "7d resets in"; v: root.aiFmtResetDetail(root.aiClReset7dTs) || "—" }
                    DetailRow { visible: root.aiClHas && root.aiClTokens !== ""; k: "Tokens"; v: root.aiClTokens }
                    DetailRow { visible: root.aiClHas && root.aiClRate !== "";   k: "Rate"; v: root.aiClRate }
                    DetailRow { visible: root.aiClHas && root.aiClToday > 0; k: "Today"; v: (root.aiClToday / 1e6).toFixed(2) + "M tok" }
                }
            }
        }
    }

    // Usage data lives in ThemeAiUsage.qml (shared with the bar pill); opening this
    // panel re-reads the cache once via root.aiUsageVisible.
}
