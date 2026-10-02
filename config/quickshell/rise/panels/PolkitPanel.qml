import QtQuick
import "../modules"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland

// The session's polkit authentication agent (replaces hyprpolkitagent).
// A dimmed overlay on the focused monitor with the request, the identity
// being authenticated and a password field.
PanelWindow {
    id: win
    required property var root

    PolkitAgent { id: agent }

    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive && flow !== null && !flow.isCompleted

    property bool failed: false
    property bool busy: false

    function focusedScreen() {
        var monitor = Hyprland.focusedMonitor
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (monitor && Quickshell.screens[i].name === monitor.name) return Quickshell.screens[i]
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    onActiveChanged: {
        if (!active) return
        screen = focusedScreen()
        failed = false
        busy = false
        input.text = ""
        Qt.callLater(function() { input.forceActiveFocus() })
    }

    function identityName(id) {
        if (!id) return ""
        return id.displayName || id.name || id.userName || ""
    }

    function submit() {
        if (!flow || !flow.isResponseRequired || busy) return
        busy = true
        failed = false
        flow.submit(input.text)
        input.text = ""
    }

    function cancel() {
        if (flow) flow.cancelAuthenticationRequest()
    }

    Connections {
        target: win.flow
        function onAuthenticationFailed() {
            win.failed = true
            win.busy = false
            shake.restart()
        }
        function onIsResponseRequiredChanged() {
            if (win.flow.isResponseRequired) {
                win.busy = false
                input.forceActiveFocus()
            }
        }
    }

    visible: active
    color: Qt.rgba(0, 0, 0, 0.45)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-polkit"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 400
        height: col.implicitHeight + 40
        radius: root.pillRadius
        color: root.paper
        border.color: win.failed ? root.sealRaw : root.sep
        border.width: 1
        PillShadow { theme: root }

        transform: Translate { id: shakeX }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeX; property: "x"; to: -10; duration: 50 }
            NumberAnimation { target: shakeX; property: "x"; to: 10; duration: 70 }
            NumberAnimation { target: shakeX; property: "x"; to: -6; duration: 60 }
            NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 50 }
        }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 12

            Row {
                spacing: 12
                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""   // lock
                    fill: 1
                    font.pixelSize: 26
                    color: root.seal
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    UiText {
                        text: "Authentication required"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.letterSpacing: 1
                    }
                    UiText {
                        width: col.width - 40
                        text: win.flow ? win.flow.actionId : ""
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                    }
                }
            }

            Text {
                width: parent.width
                text: win.flow ? win.flow.message : ""
                color: root.ink
                font.family: root.mono
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            UiText {
                width: parent.width
                visible: text !== ""
                text: {
                    var name = win.identityName(win.flow ? win.flow.selectedIdentity : null)
                    return name !== "" ? "as " + name : ""
                }
                color: root.sumiHi
                font.family: root.mono
                font.pixelSize: 11
            }

            Rectangle {
                width: parent.width
                height: 36
                radius: root.tileRadius
                color: root.bg
                border.color: win.failed ? root.sealRaw : input.activeFocus ? root.seal : root.sep
                border.width: 1

                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: win.flow && win.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    enabled: !win.busy
                    color: root.ink
                    selectionColor: root.seal
                    selectedTextColor: root.paper
                    font.family: root.mono
                    font.pixelSize: 13
                    clip: true
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            win.submit(); event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            win.cancel(); event.accepted = true
                        }
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text === ""
                        text: win.busy ? "checking…" : (win.flow && win.flow.inputPrompt ? win.flow.inputPrompt.replace(/:\s*$/, "") : "Password")
                        color: root.sumiHi
                        font: input.font
                    }
                }
            }

            UiText {
                width: parent.width
                visible: text !== ""
                text: win.failed ? "Authentication failed, try again"
                    : (win.flow && win.flow.supplementaryMessage ? win.flow.supplementaryMessage : "")
                color: win.failed || (win.flow && win.flow.supplementaryIsError) ? root.sealRaw : root.sumiHi
                font.family: root.mono
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    width: 96; height: 30
                    radius: root.tileRadius
                    color: cancelMa.containsMouse ? root.fillHover : root.fillIdle
                    border.color: cancelMa.containsMouse ? root.seal : root.sep
                    border.width: 1
                    UiText { anchors.centerIn: parent; text: "Cancel"; color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                    MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.cancel() }
                }
                Rectangle {
                    width: 120; height: 30
                    radius: root.tileRadius
                    color: okMa.containsMouse ? root.fillPrimaryHover : root.seal
                    UiText { anchors.centerIn: parent; text: win.busy ? "Checking…" : "Authenticate"; color: root.paper; font.family: root.mono; font.pixelSize: 11 }
                    MouseArea { id: okMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.submit() }
                }
            }
        }
    }
}
