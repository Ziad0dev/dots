import QtQuick
import Quickshell
import Quickshell.Io

// "Fans also like" for the playing artist: ListenBrainz's similar-artists data
// through `music-scout similar` (scripts/music-scout.py), which caches answers
// and marks the artists already in the beets library. Only fetches while
// `active` (the media panel is open). Hidden when there is nothing to show.
// A chip opens the artist's ListenBrainz page; a right click emits
// `secondary(name)`, which the Discover panel turns into a Soulseek search.
Item {
    id: sim

    signal secondary(string name)

    required property var root
    property bool active: false
    property string artist: ""
    property int limit: 8

    property var artists: []         // [{ name, mbid, score, owned }]
    property string loadedFor: ""
    readonly property bool hasArtists: artists.length > 0

    implicitHeight: hasArtists ? body.implicitHeight : 0
    Behavior on implicitHeight { Anim { kind: "size"; ms: 300 } }
    visible: hasArtists
    clip: true

    function maybeFetch() {
        if (!active || artist === "" || artist === loadedFor) return
        loadedFor = artist
        artists = []
        fetchProc.running = false
        fetchProc.command = ["music-scout", "similar", "--json", "--limit", String(limit), artist]
        fetchProc.running = true
    }
    onActiveChanged: maybeFetch()
    onArtistChanged: maybeFetch()

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                var d = null
                try { d = JSON.parse(this.text) } catch (e) { return }
                // a late answer for the previous track must not replace this one's
                if (d && d.artist === sim.artist && Array.isArray(d.similar)) sim.artists = d.similar
            }
        }
        // failed (offline, helper missing): allow a retry on the next open
        onExited: function (code) { if (code !== 0) sim.loadedFor = "" }
    }

    Column {
        id: body
        width: parent.width
        spacing: 6

        UiText {
            text: "SIMILAR ARTISTS"
            color: sim.root.sumiHi
            font.family: sim.root.mono; font.pixelSize: 9; font.letterSpacing: 1.5
        }

        Flow {
            width: parent.width
            spacing: 5

            Repeater {
                model: sim.artists
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    width: Math.min(label.implicitWidth + 14, body.width)
                    height: 20
                    radius: 10
                    color: chipMa.containsMouse ? sim.root.fillActive
                         : modelData.owned ? sim.root.fillHover : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(sim.root.ink.r, sim.root.ink.g, sim.root.ink.b,
                                          modelData.owned ? 0.0 : 0.18)
                    Behavior on color { CAnim { ms: 120 } }

                    UiText {
                        id: label
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, body.width - 14)
                        elide: Text.ElideRight
                        text: chip.modelData.name
                        // in the library already: the accent; new to you: plain ink
                        color: chip.modelData.owned ? sim.root.seal : sim.root.ink
                        font.family: sim.root.mono; font.pixelSize: 10
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) sim.secondary(chip.modelData.name)
                            else Quickshell.execDetached(
                                ["xdg-open", "https://listenbrainz.org/artist/" + chip.modelData.mbid])
                        }
                    }
                }
            }
        }
    }
}
