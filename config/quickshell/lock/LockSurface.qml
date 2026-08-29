import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    required property LockContext context
    required property var theme

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + theme.backgroundPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: theme.bg
        visible: !wallpaper.visible
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.55)
    }

    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.28
        spacing: 6

        property var now: new Date()
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clockCol.now = new Date() }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                var h = clockCol.now.getHours().toString().padStart(2, "0")
                var m = clockCol.now.getMinutes().toString().padStart(2, "0")
                return h + ":" + m
            }
            color: theme.ink
            font.family: theme.mono
            font.pixelSize: 84
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                var days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                var months = ["January","February","March","April","May","June","July",
                               "August","September","October","November","December"]
                return days[clockCol.now.getDay()] + ", " + months[clockCol.now.getMonth()]
                    + " " + clockCol.now.getDate()
            }
            color: theme.sumi
            font.family: theme.mono
            font.pixelSize: 16
            renderType: Text.NativeRendering
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.58
        spacing: 12

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 46
            radius: 23
            color: Qt.rgba(theme.ink.r, theme.ink.g, theme.ink.b, 0.08)
            border.color: root.context.showFailure
                ? theme.err
                : (passwordBox.activeFocus ? theme.accentHint : Qt.rgba(theme.ink.r, theme.ink.g, theme.ink.b, 0.18))
            border.width: 1.5
            Behavior on border.color { ColorAnimation { duration: 120 } }

            TextInput {
                id: passwordBox
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                color: theme.ink
                font.family: theme.mono
                font.pixelSize: 15
                echoMode: TextInput.Password
                passwordCharacter: "•"
                enabled: !root.context.unlockInProgress
                focus: true
                inputMethodHints: Qt.ImhSensitiveData

                onTextChanged: root.context.currentText = text
                onAccepted: root.context.tryUnlock()

                Connections {
                    target: root.context
                    function onCurrentTextChanged() {
                        if (passwordBox.text !== root.context.currentText)
                            passwordBox.text = root.context.currentText
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.context.unlockInProgress ? "checking…" : "password"
                    color: theme.sumi
                    font.family: theme.mono
                    font.pixelSize: 14
                    visible: passwordBox.text.length === 0
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.context.errorText !== "" ? root.context.errorText : "incorrect password"
            color: theme.err
            font.family: theme.mono
            font.pixelSize: 12
            visible: root.context.showFailure
        }
    }
}
