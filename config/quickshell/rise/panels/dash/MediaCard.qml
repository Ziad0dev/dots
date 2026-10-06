import QtQuick
import QtQuick.Effects
import "../../modules"

// Dashboard-tab media column: the cover under a wavy progress arc, the track,
// and previous · play/pause · next.
Item {
    id: mc
    required property var dash
    readonly property var player: dash.player
    readonly property bool playing: dash.playing

    readonly property real progress: player && player.length > 0 ? Math.min(1, dash.pos / player.length) : 0

    // the arc's wave drifts while playing; 30 steps a second is smooth for a slow
    // wave and keeps the open dashboard from redrawing at the display's rate
    property real phase: 0
    Timer {
        interval: 33; repeat: true
        running: mc.playing && mc.visible
        onTriggered: mc.phase = (mc.phase - 0.1) % (2 * Math.PI)
    }

    Column {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Item {
            width: parent.width
            height: width - 8
            Ring {
                id: arc
                anchors.fill: cover
                anchors.margins: -(4 + thickness + waveAmp)
                startAngle: 180
                sweep: 180
                thickness: 6
                value: mc.progress
                color: mc.dash.primary
                trackColor: mc.dash.secondaryContainer
                wavy: true
                waveCount: 8
                phase: mc.phase
            }
            Rectangle {
                id: cover
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12 + 4 + 6 + 2.2
                width: parent.width - 2 * y; height: width
                radius: width / 2
                color: mc.dash.surfaceContainerHigh
                IconText {
                    anchors.centerIn: parent
                    visible: coverImg.status !== Image.Ready
                    text: "art_track"
                    color: mc.dash.onSurfaceVariant
                    font.pointSize: 36
                }
                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: mc.player ? (mc.player.trackArtUrl || "") : ""
                    sourceSize.width: 320
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: coverImg
                    visible: coverImg.status === Image.Ready
                    maskEnabled: true
                    maskSource: coverMask
                }
                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
            }
        }

        DText {
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            topPadding: 12
            text: mc.player ? (mc.player.trackTitle || "Unknown title") : "No media"
            color: mc.dash.primary
            font.pointSize: 14; font.weight: Font.Medium
        }
        DText {
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            topPadding: 8
            text: mc.player ? (mc.player.trackAlbum || "Unknown album") : "No media"
            color: mc.dash.outline
        }
        DText {
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            topPadding: 8
            text: mc.player ? (mc.player.trackArtist || "Unknown artist") : "No media"
            color: mc.dash.secondary
            font.pointSize: 13
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 14
            spacing: 4
            DButton {
                dash: mc.dash; icon: "skip_previous"
                active: !!mc.player && mc.player.canGoPrevious
                onClicked: mc.player.previous()
            }
            DButton {
                dash: mc.dash
                width: 72
                icon: mc.playing ? "pause" : "play_arrow"
                checked: mc.playing
                active: !!mc.player && mc.player.canTogglePlaying
                onClicked: mc.player.togglePlaying()
            }
            DButton {
                dash: mc.dash; icon: "skip_next"
                active: !!mc.player && mc.player.canGoNext
                onClicked: mc.player.next()
            }
        }

        DText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: 14
            visible: !!mc.player
            text: mc.player ? (mc.player.identity || "") + (mc.player.length > 0 ? "  ·  " + mc.dash.clock(mc.dash.pos) + " / " + mc.dash.clock(mc.player.length) : "") : ""
            color: mc.dash.onSurfaceVariant
            font.pointSize: 9
        }
    }
}
