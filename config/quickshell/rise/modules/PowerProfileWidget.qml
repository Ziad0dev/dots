import QtQuick
import Quickshell

Item {
    id: rootMod
    required property var root
    property string gid: "G14"

    readonly property string profile: root.powerProfileCurrent

    readonly property bool isPowerSaver:  profile === "power-saver"
    readonly property bool isBalanced:    profile === "balanced"
    readonly property bool isPerformance: profile === "performance"

    readonly property string shortName: {
        if (isPowerSaver)  return "SAV"
        if (isPerformance) return "PRF"
        return "BAL"
    }

    readonly property string profileIcon: {
        if (isPowerSaver)  return "\uF06C"
        if (isPerformance) return "\uF0E7"
        return "\uF24E"
    }

    readonly property color profileColor: {
        if (isPowerSaver)  return root.indigo
        if (isPerformance) return root.seal
        return root.seal
    }

    readonly property string tooltipText: {
        if (isPowerSaver)  return "Power Saver"
        if (isPerformance) return "Performance"
        return "Balanced"
    }

    visible: implicitWidth > 0.5
    implicitWidth: root.modPower ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modPower ? 1 : 0

    Behavior on opacity { Anim { kind: "effects"; ms: 140 } }

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.widgetFillColor(rootMod.gid)
        border.color: root.widgetBorderColor(rootMod.gid)
        border.width: root.widgetBorderWidth(rootMod.gid)
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        BarLabel {
            root: rootMod.root
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compactPower
            label: "PWR"
            glyph: "bolt"
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.compactPower
            text: rootMod.profileIcon
            renderType: Text.QtRendering
            color: rootMod.profileColor
            font.family: root.mono
            font.pixelSize: rootMod.isBalanced ? 13 : 14
            Behavior on color { CAnim { ms: 200 } }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compactPower
            text: rootMod.shortName
            color: rootMod.profileColor
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { CAnim { ms: 200 } }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText; popout: "powerProfileVisible" }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) {
                var profiles = ["power-saver", "balanced", "performance"]
                var idx = profiles.indexOf(root.powerProfileCurrent)
                root.setPowerProfile(profiles[(Math.max(0, idx) + 1) % profiles.length])
            } else {
                root.popout.click("powerProfileVisible")
            }
        }
    }
}
