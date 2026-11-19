import QtQuick
import "../modules"
import Quickshell

// Tailscale: connection state, this machine, the tailnet's machines (online
// first), click one to copy its address. After Omarchy 4.5's tailscale panel.
ToolPanel {
    id: tsPanel
    flag: "tailscaleVisible"
    title: "Tailscale"
    namespace: "dots-tailscale"
    cardWidth: 340

    property string copied: ""
    function copy(text) {
        if (!text) return
        Quickshell.execDetached(["wl-copy", "--", text])
        copied = text
        copiedTimer.restart()
    }
    Timer { id: copiedTimer; interval: 1500; onTriggered: tsPanel.copied = "" }

    readonly property var self: root.tsSelf
    readonly property string selfIp: (self.TailscaleIPs || [])[0] || ""

    // state line
    Item {
        width: tsPanel.innerWidth
        height: 20
        UiText {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: !root.tsAvailable ? "Tailscale isn't running"
                : root.tsUp ? "Connected" : root.tsState
            color: root.tsUp ? root.seal : root.sumiHi
            font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
        }
        UiText {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            visible: root.tsUp
            textFormat: Text.PlainText
            text: (root.tsStatus.CurrentTailnet && root.tsStatus.CurrentTailnet.Name) || ""
            color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
            elide: Text.ElideLeft; width: parent.width * 0.55; horizontalAlignment: Text.AlignRight
        }
    }

    // this machine
    Rectangle {
        width: tsPanel.innerWidth
        height: 34
        radius: root.tileRadius
        visible: root.tsUp && tsPanel.selfIp !== ""
        color: selfMa.containsMouse ? root.fillHover : root.fillIdle
        Column {
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
            UiText {
                textFormat: Text.PlainText
                text: (tsPanel.self.HostName || "this machine") + "  (this device)"
                color: root.ink; font.family: root.mono; font.pixelSize: 11
            }
            UiText {
                text: tsPanel.copied === tsPanel.selfIp ? "copied" : tsPanel.selfIp
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
            }
        }
        MouseArea {
            id: selfMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: tsPanel.copy(tsPanel.selfIp)
        }
    }

    UiText {
        visible: root.tsUp && root.tsPeers.length > 0
        text: "MACHINES · click to copy the address"
        color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
    }

    Column {
        width: tsPanel.innerWidth
        spacing: 2
        visible: root.tsUp
        Repeater {
            model: root.tsPeers
            delegate: Rectangle {
                required property var modelData
                readonly property string ip: (modelData.TailscaleIPs || [])[0] || ""
                width: tsPanel.innerWidth
                height: 24
                radius: root.tileRadius
                color: peerMa.containsMouse ? root.fillHover : "transparent"
                Rectangle {
                    id: dot
                    anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: modelData.Online ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                }
                UiText {
                    anchors.left: dot.right; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.5
                    textFormat: Text.PlainText
                    text: (modelData.HostName || root.tsName(modelData)) + (modelData.ExitNode ? "  ⇱ exit" : "")
                    color: modelData.Online ? root.ink : root.sumi
                    font.family: root.mono; font.pixelSize: 11; elide: Text.ElideRight
                }
                UiText {
                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: tsPanel.copied === parent.ip ? "copied" : (parent.ip + "  " + (modelData.OS || ""))
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
                }
                MouseArea {
                    id: peerMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    // left: the IP; right: the MagicDNS name
                    onClicked: function (e) {
                        tsPanel.copy(e.button === Qt.RightButton ? root.tsName(modelData) : parent.ip)
                    }
                }
            }
        }
    }

    UiText {
        width: tsPanel.innerWidth
        visible: root.tsError !== ""
        textFormat: Text.PlainText
        text: root.tsError
        color: root.color01; font.family: root.mono; font.pixelSize: 10
        wrapMode: Text.WordWrap
    }

    Row {
        width: tsPanel.innerWidth
        spacing: 6
        visible: root.tsAvailable
        ToolButton {
            root: tsPanel.root
            width: root.evenW((parent.width - parent.spacing) / 2)
            primary: true
            busy: root.tsBusy
            text: root.tsBusy ? "…" : (root.tsUp ? "Disconnect" : "Connect")
            onClicked: root.setTailscale(!root.tsUp)
        }
        ToolButton {
            root: tsPanel.root
            width: root.evenW((parent.width - parent.spacing) / 2)
            text: "Admin console"
            onClicked: Quickshell.execDetached(["xdg-open", "https://login.tailscale.com/admin/machines"])
        }
    }
}
