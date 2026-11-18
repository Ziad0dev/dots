import QtQuick
import Quickshell
import Quickshell.Io

// Claude Code usage pill: the Claude glyph with a bottom-up 5h usage fill;
// clicking opens the AiUsagePanel. root.modAi is the on/off toggle for the pill.
Item {
    id: rootMod
    required property var root
    property string gid: "G7"

    // ── process detection is local (drives the pill's visibility); usage data is
    //    read straight from root.aiCl* — the one parse in ThemeAiUsage.qml that
    //    AiUsagePanel renders from too ──
    property bool clActive: false

    // ── signal: running OR fresh non-zero usage ──
    readonly property bool clSignal: clActive || (root.aiClPct5h > 0 && root.aiClFresh)

    readonly property int  pct5hStep: Math.round(root.aiClPct5h / 5) * 5

    // show whenever the gate is on AND Claude is running or has fresh usage
    readonly property bool shown: clSignal && root.modAi

    readonly property string tooltipText: {
        var lines = []
        if (root.aiClHas || clActive) {
            lines.push("Claude Code")
            var cr = root.aiFmtReset(root.aiClReset5hTs)
            lines.push("5h: " + root.aiClPct5h + "%" + (cr ? "  (reset in " + cr + ")" : ""))
            var c7 = root.aiFmtReset(root.aiClReset7dTs)
            if (root.aiClPct7d > 0) lines.push("7d: " + root.aiClPct7d + "%" + (c7 ? "  (reset in " + c7 + ")" : ""))
            if (root.aiClTokens)    lines.push(root.aiClTokens + " tokens" + (root.aiClRate ? "  · " + root.aiClRate : ""))
            if (root.aiClToday > 0) lines.push("today: " + (root.aiClToday / 1e6).toFixed(2) + "M tok")
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
        id: detectClaude
        // Nix wraps the binary, so the process is ".claude-wrapped"; the Chrome
        // native host runs the same binary and is skipped. pgrep alone, no shell.
        command: ["pgrep", "-ax", "\\.?claude(-wrapped)?"]
        stdout: StdioCollector {
            onStreamFinished: rootMod.clActive = String(this.text || "").split("\n")
                .some(l => l.trim() !== "" && l.indexOf("--chrome-native-host") < 0)
        }
    }
    Timer {
        // each check scans /proc (~25 ms of CPU); a usage pill needn't know
        // within 5 s, and its numbers only refresh every 10 min anyway
        interval: 15000; running: root.modAi || root.aiUsageVisible; repeat: true; triggeredOnStart: true
        onTriggered: { detectClaude.running = false; detectClaude.running = true }
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
            text: root.aiClBlocked
                ? "BLK"
                : (rootMod.clSignal ? String(root.aiClPct5h).padStart(2, "0") + "%" : "··")
            color: root.aiClBlocked
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
