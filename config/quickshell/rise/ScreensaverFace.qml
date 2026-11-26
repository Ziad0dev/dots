import QtQuick
import "NixosArt.js" as Art

// What the screensaver shows on one screen (Screensaver.qml puts one on each),
// after Omarchy's: the logo (NixOS here) played through terminal-text-effect
// style animations on black, one effect after another, with a small clock
// under it. Drawn per character on a monospace grid, coloured with a gradient
// through the theme's palette. Sized to fit each screen, so every monitor gets
// the same picture. Emits `wake` on any input after a short grace (the click
// or key that started it isn't someone waking it).
Item {
    id: face
    required property var theme
    property double since: Date.now()
    signal wake

    readonly property real h: Math.max(height, 1)
    readonly property real w: Math.max(width, 1)

    // ── the grid ────────────────────────────────────────────────────────
    readonly property var cells: Art.cells()
    readonly property int rows: Art.lines.length
    readonly property int cols: Art.cols()
    FontMetrics { id: fm; font.family: face.theme.mono; font.pixelSize: 100 }
    // block glyphs fill ascent + descent, so rows of them join up
    readonly property real cw100: Math.max(1, fm.advanceWidth("█"))
    readonly property real ch100: Math.max(1, fm.ascent + fm.descent)
    readonly property real px: Math.min(w * 0.6 / (cols * cw100 / 100), h * 0.55 / (rows * ch100 / 100))
    readonly property real cw: cw100 * px / 100
    readonly property real ch: ch100 * px / 100
    readonly property real artW: cols * cw
    readonly property real artH: rows * ch

    // the whole picture wanders a little every two minutes (OLED burn-in)
    property real ox: 0
    property real oy: 0
    Behavior on ox { NumberAnimation { duration: 9000; easing.type: Easing.InOutSine } }
    Behavior on oy { NumberAnimation { duration: 9000; easing.type: Easing.InOutSine } }
    Timer {
        interval: 120000
        running: true
        repeat: true
        onTriggered: {
            face.ox = (Math.random() - 0.5) * face.w * 0.1
            face.oy = (Math.random() - 0.5) * face.h * 0.1
        }
    }
    readonly property real artX: (w - artW) / 2 + ox
    readonly property real artY: (h - artH) / 2 - h * 0.04 + oy

    // ── effects ─────────────────────────────────────────────────────────
    readonly property var effects: ["decrypt", "rain", "beams", "print", "expand", "slide"]
    property int effectIndex: Math.floor(Math.random() * effects.length)
    readonly property string effect: effects[effectIndex]
    property real t: 0          // intro progress, 0..1
    property real artOpacity: 1
    property bool autoplay: true  // false: hold `effectIndex` at `t` (tests)

    SequentialAnimation {
        running: face.autoplay
        loops: Animation.Infinite
        ScriptAction { script: { face.t = 0; face.artOpacity = 1 } }
        NumberAnimation { target: face; property: "t"; from: 0; to: 1; duration: 3500 }
        PauseAnimation { duration: 9000 }
        NumberAnimation { target: face; property: "artOpacity"; to: 0; duration: 900; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                // never the same effect twice in a row
                face.effectIndex = (face.effectIndex + 1 + Math.floor(Math.random() * (face.effects.length - 1))) % face.effects.length
            }
        }
    }

    function clamp01(x) { return x < 0 ? 0 : (x > 1 ? 1 : x) }
    function easeOut(x) { return 1 - Math.pow(1 - x, 3) }

    // how far one cell is through the current effect, 0 (not yet) .. 1 (settled)
    function progress(r, c, k) {
        const rr = r / rows, cc = c / cols
        switch (effect) {
        case "decrypt": return clamp01((t - k * 0.6) / 0.4)
        case "rain":    return clamp01((t - k * 0.55 - (1 - rr) * 0.15) / 0.3)
        case "beams":   return clamp01((t - cc * 0.75 - Math.abs(rr - 0.5) * 0.1) / 0.15)
        case "print":   return clamp01((t * 1.05 - (r * cols + c) / (rows * cols)) / 0.02)
        case "expand":  return clamp01((t - k * 0.25) / 0.75)
        case "slide":   return clamp01((t - rr * 0.55 - k * 0.05) / 0.4)
        }
        return 1
    }

    // final colour: a diagonal gradient through three palette colours
    function gradient(r, c) {
        const x = clamp01(c / cols * 0.75 + r / rows * 0.25)
        const a = x < 0.5 ? theme.seal : theme.color04
        const b = x < 0.5 ? theme.color04 : theme.color05
        const f = x < 0.5 ? x * 2 : (x - 0.5) * 2
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1)
    }

    readonly property string noise: "01#$%&*+=<>/\\|?!{}[]~^:;"

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }

        Item {
            anchors.fill: parent
            opacity: face.artOpacity

            Repeater {
                model: face.cells
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property real p: face.progress(modelData.r, modelData.c, modelData.k)
                    readonly property real e: face.easeOut(p)
                    // the settled cell's edges and middle on whole pixels, shared
                    // with the neighbours: blocks meet with no seams
                    readonly property int x0: Math.round(face.artX + modelData.c * face.cw)
                    readonly property int x1: Math.round(face.artX + (modelData.c + 0.5) * face.cw)
                    readonly property int x2: Math.round(face.artX + (modelData.c + 1) * face.cw)
                    readonly property int y0: Math.round(face.artY + modelData.r * face.ch)
                    readonly property int y1: Math.round(face.artY + (modelData.r + 0.5) * face.ch)
                    readonly property int y2: Math.round(face.artY + (modelData.r + 1) * face.ch)
                    readonly property color done: face.gradient(modelData.r, modelData.c)
                    readonly property bool scrambling: face.effect === "decrypt" && p < 1
                    // settling cells glow bright, then cool into the gradient
                    readonly property color tint: p >= 1 ? done : face.theme.ink

                    x: face.effect === "expand" ? (face.w / 2 + (x0 - face.w / 2) * e)
                        : face.effect === "slide" ? x0 + (modelData.r % 2 ? 1 : -1) * (1 - e) * face.w * 0.6
                        : x0
                    y: face.effect === "expand" ? (face.h / 2 + (y0 - face.h / 2) * e)
                        : face.effect === "rain" ? y0 - (1 - e) * (y0 + face.ch * 2)
                        : y0
                    width: x2 - x0
                    height: y2 - y0
                    visible: p > 0 || face.effect === "decrypt"

                    Rectangle { visible: !cell.scrambling && (cell.modelData.q & 1); color: cell.tint
                        x: 0; y: 0; width: cell.x1 - cell.x0; height: cell.y1 - cell.y0 }
                    Rectangle { visible: !cell.scrambling && (cell.modelData.q & 2); color: cell.tint
                        x: cell.x1 - cell.x0; y: 0; width: cell.x2 - cell.x1; height: cell.y1 - cell.y0 }
                    Rectangle { visible: !cell.scrambling && (cell.modelData.q & 4); color: cell.tint
                        x: 0; y: cell.y1 - cell.y0; width: cell.x1 - cell.x0; height: cell.y2 - cell.y1 }
                    Rectangle { visible: !cell.scrambling && (cell.modelData.q & 8); color: cell.tint
                        x: cell.x1 - cell.x0; y: cell.y1 - cell.y0; width: cell.x2 - cell.x1; height: cell.y2 - cell.y1 }

                    // decrypt: noise glyphs until the cell settles
                    Text {
                        visible: cell.scrambling
                        anchors.centerIn: parent
                        text: face.noise[Math.floor((cell.modelData.k * 9973 + face.t * 47) % face.noise.length)]
                        color: Qt.rgba(cell.done.r, cell.done.g, cell.done.b, 0.35 + 0.4 * cell.p)
                        font.family: face.theme.mono
                        font.pixelSize: face.px
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        // a quiet clock under the logo
        Text {
            id: clock
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: face.ox
            y: face.artY + face.artH + face.h * 0.06
            text: (Qt.formatTime(now, face.theme.clock12h ? "h:mm AP" : "HH:mm") + "   ·   "
                   + Qt.formatDate(now, "dddd d MMMM")).toUpperCase()
            color: face.theme.ink
            opacity: 0.55
            font.family: face.theme.mono
            font.pixelSize: Math.min(face.h, face.w * 0.7) * 0.02
            font.letterSpacing: Math.min(face.h, face.w * 0.7) * 0.005
            textFormat: Text.PlainText
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        focus: true
        cursorShape: Qt.BlankCursor
        acceptedButtons: Qt.AllButtons
        property point first: Qt.point(-1, -1)
        function woke() { return Date.now() - face.since > 1200 }
        onPositionChanged: function (mouse) {
            if (first.x < 0) { first = Qt.point(mouse.x, mouse.y); return }
            if (woke() && Math.abs(mouse.x - first.x) + Math.abs(mouse.y - first.y) > 6)
                face.wake()
        }
        onPressed: if (woke()) face.wake()
        onWheel: if (woke()) face.wake()
        Keys.onPressed: function (event) {
            // taken here: the key that wakes the screen doesn't reach the app
            event.accepted = true
            if (woke()) face.wake()
        }
    }
}
