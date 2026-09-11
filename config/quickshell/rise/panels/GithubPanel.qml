import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: ghPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-github-inbox"

    readonly property int barBottom: 35
    readonly property int gap: 8

    property string filterText: ""
    property string selectedOrg: ""

    property real reveal: root.githubVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.githubVisible ? 160 : 120
            easing.type: root.githubVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.githubVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (!visible) { filterText = ""; selectedOrg = "" }

    function matches(item) {
        if (selectedOrg && String(item.org || "") !== selectedOrg) return false
        if (!filterText) return true
        var q = filterText.toLowerCase()
        return String(item.title || "").toLowerCase().indexOf(q) >= 0
            || String(item.repo || "").toLowerCase().indexOf(q) >= 0
    }

    function filtered(list) {
        var out = []
        for (var i = 0; i < list.length; i++) if (matches(list[i])) out.push(list[i])
        return out
    }

    readonly property var orgs: {
        var seen = {}
        var all = root.ghPrs.concat(root.ghReviews, root.ghIssues, root.ghMentions, root.ghNotifications)
        for (var i = 0; i < all.length; i++) {
            var o = String(all[i].org || "")
            if (o) seen[o] = true
        }
        return Object.keys(seen).sort()
    }

    readonly property var fPrs: filtered(root.ghPrs)
    readonly property var fReviews: filtered(root.ghReviews)
    readonly property var fIssues: filtered(root.ghIssues)
    readonly property var fMentions: filtered(root.ghMentions)
    readonly property var fNotifications: filtered(root.ghNotifications)
    readonly property var fClosed: filtered(root.ghClosed)

    MouseArea {
        anchors.fill: parent
        onClicked: root.githubVisible = false
    }

    component SectionLabel: Item {
        property string label: ""
        property int count: 0
        width: parent ? parent.width : 0
        height: visible ? 18 : 0
        UiText {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: label
            color: ghPanel.root.sumiHi
            font.family: ghPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
        }
        UiText {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: String(count)
            color: ghPanel.root.sumi
            font.family: ghPanel.root.mono; font.pixelSize: 10
        }
    }

    component ItemRow: Rectangle {
        id: rowRoot
        property var entry: null
        property bool unread: false
        property string kindMark: ""
        property var onActivate: null
        width: parent ? parent.width : 0
        height: 34
        radius: 4
        color: rowHover.containsMouse
            ? Qt.rgba(ghPanel.root.seal.r, ghPanel.root.seal.g, ghPanel.root.seal.b, 0.10)
            : "transparent"

        Rectangle {
            id: unreadDot
            visible: rowRoot.unread
            width: 5; height: 5; radius: 2.5
            color: ghPanel.root.color01
            anchors.left: parent.left; anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            UiText {
                width: parent.width
                text: String((rowRoot.entry && rowRoot.entry.title) || "")
                elide: Text.ElideRight
                color: ghPanel.root.ink
                font.family: ghPanel.root.mono; font.pixelSize: 11
            }
            UiText {
                width: parent.width
                text: {
                    var e = rowRoot.entry || {}
                    var n = e.number ? "#" + e.number : ""
                    var d = e.draft ? "  draft" : ""
                    return String(e.repo || "") + (n ? "  " + n : "") + d
                        + (rowRoot.kindMark ? "  " + rowRoot.kindMark : "")
                }
                elide: Text.ElideRight
                color: ghPanel.root.sumi
                font.family: ghPanel.root.mono; font.pixelSize: 9
            }
        }

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (rowRoot.onActivate) rowRoot.onActivate(rowRoot.entry)
        }
    }

    Rectangle {
        id: card
        width: 420
        height: Math.min(col.implicitHeight + 24, parent.height - 2 * (barBottom + gap))
        radius: reveal > 0.001 ? ghPanel.root.pillRadius : 0
        color: ghPanel.root.bg
        border.color: ghPanel.root.pillBorder
        border.width: ghPanel.root.pillBorderW
        PillShadow { theme: ghPanel.root }

        x: Math.round(Math.max(6, Math.min(ghPanel.root.githubBarX - width / 2, parent.width - width - 6)))
        y: ghPanel.root.barPosition === "bottom"
            ? (parent.height - ghPanel.barBottom - ghPanel.gap - height)
            : (ghPanel.barBottom + ghPanel.gap)
        opacity: ghPanel.reveal
        focus: ghPanel.root.githubVisible

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                if (ghPanel.filterText) ghPanel.filterText = ""
                else ghPanel.root.githubVisible = false
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                ghPanel.filterText = ghPanel.filterText.slice(0, -1)
                event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text >= " ") {
                ghPanel.filterText += event.text
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: scroller.width
                spacing: 6

                Item {
                    width: parent.width
                    height: 20
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: ghPanel.root.ghUser ? "@" + ghPanel.root.ghUser : "GITHUB"
                        color: ghPanel.root.ink
                        font.family: ghPanel.root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: ghPanel.filterText ? "/" + ghPanel.filterText : ghPanel.root.ghFetchedAgo()
                        color: ghPanel.filterText ? ghPanel.root.seal : ghPanel.root.sumi
                        font.family: ghPanel.root.mono; font.pixelSize: 10
                    }
                }

                UiText {
                    visible: ghPanel.root.ghError !== ""
                    width: parent.width
                    text: ghPanel.root.ghError
                    wrapMode: Text.WordWrap
                    color: ghPanel.root.color01
                    font.family: ghPanel.root.mono; font.pixelSize: 10
                }

                Flow {
                    width: parent.width
                    spacing: 4
                    visible: ghPanel.orgs.length > 1
                    Repeater {
                        model: ghPanel.orgs
                        delegate: Rectangle {
                            id: orgChip
                            required property string modelData
                            readonly property bool picked: ghPanel.selectedOrg === orgChip.modelData
                            height: 18
                            width: orgLabel.implicitWidth + 14
                            radius: 9
                            color: orgChip.picked
                                ? Qt.rgba(ghPanel.root.seal.r, ghPanel.root.seal.g, ghPanel.root.seal.b, 0.22)
                                : "transparent"
                            border.width: 1
                            border.color: ghPanel.root.pillBorder
                            UiText {
                                id: orgLabel
                                anchors.centerIn: parent
                                text: orgChip.modelData
                                color: orgChip.picked ? ghPanel.root.ink : ghPanel.root.sumi
                                font.family: ghPanel.root.mono; font.pixelSize: 9
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ghPanel.selectedOrg = orgChip.picked ? "" : orgChip.modelData
                            }
                        }
                    }
                }

                SectionLabel { label: "PULL REQUESTS"; count: ghPanel.fPrs.length; visible: ghPanel.fPrs.length > 0 }
                Repeater {
                    model: ghPanel.fPrs
                    delegate: ItemRow {
                        required property var modelData
                        entry: modelData
                        onActivate: function (e) { ghPanel.root.ghOpen(e) }
                    }
                }

                SectionLabel { label: "REVIEW REQUESTS"; count: ghPanel.fReviews.length; visible: ghPanel.fReviews.length > 0 }
                Repeater {
                    model: ghPanel.fReviews
                    delegate: ItemRow {
                        required property var modelData
                        entry: modelData
                        onActivate: function (e) { ghPanel.root.ghOpen(e) }
                    }
                }

                SectionLabel { label: "ISSUES"; count: ghPanel.fIssues.length; visible: ghPanel.fIssues.length > 0 }
                Repeater {
                    model: ghPanel.fIssues
                    delegate: ItemRow {
                        required property var modelData
                        entry: modelData
                        onActivate: function (e) { ghPanel.root.ghOpen(e) }
                    }
                }

                SectionLabel { label: "MENTIONS"; count: ghPanel.fMentions.length; visible: ghPanel.fMentions.length > 0 }
                Repeater {
                    model: ghPanel.fMentions
                    delegate: ItemRow {
                        required property var modelData
                        entry: modelData
                        unread: ghPanel.root.ghMentionUnread(modelData)
                        onActivate: function (e) { ghPanel.root.ghMarkSeen(e); ghPanel.root.ghOpen(e) }
                    }
                }

                SectionLabel { label: "NOTIFICATIONS"; count: ghPanel.fNotifications.length; visible: ghPanel.fNotifications.length > 0 }
                Repeater {
                    model: ghPanel.fNotifications
                    delegate: ItemRow {
                        required property var modelData
                        entry: modelData
                        kindMark: String(modelData.reason || "")
                        onActivate: function (e) { ghPanel.root.ghDismissNotification(e); ghPanel.root.ghOpen(e) }
                    }
                }

                SectionLabel { label: "RECENTLY CLOSED"; count: ghPanel.fClosed.length; visible: ghPanel.fClosed.length > 0 }
                Repeater {
                    model: ghPanel.fClosed
                    delegate: ItemRow {
                        required property var modelData
                        entry: modelData
                        kindMark: String(modelData.kind || "")
                        onActivate: function (e) { ghPanel.root.ghOpen(e) }
                    }
                }

                UiText {
                    visible: ghPanel.fPrs.length + ghPanel.fReviews.length + ghPanel.fIssues.length
                        + ghPanel.fMentions.length + ghPanel.fNotifications.length + ghPanel.fClosed.length === 0
                        && ghPanel.root.ghError === ""
                    width: parent.width
                    text: ghPanel.filterText || ghPanel.selectedOrg ? "nothing matches" : "inbox clear"
                    horizontalAlignment: Text.AlignHCenter
                    color: ghPanel.root.sumi
                    font.family: ghPanel.root.mono; font.pixelSize: 11
                }
            }
        }
    }
}
