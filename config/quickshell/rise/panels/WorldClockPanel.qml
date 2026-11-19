import QtQuick
import "../modules"

// World clock: the time in several zones at once, with the difference to
// local time and day/night. After Omarchy 4.5's "Elsewhen" panel (without its
// globe). Zones live in ~/.local/state/dots/worldclock (Theme: wc*).
ToolPanel {
    id: wcPanel
    flag: "worldClockVisible"
    title: "World clock"
    namespace: "dots-worldclock"
    cardWidth: 320

    property double nowMs: Date.now()
    Timer {
        interval: 1000
        running: wcPanel.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: wcPanel.nowMs = Date.now()
    }
    readonly property int localOffset: -new Date(nowMs).getTimezoneOffset()

    function pad(n) { return (n < 10 ? "0" : "") + n }
    // the zone's wall clock as a UTC-based Date
    function zoneDate(offset) { return new Date(nowMs + offset * 60000) }
    function city(zone) {
        var parts = String(zone).split("/")
        return parts[parts.length - 1].replace(/_/g, " ")
    }
    function diffLabel(offset) {
        var d = offset - localOffset
        if (d === 0) return "same time"
        var h = Math.floor(Math.abs(d) / 60), m = Math.abs(d) % 60
        return (d > 0 ? "+" : "−") + h + (m ? ":" + pad(m) : "") + "h"
    }
    function dayLabel(offset) {
        var here = new Date(nowMs + localOffset * 60000).getUTCDate()
        var there = zoneDate(offset).getUTCDate()
        if (there === here) return ""
        // across a month boundary the bigger date can be "yesterday"
        var ahead = (offset - localOffset) > 0
        return ahead ? "tomorrow" : "yesterday"
    }

    Repeater {
        model: root.wcZones
        delegate: Rectangle {
            required property string modelData
            readonly property var offset: root.wcOffsets[modelData]
            readonly property var date: offset === undefined ? null : wcPanel.zoneDate(offset)
            readonly property int hour: date ? date.getUTCHours() : 12
            width: wcPanel.innerWidth
            height: 36
            radius: root.tileRadius
            color: rowMa.containsMouse ? root.fillHover : root.fillIdle

            IconText {
                id: sky
                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: parent.hour >= 7 && parent.hour < 19 ? "light_mode" : "dark_mode"
                color: parent.hour >= 7 && parent.hour < 19 ? root.seal : root.sumiHi
                font.pixelSize: 15
            }
            Column {
                anchors.left: sky.right; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                UiText {
                    textFormat: Text.PlainText
                    text: wcPanel.city(modelData)
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                }
                UiText {
                    text: parent.parent.offset === undefined ? "…"
                        : wcPanel.diffLabel(parent.parent.offset)
                          + (wcPanel.dayLabel(parent.parent.offset) ? " · " + wcPanel.dayLabel(parent.parent.offset) : "")
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
                }
            }
            UiText {
                anchors.right: removeX.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: parent.date ? wcPanel.pad(parent.date.getUTCHours()) + ":" + wcPanel.pad(parent.date.getUTCMinutes()) : "--:--"
                color: root.seal; font.family: root.mono; font.pixelSize: 18; font.weight: Font.Medium
            }
            UiText {
                id: removeX
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                opacity: rowMa.containsMouse ? 1 : 0
                color: rmMa.containsMouse ? root.seal : root.sumi
                font.pixelSize: 10
                MouseArea { id: rmMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.wcRemove(modelData) }
            }
            MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        }
    }

    ToolField {
        id: addField
        root: wcPanel.root
        width: wcPanel.innerWidth
        visible: !root.popout.hoverMode
        placeholder: "add a zone, e.g. Asia/Kolkata  ⏎"
        onAccepted: { root.wcAdd(text); text = "" }
        onEscaped: wcPanel.close()
    }
    UiText {
        width: wcPanel.innerWidth
        visible: root.wcAddError !== ""
        textFormat: Text.PlainText
        text: root.wcAddError
        color: root.color01; font.family: root.mono; font.pixelSize: 10
        wrapMode: Text.WordWrap
    }
}
