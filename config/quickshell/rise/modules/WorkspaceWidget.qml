import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../panels/dash/Occult.js" as Occult

Item {
    id: wsWidget
    required property var root
    property string gid: "G2"

    implicitWidth: wsRow.implicitWidth
    implicitHeight: 28

    property real _lastPulse: 0
    readonly property int focusedId: Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.name) : 0
    onFocusedIdChanged: {
        var now = Date.now()
        if (now - wsWidget._lastPulse < 450) return
        wsWidget._lastPulse = now
        root.barPulse("workspace")
    }

    // The focused workspace's number ONLY when it's a real workspace beyond
    // the persist range — else 0. An int signals on value change only, so switching
    // between in-range workspaces does NOT renotify → workspaceList stays identical
    // → the Repeater model is stable → the per-delegate width/colour Behaviors keep
    // animating instead of the whole model rebuilding (B2). Number(name) is NaN for
    // special/scratchpad workspaces, so they fail `> n` and stay excluded (B3).
    readonly property int extraWs: {
        if (root.workspaceMode === "active") return 0
        var n = root.workspaceMode === "5" ? 5 : 10
        var f = Hyprland.focusedWorkspace
        var fid = f ? Number(f.name) : 0
        return (fid > n) ? fid : 0
    }

    readonly property var workspaceList: {
        if (root.workspaceMode === "active") {
            var ids = {}
            var ws = Hyprland.workspaces.values
            for (var i = 0; i < ws.length; i++) {
                var k = Number(ws[i].name)               // F13: NaN for special workspaces → skipped
                if (k > 0) ids[k] = true
            }
            if (Hyprland.focusedWorkspace) {
                var fk = Number(Hyprland.focusedWorkspace.name)
                if (fk > 0) ids[fk] = true
            }
            return Object.keys(ids).map(Number).sort(function(a, b) { return a - b })
        }
        var n = root.workspaceMode === "5" ? 5 : 10
        var list = []; for (var j = 1; j <= n; j++) list.push(j)
        if (extraWs > 0) list.push(extraWs)   // focused-beyond-range, stable per id
        return list
    }

    Rectangle {
        x: -root.wsPillPad; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(wsRow.width) + 2 * root.wsPillPad
        height: root.pillH
        radius: root.pillRadius
        color: root.widgetFillColor(wsWidget.gid)
        border.color: root.widgetBorderColor(wsWidget.gid)
        border.width: root.widgetBorderWidth(wsWidget.gid)
        PillShadow { theme: root }
    }

    // right-click anywhere opens the workspace panel
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.popout.click("workspaceVisible")
    }

    // kanji numerals: 1-10 一…十, 11-99 十一, 二十, 二十一 …; anything else stays arabic
    readonly property var _kanjiDigits: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    function kanji(n) {
        if (n <= 0 || n >= 100) return String(n)
        var t = Math.floor(n / 10), o = n % 10
        return (t > 1 ? _kanjiDigits[t] : "") + (t > 0 ? "十" : "") + _kanjiDigits[o]
    }

    function appIdOf(tl) {
        var id = tl.wayland ? tl.wayland.appId : ""
        if (!id && tl.lastIpcObject) id = tl.lastIpcObject.class || ""
        return id || ""
    }
    // desktop entry icon, else an icon named after the app id; the shell's own
    // dev.dots.* windows are Ghostty (hypr/modules/80-autostart.lua)
    function iconFor(appId) {
        if (appId === "") return ""
        if (appId.indexOf("dev.dots.") === 0) appId = "com.mitchellh.ghostty"
        var e = DesktopEntries.heuristicLookup(appId)
        return Quickshell.iconPath(e && e.icon ? e.icon : appId.toLowerCase(), true)
    }

    // occult numerals: the Elder Futhark in order, the planets (weekday order,
    // then the outer three), Roman numerals; past their end, arabic
    readonly property var _runes: ["ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ", "ᚺ", "ᚾ", "ᛁ", "ᛃ",
                                   "ᛇ", "ᛈ", "ᛉ", "ᛊ", "ᛏ", "ᛒ", "ᛖ", "ᛗ", "ᛚ", "ᛜ", "ᛞ", "ᛟ"]
    readonly property var _planets: ["☉", "☽", "♂", "☿", "♃", "♀", "♄", "♅", "♆", "♇"]
    function rune(n) { return n >= 1 && n <= _runes.length ? _runes[n - 1] : String(n) }
    function planet(n) { return n >= 1 && n <= _planets.length ? _planets[n - 1] : String(n) }
    readonly property bool occultGlyphs: root.workspaceStyle === "runes" || root.workspaceStyle === "planets"
        || root.workspaceStyle === "roman"

    property real cometX: 0
    property real cometW: 0
    property bool cometFwd: true
    function aimComet(nx, nw) {
        if (nx !== wsWidget.cometX) wsWidget.cometFwd = nx > wsWidget.cometX
        wsWidget.cometX = nx
        wsWidget.cometW = nw
    }

    Item {
        id: cometLayer
        visible: root.workspaceStyle === "comet"
        anchors.fill: wsRow

        property real lead: wsWidget.cometX + wsWidget.cometW
        property real tail: wsWidget.cometX
        property real ghostLead: wsWidget.cometX + wsWidget.cometW
        property real ghostTail: wsWidget.cometX

        Behavior on lead      { NumberAnimation { duration: wsWidget.cometFwd ? 190 : 430; easing.type: Easing.OutCubic } }
        Behavior on tail      { NumberAnimation { duration: wsWidget.cometFwd ? 430 : 190; easing.type: Easing.OutCubic } }
        Behavior on ghostLead { NumberAnimation { duration: wsWidget.cometFwd ? 320 : 620; easing.type: Easing.OutCubic } }
        Behavior on ghostTail { NumberAnimation { duration: wsWidget.cometFwd ? 620 : 320; easing.type: Easing.OutCubic } }

        Rectangle {
            x: cometLayer.ghostTail
            width: Math.max(2, cometLayer.ghostLead - cometLayer.ghostTail)
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            radius: root.styleRadiusSmall ? 5 : height / 2
            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.10)
        }

        Rectangle {
            x: cometLayer.tail
            width: Math.max(2, cometLayer.lead - cometLayer.tail)
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            radius: root.styleRadiusSmall ? 5 : height / 2
            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.26)
            border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.55)
            border.width: 1
        }
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: wsWidget.workspaceList

            delegate: Item {
                id: wsCell
                required property int modelData
                readonly property int wsId: modelData

                // hover feedback works in every style (the old code scaled the
                // default-only `dot`, invisible in numbers/magic)
                Behavior on scale { Anim { kind: "spatialFast" } }

                readonly property bool isFocused: Hyprland.focusedWorkspace !== null
                                               && Number(Hyprland.focusedWorkspace.name) === wsId

                readonly property var wsObj: {
                    var ws = Hyprland.workspaces.values
                    for (var i = 0; i < ws.length; i++)
                        if (Number(ws[i].name) === wsId) return ws[i]
                    return null
                }
                readonly property bool isOccupied: wsObj !== null && !isFocused

                // window data only for the styles that draw it
                readonly property bool wantsWindows: root.workspaceStyle === "occupancy" || root.workspaceStyle === "icons"
                readonly property var wins: wantsWindows && wsObj && wsObj.toplevels ? wsObj.toplevels.values : []
                readonly property int dotCount: Math.max(1, Math.min(wins.length, 4))   // occupancy caps at 4

                // icons: the focused window if it's here, then real apps before the
                // shell's own dev.dots.* helper terminals; the first of those with an
                // icon, else the first one (shown as a letter)
                readonly property var main: {
                    if (root.workspaceStyle !== "icons" || wins.length === 0) return { app: "", icon: "" }
                    var rank = function (t) {
                        return (t.activated ? 2 : 0) + (wsWidget.appIdOf(t).indexOf("dev.dots.") === 0 ? 0 : 1)
                    }
                    var order = wins.slice()
                    order.sort(function (a, b) { return rank(b) - rank(a) })
                    var first = null
                    for (var i = 0; i < order.length; i++) {
                        var id = wsWidget.appIdOf(order[i])
                        var icon = wsWidget.iconFor(id)
                        if (icon !== "") return { app: id, icon: icon }
                        if (first === null) first = id
                    }
                    return { app: first || "", icon: "" }
                }
                readonly property string mainApp: main.app
                readonly property string mainIcon: main.icon

                readonly property bool isEmpty: !isFocused && !isOccupied

                onXChanged:         if (wsCell.isFocused) wsWidget.aimComet(wsCell.x, wsCell.width)
                onWidthChanged:     if (wsCell.isFocused) wsWidget.aimComet(wsCell.x, wsCell.width)
                onIsFocusedChanged: if (wsCell.isFocused) wsWidget.aimComet(wsCell.x, wsCell.width)
                Component.onCompleted: if (wsCell.isFocused) wsWidget.aimComet(wsCell.x, wsCell.width)

                implicitWidth: root.workspaceStyle === "numbers"   ? 22
                             : root.workspaceStyle === "comet"     ? 24
                             : root.workspaceStyle === "magic"     ? (isFocused ? 20 : 18)
                             : root.workspaceStyle === "segments"  ? (isFocused ? 22 : 12)
                             : root.workspaceStyle === "occupancy" ? dotCount * 4 + (dotCount - 1) * 3 + 8
                             : root.workspaceStyle === "icons"     ? 22
                             : root.workspaceStyle === "kanji"     ? Math.max(22, kanjiText.implicitWidth + 8)
                             : root.workspaceStyle === "runes"     ? 20
                             : root.workspaceStyle === "planets"   ? 22
                             : root.workspaceStyle === "roman"     ? Math.max(18, occultText.implicitWidth + 9)
                             : root.workspaceStyle === "lunar"     ? 18
                             : (isFocused ? 32 : 16)
                implicitHeight: 28

                Behavior on implicitWidth {
                    Anim { kind: "size"; ms: 250 }
                }

                // ── DEFAULT style: glow + dot ──
                // glow — alle states, nur opacity variiert
                Rectangle {
                    visible: root.workspaceStyle === "default"
                    anchors.centerIn: parent
                    width:  isFocused ? 34 : 16
                    height: isFocused ? 16 : 16
                    radius: isFocused ?  8 :  8
                    color: isFocused
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                        : isOccupied
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                        : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.06)

                    Behavior on width { Anim { kind: "size"; ms: 250 } }
                    Behavior on color { CAnim { ms: 200 } }
                }

                // pill / kreis
                Rectangle {
                    id: dot
                    visible: root.workspaceStyle === "default"
                    anchors.centerIn: parent
                    width:  isFocused  ? 26 : 8
                    height: 8
                    radius: 4
                    color:  isFocused
                        ? root.seal
                        : isOccupied
                        ? root.seal
                        : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)

                    Behavior on width { Anim { kind: "size"; ms: 250 } }
                    Behavior on color { CAnim { ms: 200 } }
                }

                // ── NUMBERS style: a digit on a rounded badge (radius follows
                //    the bar radius switch: round/12 ⇄ 5) ──
                Rectangle {
                    visible: root.workspaceStyle === "numbers"
                    anchors.centerIn: parent
                    width:  20
                    height: 20
                    radius: root.styleRadiusSmall ? 5 : height / 2
                    color: isFocused  ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.30)
                         : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                                      : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.04)
                    Behavior on color { CAnim { ms: 200 } }
                    Text {
                        anchors.centerIn: parent
                        text: wsId
                        // focused = the only BRIGHT digit (lightened seal + bold + bigger);
                        // others dimmed so the active workspace is unmistakable
                        color: isFocused  ? Qt.lighter(root.seal, 1.3)
                             : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.5)
                                          : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.28)
                        font.family: root.mono
                        font.pixelSize: isFocused ? 13 : 12
                        font.weight: isFocused ? Font.Bold : Font.Normal
                    }
                }

                Text {
                    visible: root.workspaceStyle === "comet"
                    anchors.centerIn: parent
                    text: wsCell.wsId
                    color: wsCell.isFocused  ? Qt.lighter(root.seal, 1.35)
                         : wsCell.isOccupied ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
                                             : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                    font.family: root.mono
                    font.pixelSize: 12
                    font.weight: wsCell.isFocused ? Font.Bold : Font.Normal
                    Behavior on color { CAnim { ms: 200 } }
                }

                // ── MAGIC style: the 3 ORIGINAL sparkle glyphs (filled / hollow / dot),
                //    all forced into ONE font (Adwaita Mono has all three) so they share
                //    a metric → no cross-font fallback misalignment ──
                Text {
                    visible: root.workspaceStyle === "magic"
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: isFocused ? 0 : 1   // active lifted vs occupied/empty
                    text: isFocused  ? String.fromCodePoint(0x2726)    // ✦ filled four-point star (active)
                         : isOccupied ? String.fromCodePoint(0x2727)    // ✧ hollow four-point star (occupied)
                                      : String.fromCodePoint(0x00B7)    // · middle dot (empty)
                    color: isFocused  ? root.seal
                         : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.7)
                                      : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3)
                    font.family: "Adwaita Mono"   // all 3 sparkle glyphs live here → one consistent metric
                    font.pixelSize: isFocused ? 22 : 18
                    renderType: Text.NativeRendering   // crisp hinted raster (default QtRendering softens small symbols)
                    Behavior on color { CAnim { ms: 200 } }
                }

                // ── SEGMENTS style: a thin tick per workspace, the focused one
                //    longer and lit in the window-border colour ──
                Rectangle {
                    visible: root.workspaceStyle === "segments"
                    anchors.centerIn: parent
                    width: parent.width
                    height: isFocused ? 4 : 3
                    radius: height / 2
                    color: isFocused  ? root.windowBorder
                         : isOccupied ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                                      : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12)
                    Behavior on color { CAnim { ms: 200 } }
                }

                // ── OCCUPANCY style: one dot per window (up to 4); a hollow
                //    ring when the workspace has none ──
                Row {
                    visible: root.workspaceStyle === "occupancy"
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: root.workspaceStyle === "occupancy" ? wsCell.dotCount : 0
                        delegate: Rectangle {
                            width: 4; height: 4; radius: 2
                            readonly property color tone: wsCell.isFocused ? root.windowBorder : root.ink
                            color: wsCell.wins.length === 0 ? "transparent"
                                 : wsCell.isFocused ? tone : Qt.rgba(tone.r, tone.g, tone.b, 0.55)
                            border.width: wsCell.wins.length === 0 ? 1 : 0
                            border.color: wsCell.isFocused ? tone : Qt.rgba(tone.r, tone.g, tone.b, 0.25)
                            Behavior on color { CAnim { ms: 200 } }
                        }
                    }
                }

                // ── ICONS style: the main window's app icon (a letter when the
                //    app has none, a dot when the workspace is empty), with a
                //    window-border underline under the focused one ──
                Image {
                    visible: root.workspaceStyle === "icons" && wsCell.mainIcon !== ""
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    width: 14; height: 14
                    sourceSize: Qt.size(28, 28)
                    source: visible ? wsCell.mainIcon : ""
                    asynchronous: true
                    smooth: true; mipmap: true
                    opacity: isFocused ? 1.0 : 0.5
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                Text {
                    visible: root.workspaceStyle === "icons" && wsCell.mainIcon === ""
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: wsCell.mainApp !== "" ? wsCell.mainApp.split(".").pop().charAt(0).toUpperCase()
                        : wsCell.wins.length > 0 ? "?" : String.fromCodePoint(0x00B7)
                    color: isFocused ? root.ink
                         : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, wsCell.wins.length > 0 ? 0.55 : 0.3)
                    font.family: root.mono
                    font.pixelSize: 12
                    font.weight: isFocused ? Font.Bold : Font.Normal
                }
                Rectangle {
                    visible: root.workspaceStyle === "icons"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 8
                    width: isFocused ? 12 : 0
                    height: 2; radius: 1
                    color: root.windowBorder
                    Behavior on width { Anim { kind: "size"; ms: 250 } }
                }

                // ── KANJI style: 一 二 三 … numerals; focused in the window-border colour ──
                Text {
                    id: kanjiText
                    visible: root.workspaceStyle === "kanji"
                    anchors.centerIn: parent
                    text: wsWidget.kanji(wsCell.wsId)
                    color: isFocused  ? Qt.lighter(root.windowBorder, 1.3)
                         : isOccupied ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
                                      : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                    font.family: "Noto Sans CJK JP"
                    font.pixelSize: isFocused ? 14 : 13
                    font.weight: isFocused ? Font.Bold : Font.Normal
                    Behavior on color { CAnim { ms: 200 } }
                }

                // ── RUNES / PLANETS / ROMAN: occult numerals, the focused one in
                //    the window-border red over a small lozenge ──
                Text {
                    id: occultText
                    visible: wsWidget.occultGlyphs
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: root.workspaceStyle === "roman" ? -1 : -2
                    text: root.workspaceStyle === "runes" ? wsWidget.rune(wsCell.wsId)
                        : root.workspaceStyle === "planets" ? wsWidget.planet(wsCell.wsId)
                        : Occult.roman(wsCell.wsId)
                    color: isFocused  ? Qt.lighter(root.windowBorder, 1.3)
                         : isOccupied ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.78)
                                      : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28)
                    font.family: root.workspaceStyle === "runes" ? "Noto Sans Runic"
                               : root.workspaceStyle === "planets" ? "Libertinus Serif Display"
                               : root.gothic
                    font.pixelSize: root.workspaceStyle === "roman" ? (isFocused ? 17 : 15)
                                  : (isFocused ? 17 : 15)
                    renderType: Text.NativeRendering
                    Behavior on color { CAnim { ms: 200 } }
                }
                Rectangle {
                    visible: wsWidget.occultGlyphs
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 9
                    width: isFocused ? 4 : 0; height: width
                    rotation: 45
                    color: root.windowBorder
                    Behavior on width { Anim { kind: "spatialFast" } }
                }

                // ── LUNAR: a new moon when empty, a half moon when occupied,
                //    a full blood moon when focused ──
                Item {
                    visible: root.workspaceStyle === "lunar"
                    anchors.centerIn: parent
                    width: isFocused ? 12 : 10; height: width
                    Behavior on width { Anim { kind: "spatialFast" } }
                    // halo round the blood moon
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8; height: width; radius: width / 2
                        visible: isFocused
                        color: Qt.rgba(root.windowBorder.r, root.windowBorder.g, root.windowBorder.b, 0.18)
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: isFocused ? root.windowBorder : "transparent"
                        border.width: 1
                        border.color: isFocused ? root.windowBorder
                                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, isOccupied ? 0.7 : 0.3)
                        Behavior on color { CAnim { ms: 200 } }
                    }
                    // the lit half of an occupied workspace's moon
                    Item {
                        visible: isOccupied
                        x: parent.width / 2; width: parent.width / 2; height: parent.height
                        clip: true
                        Rectangle {
                            x: -parent.width; width: parent.width * 2; height: parent.height
                            radius: height / 2
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.gotoWorkspace(wsId)
                    onEntered: wsCell.scale = 1.15
                    onExited:  wsCell.scale = 1.0
                }
            }
        }
    }

}
