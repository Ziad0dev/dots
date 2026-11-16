import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Music discovery (SUPER+SHIFT+D): artists similar to the one playing, artists to try
// picked from the whole library, and releases by library artists that the beets
// library lacks, plus the albums of an imported Spotify export (most played, liked
// or saved) that the library lacks. All come from `music-scout` (scripts/music-scout.py). The
// two lists paint at once from the previous run's result, then refresh in the
// background — a full check walks every library artist on MusicBrainz at
// 1 request/s, so it can take minutes.
// The "slsk" buttons (and a right click on a similar-artist chip) hand a query
// to `slsk-search`, which opens it as a search tab in Nicotine+.
PanelWindow {
    id: dp
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-discover"

    readonly property int barBottom: 35
    readonly property int gap: 8

    MprisSelect { id: sel }
    readonly property string artist: sel.player ? (sel.player.trackArtist || "") : ""
    // "Song (2011 Remaster) [Live]" -> "Song": the point is to find the others
    readonly property string track: sel.player
        ? (sel.player.trackTitle || "").replace(/\s*[\(\[].*?[\)\]]/g, "").replace(/\s+-\s+.*$/, "").trim()
        : ""

    function slsk(query) {
        Quickshell.execDetached(["slsk-search", query])
        root.discoverVisible = false
    }

    property var weekly: ({ title: "", tracks: [] })   // ListenBrainz's playlist for the week
    // [{ artist, album, why, plays, liked, saved, bandcamp, qobuz }]; empty without a Spotify import
    property var missing: []
    property var picks: []           // [{ name, mbid, score, because: [names] }]
    readonly property bool picking: picksRefresh.running

    property var releases: []        // [{ artist, title, date, type, id }]
    property bool loadedOnce: false
    readonly property bool checking: refreshProc.running
    readonly property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")

    function parse(text) {
        var d = null
        try { d = JSON.parse(text) } catch (e) { return }
        if (Array.isArray(d)) { dp.releases = d; dp.loadedOnce = true }
    }
    function parsePicks(text) {
        var d = null
        try { d = JSON.parse(text) } catch (e) { return }
        if (Array.isArray(d)) dp.picks = d
    }

    property bool open: root.discoverVisible
    onOpenChanged: if (open) {
        lastProc.running = true; refreshProc.running = true
        picksLast.running = true; picksRefresh.running = true
        missingProc.running = true
        weeklyProc.running = true
    }

    Process {
        id: weeklyProc
        command: ["music-scout", "weekly", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = null
                try { d = JSON.parse(this.text) } catch (e) { return }
                if (d && Array.isArray(d.tracks)) dp.weekly = d
            }
        }
    }

    Process {
        id: missingProc
        command: ["music-scout", "missing", "--json", "--limit", "10"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = null
                try { d = JSON.parse(this.text) } catch (e) { return }
                if (Array.isArray(d)) dp.missing = d
            }
        }
    }

    Process {
        id: picksLast
        command: ["music-scout", "foryou", "--json", "--last"]
        stdout: StdioCollector { onStreamFinished: dp.parsePicks(this.text) }
    }
    Process {
        id: picksRefresh
        command: ["music-scout", "foryou", "--json", "--limit", "12"]
        stdout: StdioCollector { onStreamFinished: dp.parsePicks(this.text) }
    }

    Process {
        id: lastProc
        command: ["music-scout", "new", "--json", "--last"]
        stdout: StdioCollector { onStreamFinished: dp.parse(this.text) }
    }
    Process {
        id: refreshProc
        command: ["music-scout", "new", "--json"]
        stdout: StdioCollector { onStreamFinished: dp.parse(this.text) }
    }

    property real reveal: root.discoverVisible ? 1 : 0
    Behavior on reveal {
        Anim { kind: root.discoverVisible ? "spatial" : "exit" }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.discoverVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.discoverVisible = false }

    FrameCard { root: dp.root; card: card; reveal: dp.reveal }
    Rectangle {
        id: card
        width: 440
        height: Math.min(col.implicitHeight + 24, parent.height - dp.barBottom - dp.gap * 2)
        radius: root.pillRadius
        color: root.frameCardBg
        border.color: root.pillBorder
        border.width: root.frameCardBorderW

        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom"
            ? (parent.height - dp.barBottom - dp.gap - height)
            : (dp.barBottom + dp.gap)
        opacity: dp.reveal
        transformOrigin: root.barPosition === "bottom" ? Item.Bottom : Item.Top
        scale: root.motionHover ? (0.92 + 0.08 * dp.reveal) : 1
        focus: root.discoverVisible
        clip: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.discoverVisible = false; event.accepted = true }
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
                spacing: 10

                Item {
                    width: parent.width
                    height: 24
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DISCOVER"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: closeMa.containsMouse ? root.seal : root.sumi
                        font.pixelSize: 12
                        Behavior on color { CAnim { ms: 120 } }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.discoverVisible = false
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.sep }

                // ── similar to what's playing ──
                Item {
                    width: parent.width
                    height: 18
                    UiText {
                        anchors.left: parent.left
                        anchors.right: versions.visible ? versions.left : parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: dp.artist !== ""
                            ? "Playing: " + dp.artist + (dp.track !== "" ? " – " + dp.track : "")
                            : "Nothing playing"
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }
                    // the bought copy is playing; look for the others on Soulseek
                    SlskButton {
                        root: dp.root
                        onLaunched: dp.root.discoverVisible = false
                        id: versions
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: dp.artist !== "" && dp.track !== ""
                        label: "other versions"
                        query: dp.artist + " " + dp.track
                    }
                }
                SimilarArtists {
                    id: similar
                    width: parent.width
                    root: dp.root
                    active: root.discoverVisible
                    artist: dp.artist
                    limit: 18
                    onSecondary: function (name) { dp.slsk(name) }
                }
                UiText {
                    visible: !similar.hasArtists
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: dp.artist === "" ? "Play something to see similar artists."
                                           : "No similar artists known for this one."
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 11
                }

                // ── ListenBrainz's weekly exploration; absent until it has made one ──
                Rectangle { visible: dp.weekly.tracks.length > 0; width: parent.width; height: 1; color: root.sep }
                UiText {
                    visible: dp.weekly.tracks.length > 0
                    width: parent.width
                    elide: Text.ElideRight
                    text: dp.weekly.title.toUpperCase()
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                }
                Repeater {
                    model: dp.weekly.tracks.slice(0, 15)
                    delegate: Rectangle {
                        id: wk
                        required property var modelData
                        width: col.width
                        height: 34
                        radius: 5
                        color: wkMa.containsMouse ? root.fillHover : "transparent"
                        Behavior on color { CAnim { ms: 120 } }

                        MouseArea {
                            id: wkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(
                                ["xdg-open", "https://musicbrainz.org/recording/" + wk.modelData.mbid])
                        }
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 6
                            anchors.right: wkSlsk.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            UiText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: wk.modelData.title
                                // already in the library: the accent
                                color: wk.modelData.owned ? root.seal : root.ink
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            UiText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: wk.modelData.artist
                                color: root.sumiHi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                        }
                        SlskButton {
                            id: wkSlsk
                            root: dp.root
                            onLaunched: dp.root.discoverVisible = false
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !wk.modelData.owned
                            query: wk.modelData.artist + " " + wk.modelData.title
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.sep }

                // ── artists to try, from the whole library ──
                Item {
                    width: parent.width
                    height: 14
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FOR YOU"
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: dp.picking
                        text: "checking…"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 9
                    }
                }
                UiText {
                    visible: dp.picks.length === 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: dp.picking ? "Comparing every artist in the library. The first run takes a few minutes."
                                     : "No suggestions yet."
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 11
                }
                Repeater {
                    model: dp.picks.slice(0, 12)
                    delegate: Rectangle {
                        id: pick
                        required property var modelData
                        width: col.width
                        height: 34
                        radius: 5
                        color: pickMa.containsMouse ? root.fillHover : "transparent"
                        Behavior on color { CAnim { ms: 120 } }

                        MouseArea {
                            id: pickMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(
                                ["xdg-open", "https://listenbrainz.org/artist/" + pick.modelData.mbid])
                        }
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 6
                            anchors.right: pickSlsk.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            UiText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: pick.modelData.name
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            UiText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: "like " + (pick.modelData.because || []).join(", ")
                                color: root.sumiHi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                        }
                        SlskButton {
                            root: dp.root
                            onLaunched: dp.root.discoverVisible = false
                            id: pickSlsk
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            query: pick.modelData.name
                        }
                    }
                }

                // ── played, liked or saved on Spotify, not in the library ──
                Rectangle { visible: dp.missing.length > 0; width: parent.width; height: 1; color: root.sep }
                Item {
                    visible: dp.missing.length > 0
                    width: parent.width
                    height: 18
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FROM SPOTIFY, NOT IN YOUR LIBRARY"
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }
                    // every one of them, as a page of store links
                    LinkPill {
                        root: dp.root
                        onLaunched: dp.root.discoverVisible = false
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        label: "buy list"
                        command: ["music-scout", "buylist"]
                    }
                }
                Repeater {
                    model: dp.missing
                    delegate: Rectangle {
                        id: miss
                        required property var modelData
                        width: col.width
                        height: 34
                        radius: 5
                        color: missMa.containsMouse ? root.fillHover : "transparent"
                        Behavior on color { CAnim { ms: 120 } }

                        MouseArea { id: missMa; anchors.fill: parent; hoverEnabled: true }
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 6
                            anchors.right: missLinks.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            UiText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: miss.modelData.album
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            UiText {
                                width: parent.width
                                elide: Text.ElideRight
                                // "Deftones · 2285 plays · 10 liked · saved"
                                text: miss.modelData.artist + " · " + miss.modelData.why
                                color: root.sumiHi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                        }
                        // buy it (store search pages), or look for it on Soulseek
                        Row {
                            id: missLinks
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            LinkPill {
                                root: dp.root
                                onLaunched: dp.root.discoverVisible = false
                                label: "bandcamp"
                                url: miss.modelData.bandcamp || ""
                            }
                            LinkPill {
                                root: dp.root
                                onLaunched: dp.root.discoverVisible = false
                                label: "qobuz"
                                url: miss.modelData.qobuz || ""
                            }
                            SlskButton {
                                root: dp.root
                                onLaunched: dp.root.discoverVisible = false
                                query: miss.modelData.artist + " " + miss.modelData.album
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.sep }

                // ── new releases ──
                Item {
                    width: parent.width
                    height: 14
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "NEW FROM YOUR ARTISTS"
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: dp.checking
                        text: "checking…"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 9
                    }
                }
                UiText {
                    visible: dp.releases.length === 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: dp.checking
                        ? "Asking MusicBrainz about every artist in the library. The first check takes a few minutes."
                        : dp.loadedOnce ? "Nothing new in the last 90 days."
                        : "Couldn't run music-scout."
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 11
                }

                Repeater {
                    model: dp.releases
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool upcoming: modelData.date > dp.today
                        width: col.width
                        height: 34
                        radius: 5
                        color: rowMa.containsMouse ? root.fillHover : "transparent"
                        Behavior on color { CAnim { ms: 120 } }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(
                                ["xdg-open", "https://musicbrainz.org/release-group/" + row.modelData.id])
                        }
                        UiText {
                            id: when
                            anchors.left: parent.left; anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 74
                            text: row.modelData.date
                            color: row.upcoming ? root.seal : root.sumi
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                        Column {
                            anchors.left: when.right; anchors.leftMargin: 6
                            anchors.right: kind.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            UiText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.title
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            UiText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.artist
                                color: root.sumiHi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                        }
                        UiText {
                            id: kind
                            anchors.right: rowSlsk.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.upcoming ? "soon" : (row.modelData.type || "")
                            color: row.upcoming ? root.seal : root.sumi
                            font.family: root.mono
                            font.pixelSize: 9
                            font.letterSpacing: 1
                        }
                        // not out yet: nothing to find
                        SlskButton {
                            root: dp.root
                            onLaunched: dp.root.discoverVisible = false
                            id: rowSlsk
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !row.upcoming
                            width: visible ? implicitWidth : 0
                            // "Composer; Orchestra, Conductor" -> the first name
                            query: row.modelData.artist.split(";")[0] + " " + row.modelData.title
                        }
                    }
                }
            }
        }
    }
}
