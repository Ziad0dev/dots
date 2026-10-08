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
    visible: false

    function open() {
        visible = true;
        timer.forceActiveFocus();
    }
    function close() { visible = false; }
    function toggle() { visible ? close() : open(); }

    // click-away
    MouseArea {
        anchors.fill: parent
        onClicked: panel.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: timer.implicitWidth + 24
        height: timer.implicitHeight + 24
        radius: Services.DesktopTheme.panelRadius(20)
        color: Colors.withAlpha(Colors.surface_container, 0.96)
        border.width: 1
        border.color: Colors.withAlpha(Colors.primary, 0.45)

        // swallow clicks on the card itself
        MouseArea { anchors.fill: parent }

        PanelDecor {
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
