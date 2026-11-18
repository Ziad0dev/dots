pragma ComponentBehavior: Bound
// After lucid's lyrics widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import qs.ext.colors
import qs.ext.services as Services
import qs.modules

// The song's timed lyrics scrolling by, the line being sung lit, from the same
// LRCLIB fetcher and cache as the media panel (modules/SyncedLyrics.qml). It
// fetches only while something plays; a song without timed lyrics says so.
WidgetFrame {
    id: root

    readonly property var media: Services.Media
    readonly property bool playing: media.activePlayer !== null && media.title !== "No Media"

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("lyrics", themeId)
    seal: "詞"

    Text {
        width: 360
        elide: Text.ElideRight
        text: root.playing ? root.media.title + (root.media.artist ? "  ·  " + root.media.artist : "") : "Nothing playing"
        font.family: root.st.font
        font.pixelSize: 13
        font.weight: Font.Medium
        color: Colors.withAlpha(root.ink, 0.75)
    }

    SyncedLyrics {
        id: lyrics
        width: 360
        root: Services.Rise.theme
        active: root.playing
        title: root.media.title
        artist: root.media.artist
        album: root.media.album
        length: root.media.length
        position: root.media.position
        visibleLines: 7
        lineH: 26
        family: root.st.font
        currentColor: root.accent
        otherColor: Colors.withAlpha(root.ink, 0.55)
        currentSize: 17
        otherSize: 14
    }

    Text {
        visible: root.playing && !lyrics.hasLyrics
        text: "No timed lyrics for this song"
        font.family: root.st.font
        font.pixelSize: 13
        font.italic: true
        color: Colors.withAlpha(root.ink, 0.5)
    }
}
