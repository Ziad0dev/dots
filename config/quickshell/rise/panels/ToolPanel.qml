import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

// The shared shell of a bar-anchored popout, as WeatherPanel/StoragePanel do
// it inline: a fullscreen overlay whose card lives in the morphing popout box
// (PopoutClip), with a title row and a close button. Children go in the
// card's column.
PanelWindow {
    id: panel
    required property var root
    required property string flag          // the Theme flag, e.g. "tailscaleVisible"
    property string title: ""
    property string namespace: "dots-tool"
    property int cardWidth: 320
    default property alias content: body.data
    readonly property int innerWidth: cardWidth - 24
    readonly property bool shown: root[flag] === true

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: namespace

    function close() { root[flag] = false }

    property real reveal: shown ? 1 : 0
    Behavior on reveal { Anim { kind: "effects" } }
    visible: reveal > 0.001 || (root.popout.last === flag && root.popout.shown)
    WlrLayershell.keyboardFocus: shown && !root.popout.hoverMode
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        readonly property bool hover: panel.root.popout.hoverMode
        readonly property int gap: panel.root.popout.gap
        x: hover ? popClip.x : 0
        y: hover ? popClip.y - (panel.root.popout.barOnTop ? gap : 0) : 0
        width: hover ? popClip.width : panel.width
        height: hover ? popClip.height + gap : panel.height
    }

    MouseArea { anchors.fill: parent; onClicked: panel.close() }

    PopoutClip {
        id: popClip
        root: panel.root
        flag: panel.flag
        card: card
        Rectangle {
            id: card
            width: panel.cardWidth
            height: col.implicitHeight + 24
            radius: panel.reveal > 0.001 ? panel.root.pillRadius : 0
            color: "transparent"
            border.color: panel.root.pillBorder
            border.width: 0
            x: popClip.cardX
            y: popClip.cardY
            opacity: panel.reveal
            focus: panel.shown

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) { panel.close(); event.accepted = true }
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: col
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Item {
                    width: parent.width
                    height: 24
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: panel.title
                        color: panel.root.ink; font.family: panel.root.gothic; font.pixelSize: 20
                        font.letterSpacing: 0.5; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "✕"; color: closeMa.containsMouse ? panel.root.seal : panel.root.sumi; font.pixelSize: 12
                        Behavior on color { CAnim { ms: 120 } }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.close() }
                    }
                }

                GrimRule { root: panel.root; width: parent.width }

                Column {
                    id: body
                    width: parent.width
                    spacing: 8
                }
            }
        }
    }
}
