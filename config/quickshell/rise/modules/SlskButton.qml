import QtQuick
import Quickshell

// A small pill that opens `query` as a search tab in Nicotine+ through
// `slsk-search` (home/soulseek.nix), then emits `launched` so the panel
// holding it can close.
Rectangle {
    id: btn

    required property var root
    property string query: ""
    property string label: "slsk"
    signal launched()

    implicitWidth: btnText.implicitWidth + 12
    width: implicitWidth
    height: 18
    radius: 9
    color: btnMa.containsMouse ? root.fillActive : "transparent"
    border.width: 1
    border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
    Behavior on color { CAnim { ms: 120 } }

    UiText {
        id: btnText
        anchors.centerIn: parent
        text: btn.label
        color: btnMa.containsMouse ? btn.root.seal : btn.root.sumiHi
        font.family: btn.root.mono
        font.pixelSize: 9
        font.letterSpacing: 1
    }
    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["slsk-search", btn.query])
            btn.launched()
        }
    }
}
