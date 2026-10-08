pragma ComponentBehavior: Bound
// Ported from dhrruvsharma/shell (quickshell/modules/pet/PetHub.qml), GPL-3.0-or-later.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.ext.services as Services
import qs.ext.components

// The pet's hub (PetHubCard) in a window hanging from the bar under the
// pet, while Services.Pet.hubOpen. It takes the keyboard while it's open
// and closes on Esc, on a click anywhere else, or on the pet again. The
// window exists only while it's showing.
Scope {
    id: root

    property bool up: false
    // Where the pet was when it opened (the card stays put while it walks);
    // -1 to centre it, when the pet isn't in the bar.
    property real anchorX: -1

    Connections {
        target: Services.Pet

        function onHubOpenChanged() {
            if (Services.Pet.hubOpen) {
                root.anchorX = Services.Pet.shown && Services.Pet.barX > 0 ? Services.Pet.barX : -1;
                root.up = true;
            }
        }
    }

    // Unloads once it has slid back into the bar.
    property bool sliding: false
    Timer {
        interval: 120
        running: root.up && !Services.Pet.hubOpen && !root.sliding
        onTriggered: root.up = false
    }

    LazyLoader {
        active: root.up

        PanelWindow {
            id: win

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dots-ext-pet-hub"
            screen: Services.Pet.barScreen
            WlrLayershell.keyboardFocus: Services.Pet.hubOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            // A click anywhere else closes it.
            MouseArea {
                anchors.fill: parent
                enabled: Services.Pet.hubOpen
                acceptedButtons: Qt.AllButtons
                onClicked: Services.Pet.hubOpen = false
            }

            // rise: hangs from the bar under the pet, docked in rise's frame
            FrameDock {
                id: dock
                card: holder
                shown: Services.Pet.hubOpen
                screenName: Services.Pet.barScreen ? Services.Pet.barScreen.name : ""
                onOpenChanged: root.sliding = open
            }

            Item {
                id: holder

                // the frame blob's corners (FrameBlobs reads card.radius)
                readonly property real radius: dock.radius
                x: root.anchorX < 0 ? (win.width - width) / 2 : Math.max(12, Math.min(win.width - width - 12, root.anchorX - width / 2))
                y: dock.cardY
                width: Math.min(640, win.width - 24)
                height: card.implicitHeight
                opacity: dock.reveal
                transform: dock.slide

                // Clicks on the card's bare parts stay on the card.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                PetHubCard {
                    id: card
                    anchors.fill: parent
                    framed: dock.framed
                    onCloseRequested: Services.Pet.hubOpen = false
                }
            }

            Component.onCompleted: Qt.callLater(card.focusSearch)
        }
    }
}
