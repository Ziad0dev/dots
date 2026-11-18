pragma ComponentBehavior: Bound
// After lucid's battery widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import Quickshell.Services.UPower
import qs.ext.colors
import qs.ext.services as Services

// The charge of everything that reports one: the laptop battery if there is
// one, and wireless mice, keyboards, headsets and controllers (UPower).
WidgetFrame {
    id: root

    readonly property var devices: UPower.devices.values.filter(d => d.isPresent && d.type !== UPowerDeviceType.LinePower && d.percentage > 0)

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("devices", themeId)
    seal: "電"

    function name(d) {
        if (d.isLaptopBattery) return "Battery";
        return d.model || d.nativePath || "Device";
    }

    Text {
        visible: root.devices.length === 0
        text: "No battery-powered devices connected"
        font.family: root.st.font
        font.pixelSize: 13
        font.italic: true
        color: Colors.withAlpha(root.ink, 0.55)
    }

    Repeater {
        model: root.devices
        Column {
            id: row
            required property var modelData
            readonly property real level: modelData.percentage <= 1 ? modelData.percentage : modelData.percentage / 100
            width: 260
            spacing: 4
            Item {
                width: parent.width
                height: label.implicitHeight
                Text {
                    id: label
                    width: parent.width - 60
                    elide: Text.ElideRight
                    text: root.name(row.modelData)
                    font.family: root.st.font
                    font.pixelSize: 13
                    color: root.ink
                }
                Text {
                    anchors.right: parent.right
                    text: Math.round(row.level * 100) + "%" + (row.modelData.state === UPowerDeviceState.Charging ? " ⚡" : "")
                    font.family: root.st.mono
                    font.pixelSize: 13
                    color: root.ink
                }
            }
            WidgetBar {
                width: parent.width
                themeId: root.themeId
                value: row.level
            }
        }
    }
}
