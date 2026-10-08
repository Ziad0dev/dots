import QtQuick
import qs.ext.colors
import qs.ext.components
import qs.ext.services as Services

// rise: the countdown timer (TimerComponent, from dhrruvsharma/shell's GitHub
// popout) as a panel of its own, opened from the Utilities corner or
// `qs -c rise ipc call timer toggle`. ExtRoot keeps it loaded once opened, so
// a countdown carries on while it's closed.
Item {
    id: panel

    anchors.fill: parent
    // rise: hangs from the bar (FrameDock); visible until it has slid back in
    property bool opened: false
    visible: opened || dock.open

    function open() {
        opened = true;
        timer.forceActiveFocus();
    }
    function close() { opened = false; }
    function toggle() { opened ? close() : open(); }

    FrameDock {
        id: dock
        card: card
        shown: panel.opened
    }

    // click-away
    MouseArea {
        anchors.fill: parent
        onClicked: panel.close()
    }

    Rectangle {
        id: card
        x: dock.cardX
        y: dock.cardY
        width: timer.implicitWidth + 24
        height: timer.implicitHeight + 24
        opacity: dock.reveal
        transform: dock.slide
        radius: dock.framed ? dock.radius : Services.DesktopTheme.panelRadius(20)
        color: dock.framed ? "transparent" : Colors.withAlpha(Colors.surface_container, 0.96)
        border.width: dock.framed ? 0 : 1
        border.color: Colors.withAlpha(Colors.primary, 0.45)

        // swallow clicks on the card itself
        MouseArea { anchors.fill: parent }

        PanelDecor {
            visible: !dock.framed
            radius: card.radius
            title: "timer"
        }

        TimerComponent {
            id: timer
            anchors.centerIn: parent
            Keys.onEscapePressed: panel.close()
        }
    }
}
