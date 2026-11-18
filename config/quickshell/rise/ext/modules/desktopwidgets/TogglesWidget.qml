pragma ComponentBehavior: Bound
// After lucid's quick toggles widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import Quickshell
import qs.ext.colors
import qs.ext.modules.lock
import qs.ext.services as Services

// Round switches for the things you flip most: Do Not Disturb, the night
// light, Wi-Fi, the microphone and staying awake. Each runs the same command
// the bar's own toggle does; Do Not Disturb shows its state from the bar.
WidgetFrame {
    id: root

    readonly property var theme: Services.Rise.theme
    readonly property var toggles: [
        { icon: "do_not_disturb_on", name: "Do not disturb", on: theme ? theme.notifSilenced === true : false,
          cmd: ["bash", "-c", "if command -v dots-toggle-notification-silencing >/dev/null 2>&1; then exec dots-toggle-notification-silencing; fi; exec dots toggle notification silencing"] },
        { icon: "nightlight", name: "Night light", on: false, cmd: ["dots-nightlight", "toggle"] },
        { icon: "wifi", name: "Wi-Fi", on: false, cmd: ["rfkill", "toggle", "wifi"] },
        { icon: "mic_off", name: "Microphone", on: false,
          cmd: ["bash", "-c", "if command -v dots-audio-input-mute >/dev/null 2>&1; then exec dots-audio-input-mute; fi; wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"] },
        { icon: "coffee", name: "Stay awake", on: false,
          cmd: ["bash", "-c", "if command -v dots-toggle-idle >/dev/null 2>&1; then exec dots-toggle-idle; fi; exec dots toggle idle"] }
    ]

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("toggles", themeId)
    seal: "切"

    Row {
        spacing: 12
        Repeater {
            model: root.toggles
            Column {
                id: tog
                required property var modelData
                spacing: 4
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 48
                    radius: 24
                    color: tog.modelData.on ? root.accent : Colors.withAlpha(root.ink, area.containsMouse ? 0.16 : 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Glyph {
                        anchors.centerIn: parent
                        text: tog.modelData.icon
                        font.pixelSize: 22
                        color: tog.modelData.on ? Colors.on_primary : root.ink
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(tog.modelData.cmd);
                            if (root.theme && root.theme.refreshStatusIndicators)
                                refreshSoon.restart();
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tog.modelData.name
                    font.family: root.st.font
                    font.pixelSize: 11
                    color: Colors.withAlpha(root.ink, 0.7)
                }
            }
        }
    }

    // the bar's indicators catch up with what a switch just did
    Timer {
        id: refreshSoon
        interval: 400
        onTriggered: root.theme.refreshStatusIndicators()
    }
}
