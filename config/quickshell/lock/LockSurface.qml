import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Lock screen, in the bar's frame look: blurred wallpaper, the rounded screen
// frame with its accent rim, a light clock, and a glass card with the password
// field. Plain QtQuick only — no Caelestia plugin — so the lock always loads.
// The PAM wiring (context, passwordBox, focus) is unchanged.
Item {
    id: root
    required property LockContext context
    required property var theme

    readonly property int frameThickness: 10
    readonly property int frameRounding: 0     // square, like the bar's frame
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ── wallpaper, softly blurred and dimmed ──
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + theme.backgroundPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        blurEnabled: true
        blur: 0.55
        blurMax: 48
    }
    Rectangle {
        anchors.fill: parent
        color: theme.bg
        visible: wallpaper.status !== Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.tint(theme.bg, 0.35) }
            GradientStop { position: 1.0; color: root.tint(theme.bg, 0.70) }
        }
    }

    // ── the screen frame: an oversized rectangle whose border's inner edge is
    // the rounded opening; the rim is the same, 2px further in, drawn first ──
    // (inline components don't see this file's ids: sizes are passed in)
    component FrameBand: Rectangle {
        required property real inset
        required property real rounding
        required property real thickness
        property real over: 200                     // reach past the screen edge
        anchors.fill: parent
        anchors.margins: -over
        color: "transparent"
        border.width: over + inset
        // inner corner radius = radius - border.width = rounding + thickness - inset
        radius: rounding + over + thickness
    }
    FrameBand { inset: root.frameThickness + 2; rounding: root.frameRounding; thickness: root.frameThickness; border.color: theme.color01 }   // the window-border colour, as on the bar
    FrameBand { inset: root.frameThickness; rounding: root.frameRounding; thickness: root.frameThickness; border.color: theme.bg }

    // ── clock ──
    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        spacing: 4

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
            font.pixelSize: 120
            font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                var days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                var months = ["January","February","March","April","May","June","July",
                               "August","September","October","November","December"]
                return (days[clockCol.now.getDay()] + " · " + clockCol.now.getDate() + " "
                    + months[clockCol.now.getMonth()]).toUpperCase()
            }
            color: theme.seal
            font.family: theme.mono
            font.pixelSize: 15
            font.letterSpacing: 4
        }
    }

    // ── glass card: who's locked, and the password ──
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.56
        width: 380
        height: cardCol.implicitHeight + 44
        radius: 28
        color: root.tint(theme.bg, 0.62)
        border.color: root.tint(theme.seal, 0.55)
        border.width: 1.5

        Column {
            id: cardCol
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 14

            // monogram in an accent ring
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64; height: 64; radius: 32
                color: root.tint(theme.seal, 0.16)
                border.color: theme.seal
                border.width: 2
                Text {
                    anchors.centerIn: parent
                    text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                    color: theme.seal
                    font.family: theme.mono
                    font.pixelSize: 28
                    font.weight: Font.Medium
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Quickshell.env("USER") || ""
                color: theme.ink
                font.family: theme.mono
                font.pixelSize: 15
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 48
                radius: 24
                color: root.tint(theme.ink, 0.08)
                border.color: root.context.showFailure
                    ? theme.err
                    : (passwordBox.activeFocus ? theme.seal : root.tint(theme.ink, 0.22))
                border.width: 1.5
                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextInput {
                    id: passwordBox
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    color: theme.ink
                    font.family: theme.mono
                    font.pixelSize: 16
                    font.letterSpacing: 3
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
                        anchors.centerIn: parent
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

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.frameThickness + 28
        text: "type your password · enter to unlock"
        color: theme.sumi
        font.family: theme.mono
        font.pixelSize: 11
        font.letterSpacing: 1
    }
}
