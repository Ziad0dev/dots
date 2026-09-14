import QtQuick

Item {
    id: motion

    property bool active: true
    property real hoverScale: 1.055
    property real pressScale: 0.945
    property int  introDelay: 0
    property bool introEnabled: true

    readonly property bool hovered: motion.active && hh.hovered
    readonly property bool held: motion.active && ph.active

    property real amount: motion.held ? motion.pressScale : motion.hovered ? motion.hoverScale : 1.0
    property real intro: motion.introEnabled ? 0.0 : 1.0

    readonly property real scaleFactor: motion.amount * (0.86 + 0.14 * motion.intro)
    readonly property real introOpacity: motion.intro

    Behavior on amount {
        SpringAnimation { spring: 5.0; damping: 0.34; mass: 0.55; epsilon: 0.0005 }
    }

    HoverHandler { id: hh; enabled: motion.active }
    PointHandler { id: ph; enabled: motion.active; acceptedButtons: Qt.LeftButton }

    SequentialAnimation {
        running: motion.introEnabled
        PauseAnimation { duration: motion.introDelay }
        NumberAnimation {
            target: motion; property: "intro"
            from: 0.0; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.1
        }
    }
}
