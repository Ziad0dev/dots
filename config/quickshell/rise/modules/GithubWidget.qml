import QtQuick

Item {
    id: rootMod
    required property var root
    property string gid: "G18"

    readonly property int workCount: root.ghWorkCount
    readonly property int unreadMentions: root.ghUnreadMentions
    readonly property int notifCount: root.ghNotifCount
    readonly property bool broken: root.ghError !== ""
    readonly property bool attention: unreadMentions > 0 || notifCount > 0

    readonly property bool shown: root.modGithub

    visible: implicitWidth > 0.5
    implicitWidth: shown ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property string tooltipText: {
        if (broken) return "GitHub: " + root.ghError
        var lines = []
        if (root.ghUser) lines.push("@" + root.ghUser)
        lines.push("pull requests: " + root.ghPrs.length)
        lines.push("review requests: " + root.ghReviews.length)
        lines.push("assigned issues: " + root.ghIssues.length)
        if (unreadMentions > 0) lines.push("unread mentions: " + unreadMentions)
        if (notifCount > 0) lines.push("notifications: " + notifCount)
        var age = root.ghFetchedAgo()
        if (age) lines.push("updated " + age)
        return lines.join("\n")
    }

    Rectangle {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
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

        Item {
            id: glyphItem
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: glyph.implicitWidth
            implicitHeight: glyph.implicitHeight

            UiText {
                id: glyph
                text: String.fromCodePoint(0xF09B)
                renderType: Text.QtRendering
                color: rootMod.broken
                    ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                    : root.widgetContentColor(rootMod.gid, root.seal)
                font.family: root.mono
                font.pixelSize: 14
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Rectangle {
                id: dot
                visible: rootMod.attention && !rootMod.broken
                width: 6; height: 6; radius: 3
                color: root.color01
                anchors.right: parent.right
                anchors.rightMargin: -2
                anchors.top: parent.top
                anchors.topMargin: -1
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.broken ? "··" : String(rootMod.workCount).padStart(2, "0")
            color: rootMod.broken
                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                : root.widgetContentColor(rootMod.gid, Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.85))
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: if (rootMod.shown) { root.refreshGithub(); tip.show() }
        onExited: tip.hide()
        onClicked: function (e) {
            tip.hide()
            if (e.button === Qt.MiddleButton) { root.refreshGithub(true); return }
            root.githubVisible = !root.githubVisible
        }
    }
}
