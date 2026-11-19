import QtQuick
import "../modules"

// Reminders: "remind me in 20 min" / "at 15:30" from the bar. Each one is a
// transient systemd user timer (dots-bar-tools remind) that sends a critical
// notification, so it survives a bar restart. After Omarchy 4.5's reminders.
ToolPanel {
    id: remPanel
    flag: "reminderVisible"
    title: "Reminders"
    namespace: "dots-reminders"
    cardWidth: 320

    property double nowMs: Date.now()
    Timer {
        interval: 1000; running: remPanel.visible; repeat: true; triggeredOnStart: true
        onTriggered: remPanel.nowMs = Date.now()
    }
    property string error: ""

    function pad(n) { return (n < 10 ? "0" : "") + n }
    function left(epochS) {
        var s = Math.max(0, Math.round(epochS - nowMs / 1000))
        if (s >= 3600) return Math.floor(s / 3600) + "h " + pad(Math.floor(s % 3600 / 60)) + "m"
        return Math.floor(s / 60) + ":" + pad(s % 60)
    }
    function clock(epochS) {
        var d = new Date(epochS * 1000)
        return pad(d.getHours()) + ":" + pad(d.getMinutes())
    }
    // "20", "20m", "1h", "1h30", "1h30m", "90s" -> seconds; "15:30" -> seconds until then (tomorrow if past)
    function parseWhen(s) {
        s = String(s || "").trim().toLowerCase().replace(/^(at|in)\s+/, "")
        var m = /^(\d{1,2}):(\d{2})$/.exec(s)
        if (m) {
            var now = new Date(), at = new Date()
            at.setHours(parseInt(m[1], 10), parseInt(m[2], 10), 0, 0)
            if (at <= now) at.setDate(at.getDate() + 1)
            return Math.round((at - now) / 1000)
        }
        m = /^(?:(\d+)h)?\s*(?:(\d+)\s*m?(?:in)?)?$/.exec(s)
        if (m && (m[1] || m[2])) return (parseInt(m[1] || "0", 10) * 60 + parseInt(m[2] || "0", 10)) * 60
        m = /^(\d+)\s*s$/.exec(s)
        if (m) return parseInt(m[1], 10)
        return -1
    }
    function add(seconds) {
        if (!(seconds >= 1)) { error = "When? e.g. 20, 1h30 or 15:30"; return }
        error = ""
        root.addReminder(seconds, what.text.trim() || "Reminder")
        what.text = ""
        when.text = ""
    }

    ToolField {
        id: what
        root: remPanel.root
        width: remPanel.innerWidth
        visible: !root.popout.hoverMode
        placeholder: "remind me to…"
        onAccepted: when.input.forceActiveFocus()
        onEscaped: remPanel.close()
    }

    // presets
    Row {
        width: remPanel.innerWidth
        spacing: 4
        visible: !root.popout.hoverMode
        Repeater {
            model: [["5m", 300], ["10m", 600], ["20m", 1200], ["30m", 1800], ["1h", 3600]]
            delegate: ToolButton {
                required property var modelData
                root: remPanel.root
                width: root.evenW((remPanel.innerWidth - 4 * 4) / 5)
                text: modelData[0]
                onClicked: remPanel.add(modelData[1])
            }
        }
    }

    Row {
        width: remPanel.innerWidth
        spacing: 6
        visible: !root.popout.hoverMode
        ToolField {
            id: when
            root: remPanel.root
            width: parent.width - addBtn.width - parent.spacing
            placeholder: "in 45 · 1h30 · at 15:30  ⏎"
            onAccepted: remPanel.add(remPanel.parseWhen(text))
            onEscaped: remPanel.close()
        }
        ToolButton {
            id: addBtn
            root: remPanel.root
            width: 64
            primary: true
            text: "Add"
            onClicked: remPanel.add(remPanel.parseWhen(when.text))
        }
    }

    UiText {
        width: remPanel.innerWidth
        visible: remPanel.error !== ""
        text: remPanel.error
        color: root.color01; font.family: root.mono; font.pixelSize: 10
    }

    Rectangle { width: remPanel.innerWidth; height: 1; color: root.sep; visible: root.reminders.length > 0 }

    UiText {
        visible: root.reminders.length === 0
        text: "Nothing pending"
        color: root.sumi; font.family: root.mono; font.pixelSize: 11
    }

    Repeater {
        model: root.reminders
        delegate: Rectangle {
            required property var modelData
            width: remPanel.innerWidth
            height: 26
            radius: root.tileRadius
            color: rowMa.containsMouse ? root.fillHover : "transparent"
            UiText {
                anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 140
                textFormat: Text.PlainText
                text: modelData.text
                color: root.ink; font.family: root.mono; font.pixelSize: 11; elide: Text.ElideRight
            }
            UiText {
                anchors.right: cancelX.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: remPanel.clock(modelData.next) + "  ·  " + remPanel.left(modelData.next)
                color: root.seal; font.family: root.mono; font.pixelSize: 10
            }
            UiText {
                id: cancelX
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: cxMa.containsMouse ? root.seal : root.sumi
                font.pixelSize: 10
                MouseArea { id: cxMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelReminder(modelData.unit) }
            }
            MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        }
    }
}
