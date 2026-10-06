import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Combined AI-usage pill (OpenAI Codex + OpenCode). The bar shows ONE tool
// (root.aiTool) as a themed-tinted SVG with a bottom-up usage fill; the tooltip
// shows all tracked tools; clicking opens the AiUsagePanel where the tool can be switched.
// root.modAi is the on/off toggle for the whole pill.
Item {
    id: rootMod
    required property var root
    property string gid: "G7"

    // ── which tool the bar pill displays ──
    readonly property bool isOpenCode: root.aiTool === "opencode"
    readonly property bool isCodex: !isOpenCode
    readonly property url  logoSource: Qt.resolvedUrl(isOpenCode ? "../assets/opencode-mark.svg" : "../assets/codex.svg")
    readonly property var  logoSourceSize: isOpenCode ? Qt.size(20, 12) : Qt.size(56, 56)
    readonly property int  codexMarkSize: 14
    readonly property int  ocMarkW: 20
    readonly property int  ocMarkH: 12

    // ── Codex ──
    property bool cxActive: false
    readonly property bool   cxFresh:     root.aiCxFresh
    readonly property int    cxPct5h:     root.aiCxPct5h
    readonly property int    cxPct7d:     root.aiCxPct7d    // weekly
    readonly property string cxPlan:      root.aiCxPlan
    readonly property string cxTokens:    root.aiCxTokens
    readonly property string cxRate:      root.aiCxRate
    readonly property int    cxReset5hTs: root.aiCxReset5hTs
    readonly property int    cxReset7dTs: root.aiCxReset7dTs
    readonly property bool   cxHas:       root.aiCxHas
    readonly property var    cxBuckets:   root.aiCxBuckets || []
    readonly property var    cxWindows:   root.aiCxWindows || []
    readonly property string cxLimitStatus: root.aiCxLimitStatus
    readonly property string cxLimitReachedType: root.aiCxLimitReachedType
    readonly property int    cxPrimaryPct: root.aiCxPrimaryPct
    readonly property string cxPrimaryLabel: root.aiCxPrimaryLabel
    readonly property bool   cxHasGeneral5h: {
        for (var i = 0; i < cxWindows.length; i++) {
            if ((cxWindows[i] || {}).minutes === 300) return true
        }
        return false
    }

    // ── OpenCode ──
    property bool ocActive: false
    readonly property bool   ocFresh:     root.aiOcFresh
    readonly property int    ocPct5h:     root.aiOcPct5h
    readonly property int    ocPct7d:     root.aiOcPct7d
    readonly property string ocPlan:      root.aiOcPlan
    readonly property string ocTokens:    root.aiOcTokens
    readonly property string ocRate:      root.aiOcRate
    readonly property string ocModel:     root.aiOcModel
    readonly property int    ocToday:     root.aiOcToday
    readonly property bool   ocHas:       root.aiOcHas

    // ── per-tool signal (active OR fresh non-zero usage) ──
    readonly property bool cxSignal: cxActive || (cxPrimaryPct > 0 && cxFresh)
    readonly property bool ocSignal: ocActive || ((ocPct5h > 0 || ocToday > 0) && ocFresh)

    // ── selected-tool display values ──
    readonly property int  pct5h:   isOpenCode ? ocPct5h : cxPrimaryPct
    readonly property int  pct5hStep: Math.round(pct5h / 5) * 5
    readonly property bool selFresh: isOpenCode ? ocFresh : cxFresh
    readonly property bool selSignal: isOpenCode ? ocSignal : cxSignal

    // show whenever the gate is on AND either tool has a signal — the pill stays
    // reachable (to open the panel + switch) even if the selected tool is idle
    readonly property bool shown: (cxSignal || ocSignal) && root.modAi

    readonly property string tooltipText: {
        var lines = []
        if (cxHas || cxActive) {
            if (lines.length) lines.push("")
            lines.push("OpenAI Codex" + (cxPlan ? "  (" + cxPlan + ")" : ""))
            for (var i = 0; i < cxWindows.length; i++) {
                var xw = cxWindows[i] || {}
                var xr = root.aiFmtReset(xw.resetTs || 0)
                lines.push(String(xw.label || "window") + ": " + (xw.pct || 0) + "%" + (xr ? "  (reset in " + xr + ")" : ""))
            }
            if (!cxHasGeneral5h) lines.push("5h: not reported by Codex RPC")
            lines.push("General limit: " + root.aiCodexStatusLabel(cxLimitStatus, cxLimitReachedType))
            if (cxRate) lines.push("Local activity (1h, incl. cached): " + cxRate)
        }
        if (ocHas || ocActive) {
            if (lines.length) lines.push("")
            lines.push("OpenCode" + (ocPlan ? "  (" + ocPlan + ")" : ""))
            lines.push("5h: " + ocPct5h + "%  ·  7d: " + ocPct7d + "%")
            if (ocTokens) lines.push(ocTokens + " tokens" + (ocRate ? "  · " + ocRate : ""))
            if (ocToday > 0) lines.push("today: " + (ocToday / 1e6).toFixed(2) + "M tok")
            if (ocModel) lines.push(ocModel)
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
        command: ["bash", "-c", "x=0; o=0; while read -r pid comm args; do case $comm in codex) case $args in *app-server*) ;; *) x=1 ;; esac ;; esac; case $args in *opencode-usage*|*grep*) ;; *opencode-ai*|*/opencode\ *|opencode\ *|*/opencode|opencode) o=1 ;; esac; done < <(ps -eo pid=,comm=,args=); printf '%s%s' \"$x\" \"$o\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim()
                rootMod.cxActive = t.charAt(0) === "1"
                rootMod.ocActive = t.charAt(1) === "1"
            }
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

        // icon with bottom-to-top usage fill, themed via the shared logo tint shader.
        Item {
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: rootMod.isOpenCode ? rootMod.ocMarkW : rootMod.codexMarkSize
            implicitHeight: rootMod.isOpenCode ? rootMod.ocMarkH : rootMod.codexMarkSize
            width: implicitWidth
            height: implicitHeight

            Item {
                anchors.fill: parent

                Image {
                    id: codexBase
                    anchors.fill: parent
                    source: rootMod.logoSource
                    sourceSize: rootMod.logoSourceSize
                    fillMode: Image.PreserveAspectFit
                    smooth: !rootMod.isOpenCode
                    mipmap: !rootMod.isOpenCode
                    opacity: rootMod.isCodex ? 0.65 : 0.5
                    layer.enabled: true
                    layer.smooth: !rootMod.isCodex
                    layer.effect: ShaderEffect {
                        property color tintColor: root.ink
                        fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                    }
                }
                Item {
                    clip: true
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: rootMod.pct5hStep > 0
                        ? Math.min(parent.height, Math.max(parent.height * rootMod.pct5hStep / 100, parent.height * 0.22))
                        : 0
                    Behavior on height { Anim { kind: "size"; ms: 600 } }
                    Image {
                        width: iconItem.width; height: iconItem.height
                        anchors.bottom: parent.bottom
                        source: rootMod.logoSource
                        sourceSize: rootMod.logoSourceSize
                        fillMode: Image.PreserveAspectFit
                        smooth: !rootMod.isOpenCode
                        mipmap: !rootMod.isOpenCode
                        layer.enabled: true
                        layer.smooth: !rootMod.isCodex
                        layer.effect: ShaderEffect {
                            property color tintColor: root.seal
                            fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                        }
                    }
                }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.selSignal ? String(rootMod.pct5h).padStart(2, "0") + "%" : "··"
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.85)
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { CAnim { ms: 200 } }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: if (shown) { root.refreshAiUsage(); tip.show() }
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.aiUsageVisible = !root.aiUsageVisible }
    }
}
