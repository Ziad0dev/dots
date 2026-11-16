import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Claude Code usage pill: the Claude glyph with a bottom-up 5h usage fill;
// clicking opens the AiUsagePanel. root.modAi is the on/off toggle for the pill.
Item {
    id: rootMod
    required property var root
    property string gid: "G7"

    // ── Claude: process detection is local (drives the pill's visibility); all
    //    usage data comes from root.ai* — the single shared parse in Theme.qml that
    //    AiUsagePanel renders from too, so the two views can't drift apart. ──
    property bool clActive: false
    readonly property bool   clFresh:     root.aiClFresh
    readonly property int    clPct5h:     root.aiClPct5h
    readonly property int    clPct7d:     root.aiClPct7d
    readonly property bool   clBlocked:   root.aiClBlocked
    readonly property string clTokens:    root.aiClTokens
    readonly property string clRate:      root.aiClRate
    readonly property int    clReset5hTs: root.aiClReset5hTs
    readonly property int    clReset7dTs: root.aiClReset7dTs
    readonly property int    clToday:     root.aiClToday
    readonly property bool   clHas:       root.aiClHas

    // ── signal: running OR fresh non-zero usage ──
    readonly property bool clSignal: clActive || (clPct5h > 0 && clFresh)

    // ── display values ──
    readonly property int  pct5h:   clPct5h
    readonly property int  pct5hStep: Math.round(pct5h / 5) * 5
    readonly property bool selSignal: clSignal
    readonly property bool blocked:  clBlocked

    // show whenever the gate is on AND Claude is running or has fresh usage
    readonly property bool shown: clSignal && root.modAi

    readonly property string tooltipText: {
        var lines = []
        if (clHas || clActive) {
            lines.push("Claude Code")
            var cr = root.aiFmtReset(clReset5hTs)
            lines.push("5h: " + clPct5h + "%" + (cr ? "  (reset in " + cr + ")" : ""))
            var c7 = root.aiFmtReset(clReset7dTs)
            if (clPct7d > 0) lines.push("7d: " + clPct7d + "%" + (c7 ? "  (reset in " + c7 + ")" : ""))
            if (clTokens)    lines.push(clTokens + " tokens" + (clRate ? "  · " + clRate : ""))
            if (clToday > 0) lines.push("today: " + (clToday / 1e6).toFixed(2) + "M tok")
        }
        return lines.length ? lines.join("\n") : "AI usage"
    }

    // keep rendered until the collapse animation finishes
    visible: implicitWidth > 0.5
    implicitWidth: shown ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: shown ? 1 : 0

    Behavior on opacity { Anim { kind: "effects"; ms: 140 } }

    // ── process detection ──
    Process {
        id: detectAll
        // Nix wraps the binary, so the process is ".claude-wrapped"; skip the Chrome native host
        command: ["bash", "-c", "pgrep -ax '\\.?claude(-wrapped)?' | grep -qv -- --chrome-native-host && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: rootMod.clActive = String(this.text || "").trim() === "1"
        }
    }
    Timer {
        interval: 5000; running: root.modAi || root.aiUsageVisible; repeat: true; triggeredOnStart: true
        onTriggered: { detectAll.running = false; detectAll.running = true }
    }

    // ── background pill ──
    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH; radius: root.pillRadius
        color: root.widgetFillColor(rootMod.gid)
        border.color: root.widgetBorderColor(rootMod.gid)
        border.width: root.widgetBorderWidth(rootMod.gid)
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // Claude nerd-font glyph with bottom-to-top usage fill
        Item {
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 15
            implicitHeight: 15
            width: implicitWidth
            height: implicitHeight

            Item {
                anchors.centerIn: parent
                implicitWidth: glyphBase.implicitWidth
                implicitHeight: glyphBase.implicitHeight

                UiText {
                    id: glyphBase
                    text: String.fromCodePoint(0xF167A)
                    renderType: Text.QtRendering
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                    font.family: root.mono
                    font.pixelSize: 14
                }
                Item {
                    clip: true
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: rootMod.pct5hStep > 0
                        ? Math.min(parent.height, Math.max(parent.height * rootMod.pct5hStep / 100, parent.height * 0.25))
                        : 0
                    Behavior on height { Anim { kind: "size"; ms: 600 } }
                    UiText {
                        anchors.bottom: parent.bottom
                        text: String.fromCodePoint(0xF167A)
                        renderType: Text.QtRendering
                        color: root.seal
                        font.family: root.mono
                        font.pixelSize: 14
                        Behavior on color { CAnim { ms: 200 } }
                    }
                }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.blocked
                ? "BLK"
                : (rootMod.selSignal ? String(rootMod.pct5h).padStart(2, "0") + "%" : "··")
            color: rootMod.blocked
                ? root.seal
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.85)
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { CAnim { ms: 200 } }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText; popout: "aiUsageVisible" }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: if (shown) { root.refreshAiUsage(); tip.show() }
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.popout.click("aiUsageVisible") }
    }
}
