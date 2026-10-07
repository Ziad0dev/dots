import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "modules"
import "Palette.js" as Palette

ThemeAiUsage {
    id: theme
    property var variantHost: null
    signal reactorTest(string kind, string arg)

    property string dotsStateRoot: Quickshell.env("HOME") + "/.local/state/dots/shell/current"
    property string dotsShellRoot: Quickshell.env("HOME") + "/dots/config/quickshell/rise"
    property bool dotsStateRootResolved: false
    readonly property string themeNamePath: dotsStateRoot + "/theme.name"
    readonly property string colorsPath: dotsStateRoot + "/theme/colors.sh"
    readonly property string currentBackgroundPath: dotsStateRoot + "/background"
    readonly property string currentBackgroundsPath: dotsStateRoot + "/theme/backgrounds"
    property string currentThemeName: ""
    readonly property string userBackgroundsPath: currentThemeName === ""
        ? ""
        : Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property var wallpaperSourcePaths: userBackgroundsPath === ""
        ? [currentBackgroundsPath]
        : [currentBackgroundsPath, userBackgroundsPath]

    function setCurrentThemeName(rawName) {
        var name = String(rawName || "").trim()
        if (name === "." || name === ".." || name.indexOf("/") >= 0 || name.indexOf("\\") >= 0)
            name = ""
        currentThemeName = name
    }

    function reloadCurrentThemeFiles() {
        if (!dotsStateRootResolved) return
        themeReloadDebounce.restart()
    }

    property color paper:   "#181616"
    property color ink:     "#c5c9c5"
    property color sumi:    "#a6a69c"
    property color color01: "#c4746e"
    property color color02: "#8a9a73"
    property color color03: "#c8b36a"
    property color color04: "#658594"
    property color color05: "#957fb8"
    property color color06: "#7aa89f"
    property color color07: "#c8c093"
    readonly property color inkDeep: color07
    readonly property color indigo:  color04
    readonly property color sealRaw: color01
    readonly property color sumiHi:  Qt.rgba(sumi.r*0.45 + ink.r*0.55, sumi.g*0.45 + ink.g*0.55, sumi.b*0.45 + ink.b*0.55, 1.0)  // lifted section-header text
    property color green:   "#8a9a73"   // gate "OK" verdict
    property color accentHint: sealRaw    // filled by palette; default = same as red
    readonly property color foregroundSoft: Qt.rgba(
        ink.r * 0.88 + paper.r * 0.12,
        ink.g * 0.88 + paper.g * 0.12,
        ink.b * 0.88 + paper.b * 0.12,
        1.0)
    property string barColor: "color01"
    readonly property bool barColorIsAccent: barColor === "accent"
    // Compatibility alias for older local code/reviews that still use the
    // previous boolean name.
    readonly property bool useThemeAccent: barColorIsAccent

    function paletteColor(id) {
        if (id === "color02") return color02
        if (id === "color03") return color03
        if (id === "color04") return color04
        if (id === "color05") return color05
        if (id === "color06") return color06
        if (id === "color07") return color07
        if (id === "foreground") return foregroundSoft
        if (id === "accent") return accentHint
        return color01
    }
    function normalizedPaletteId(id) {
        if (id === "red" || id === "accent") return "color01"
        return paletteColorValid(id) ? id : "color01"
    }
    readonly property color seal: paletteColor(barColor)
    readonly property var barColorOptions: [
        "color01", "color02", "color03", "color04",
        "color05", "color06", "color07", "foreground"
    ]
    function paletteColorValid(id) {
        return id === "color01" || id === "color02" || id === "color03"
            || id === "color04" || id === "color05" || id === "color06"
            || id === "color07" || id === "foreground"
    }
    function barColorValid(id) {
        return paletteColorValid(id) || id === "red" || id === "accent"
    }
    function barColorLabel(id) {
        if (id === "color01" || id === "red" || id === "accent") return "Color 01"
        if (id === "color02") return "Color 02"
        if (id === "color03") return "Color 03"
        if (id === "color04") return "Color 04"
        if (id === "color05") return "Color 05"
        if (id === "color06") return "Color 06"
        if (id === "color07") return "Color 07"
        if (id === "foreground") return "Foreground"
        return "Color 01"
    }
    function _linearColorChannel(v) {
        return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }
    function _relativeLuminance(c) {
        return 0.2126 * _linearColorChannel(c.r)
             + 0.7152 * _linearColorChannel(c.g)
             + 0.0722 * _linearColorChannel(c.b)
    }
    function _contrastRatio(a, b) {
        var la = _relativeLuminance(a)
        var lb = _relativeLuminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }
    function paletteContrastColor(id) {
        var fill = paletteColor(id)
        return _contrastRatio(fill, paper) >= _contrastRatio(fill, ink) ? paper : ink
    }

    readonly property string mono:  "JetBrainsMono Nerd Font"

    // ── transparency knobs (0.0 = fully transparent, 1.0 = opaque) ──
    property real barOpacity:  0.94   // große Insel / Split-Sektionen
    property real pillOpacity: 0.18   // einzelne Widget-Pillen (workspace, mem, cpu, …)

    readonly property color bg:     Qt.rgba(paper.r, paper.g, paper.b, barOpacity)
    // bar island/section bg ONLY (NOT the shared bg -> panels keep their opacity): Frost
    // lowers the island alpha; compositor blur appears automatically when the theme
    // already blurs Quickshell layer surfaces.
    readonly property color barBg:  Qt.rgba(paper.r, paper.g, paper.b,
                                            styleFrost ? Math.min(barOpacity, 0.68) : barOpacity)
    // widgets sit straight on the frame (its band is the bar background), so
    // in frame mode their pills have no fill of their own
    readonly property color pill:   frameOn ? "transparent" : Qt.rgba(paper.r, paper.g, paper.b, pillOpacity)
    // ── tonal depth (M3-style surface container) ──
    // panel cards sit one tone above the bar (paper stepped toward ink, so it
    // scales with every palette); inputs keep `bg` and read as recessed wells.
    property bool styleDepth: true
    function surfaceTone(t, a) {
        return Qt.rgba(paper.r + (ink.r - paper.r) * t, paper.g + (ink.g - paper.g) * t,
                       paper.b + (ink.b - paper.b) * t, a)
    }
    readonly property color cardBg: styleDepth ? surfaceTone(0.06, barOpacity) : bg

    // ── frame (Caelestia-style, FrameBlobs.qml) ──
    // The bar becomes the thick edge of one rounded frame around the screen, and
    // panels attached to the bar register their card (FrameCard) so its
    // background is drawn as a blob in the frame's group and melts out of it.
    property bool styleFrame: true
    // false when Caelestia.Blobs can't load (no QML_IMPORT_PATH): the bar then
    // keeps the classic island look instead of failing to start
    property bool frameAvailable: true
    readonly property bool frameOn: styleFrame && frameAvailable
    property bool styleFrameEdge: true      // accent rim along the frame's inner edge
    property bool styleAutoHide: false      // bar collapses to the frame edge until hovered
    property bool styleDeskClock: true      // large clock on the wallpaper (DeskClock.qml)
    property bool styleDeskVisualiser: false // audio bars on an empty desktop (DeskVisualiser.qml)
    // panels opened by hovering a frame edge close again when the pointer leaves
    // them, and don't take keyboard focus
    property bool notifHoverOpened: false
    property bool utilitiesHoverOpened: false
    property bool dashboardHoverOpened: false
    property bool drawerHoverOpened: false
    readonly property int frameThickness: 10
    readonly property int frameRounding: 0     // square inner corners
    // the edge rim matches the window borders: Hyprland's active border runs
    // color0 → color1 (themes/_templates/hyprland.lua.in); color1 is its bright end.
    // A theme's optional `border` key replaces it, toned well down toward paper
    // since the rim is far thicker than a 1px window border.
    property string paletteBorder: ""
    readonly property real frameEdgeBorderDim: 0.55
    readonly property color frameEdge: paletteBorder === "" ? color01 : Qt.rgba(
        _pb.r * (1 - frameEdgeBorderDim) + paper.r * frameEdgeBorderDim,
        _pb.g * (1 - frameEdgeBorderDim) + paper.g * frameEdgeBorderDim,
        _pb.b * (1 - frameEdgeBorderDim) + paper.b * frameEdgeBorderDim, 1.0)
    readonly property color _pb: paletteBorder === "" ? color01 : paletteBorder
    // the active window border's bright end, untoned (workspace styles mark the
    // focused workspace with it so the bar and Hyprland agree)
    readonly property color windowBorder: _pb
    // the frame layer's alpha: with Frost, low enough that Hyprland's layer blur
    // (71-layers.lua) reads through the bar band and the panels
    readonly property real frameOpacity: styleFrost ? 0.55 : barOpacity
    readonly property color frameColor: styleDepth ? surfaceTone(0.03, 1) : Qt.rgba(paper.r, paper.g, paper.b, 1)
    // a split bar's sections in frame mode: a tone above the band, same alpha
    readonly property color frameRunFill:   surfaceTone(styleDepth ? 0.09 : 0.06, frameOpacity)
    readonly property color frameRunBorder: surfaceTone(0.14, frameOpacity)
    // attached cards hand their background to the frame
    readonly property color frameCardBg: frameOn ? "transparent" : cardBg
    readonly property int frameCardBorderW: frameOn ? 0 : pillBorderW
    // every assignment rebuilds FrameBlobs' delegates, so changes made in the
    // same tick (all panels registering at startup) land as one update
    property var frameCards: []
    property var _frameCardsPending: null
    function _editFrameCards(fn) {
        if (_frameCardsPending === null) {
            _frameCardsPending = frameCards.slice()
            Qt.callLater(function () {
                theme.frameCards = theme._frameCardsPending
                theme._frameCardsPending = null
            })
        }
        fn(_frameCardsPending)
    }
    function registerFrameCard(c) {
        _editFrameCards(function (a) { if (a.indexOf(c) < 0) a.push(c) })
    }
    function unregisterFrameCard(c) {
        _editFrameCards(function (a) { var i = a.indexOf(c); if (i >= 0) a.splice(i, 1) })
    }
    readonly property color fg:     ink
    readonly property color muted:  sumi
    readonly property color accent: seal
    readonly property color warn:   seal
    readonly property color sep:    Qt.rgba(ink.r, ink.g, ink.b, 0.18)

    // ── interactive fill tokens (button/tile backgrounds) ──
    // One source of truth so every panel uses the same hover/active/idle alpha
    // instead of ad-hoc rgba literals scattered across the panels.
    readonly property real  fillActiveAlpha: 0.18
    readonly property real  fillHoverAlpha:  0.10
    readonly property color fillActive:      Qt.rgba(seal.r, seal.g, seal.b, fillActiveAlpha) // selected/active OR ghost-action hover
    readonly property color fillHover:        Qt.rgba(seal.r, seal.g, seal.b, fillHoverAlpha)  // light-seal hover (idle chip → this → fillActive)
    readonly property color fillIdle:         Qt.rgba(0, 0, 0, 0.12)              // resting chip (slight darken)
    // faint, NEUTRAL backdrop behind picker thumbnails — NOT an interactive fill.
    // ink-tinted and much weaker than fillIdle so a thumbnail sits on a quiet frame,
    // not on a dark interactive-looking box.
    readonly property color frameWeak:        Qt.rgba(ink.r, ink.g, ink.b, 0.05)
    readonly property color fillPrimaryHover: Qt.lighter(seal, 1.15)                // solid-seal button hover
    function evenW(w) { return 2 * Math.round(w / 2) }  // even px width -> integer-centered native text (crisp)

    // ── Multi-monitor popup routing ─────────────────────────────
    // Bars exist per screen, but panels remain singletons. The bar under the
    // pointer publishes its screen + local anchor map before any widget opens a
    // popup, so the singleton panel can move to the correct output.
    property var activePopupScreen: null
    property string activePopupScreenName: ""
    property var barAnchorsByScreen: ({})
    property bool _closingPopups: false
    property var barLayoutControllers: ({})
    property bool _barLayoutSyncing: false

    readonly property bool anyPopupVisible: calendarVisible || cpuVisible || aiUsageVisible
        || memVisible || volVisible || langVisible || controlVisible || networkVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible || keybindsVisible
        || workspaceVisible || imagePickerVisible || mediaBrowserVisible || notifVisible
        || powerProfileVisible || trayVisible || trayMenuVisible || utilitiesVisible
        || dashboardVisible || drawerVisible || sessionVisible || windowInfoVisible || settingsVisible
    readonly property bool keyboardPopupVisible: imagePickerVisible || mediaBrowserVisible

    function registerBarLayoutController(screenName, controller) {
        if (!screenName || !controller) return

        var next = {}
        for (var screen in barLayoutControllers) next[screen] = barLayoutControllers[screen]
        next[screenName] = controller
        barLayoutControllers = next
    }

    function unregisterBarLayoutController(screenName, controller) {
        if (!screenName) return
        if (controller && barLayoutControllers[screenName] !== controller) return

        var next = {}
        for (var screen in barLayoutControllers) {
            if (screen !== screenName) next[screen] = barLayoutControllers[screen]
        }
        barLayoutControllers = next
    }

    function barLayoutControllerScreenValid(screenName) {
        if (!screenName) return false

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var screen = Quickshell.screens[i]
            if (screen.name === screenName && screen.width > 0 && screen.height > 0) return true
        }
        return false
    }

    function barLayoutControllerKeys() {
        var keys = []
        for (var screen in barLayoutControllers) {
            if (barLayoutControllerScreenValid(screen)) keys.push(screen)
        }
        keys.sort()
        return keys
    }

    function applyToBarLayoutControllers(actionName) {
        var keys = barLayoutControllerKeys()

        _barLayoutSyncing = true
        try {
            for (var i = 0; i < keys.length; i++) {
                var controller = barLayoutControllers[keys[i]]
                if (controller && controller[actionName]) controller[actionName]()
            }
        } finally {
            _barLayoutSyncing = false
        }
    }

    function syncBarSplits(sourceScreenName, serialized) {
        if (_barLayoutSyncing || !serialized) return

        _barLayoutSyncing = true
        try {
            var keys = barLayoutControllerKeys()
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] === sourceScreenName) continue
                var controller = barLayoutControllers[keys[i]]
                if (controller && controller.applySplits) controller.applySplits(serialized)
            }
        } finally {
            _barLayoutSyncing = false
        }
    }

    function syncBarOrder(sourceScreenName, serialized) {
        if (_barLayoutSyncing || !serialized) return

        _barLayoutSyncing = true
        try {
            var keys = barLayoutControllerKeys()
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] === sourceScreenName) continue
                var controller = barLayoutControllers[keys[i]]
                if (controller && controller.applyOrder) controller.applyOrder(serialized)
            }
        } finally {
            _barLayoutSyncing = false
        }
    }

    function splitAllBars() {
        applyToBarLayoutControllers("splitAll")
    }

    function mergeAllBars() {
        applyToBarLayoutControllers("mergeAll")
    }

    function resetAllBarLayouts() {
        applyToBarLayoutControllers("defaultLayout")
        resetCompactDisplayModes()
    }

    function resetCompactDisplayModes() {
        var changed = compactNetwork || compactBattery || compactBrightness || compactCpu
                   || compactMemory || compactVolume || compactBluetooth || compactPower
                   || compactMpris
        _compactResetting = true
        compactNetwork = false
        compactBattery = false
        compactBrightness = false
        compactCpu = false
        compactMemory = false
        compactVolume = false
        compactBluetooth = false
        compactPower = false
        compactMpris = false
        _compactResetting = false
        if (changed && _widgetsLoaded) saveWidgets()
    }

    function activatePopupScreen(screen) {
        if (!screen || screen.name === "") return

        // panels anchor to a bar: a screen without one (barMonitor) hands
        // its popups to a screen that has one
        if (!barLayoutControllers[screen.name]) {
            var keys = barLayoutControllerKeys()
            for (var i = 0; keys.length > 0 && i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === keys[0]) { screen = Quickshell.screens[i]; break }
            }
        }

        activePopupScreen = screen
        activePopupScreenName = screen.name
        applyActiveBarAnchors()
    }

    function activateFocusedPopupScreen() {
        var monitor = Hyprland.focusedMonitor
        var targetName = monitor ? monitor.name : ""

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name === targetName
                    && candidate.width > 0
                    && candidate.height > 0) {
                activatePopupScreen(candidate)
                return true
            }
        }

        if (activePopupScreenName !== "") return true

        for (var j = 0; j < Quickshell.screens.length; j++) {
            var fallback = Quickshell.screens[j]
            if (fallback.name !== ""
                    && fallback.width > 0
                    && fallback.height > 0) {
                activatePopupScreen(fallback)
                return true
            }
        }

        return false
    }

    function activatePopupScreenByName(screenName) {
        if (screenName) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var candidate = Quickshell.screens[i]
                if (candidate.name === screenName
                        && candidate.width > 0
                        && candidate.height > 0) {
                    activatePopupScreen(candidate)
                    return true
                }
            }
        }

        return activateFocusedPopupScreen()
    }

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged() {
            if (!theme.keyboardPopupVisible || theme.activePopupScreenName === "") return

            var monitor = Hyprland.focusedMonitor
            var focusedName = monitor ? monitor.name : ""
            if (focusedName !== "" && focusedName !== theme.activePopupScreenName) {
                theme.closePopups()
            }
        }
    }

    function isActivePopupScreenName(screenName) {
        return activePopupScreenName !== "" && screenName === activePopupScreenName
    }

    function applyAnchor(name, x) {
        if (name === "tray") trayBarX = x
        else if (name === "notif") notifBarX = x
        else if (name === "quickActions") quickActionsBarX = x
        else if (name === "volume") volumeBarX = x
        else if (name === "language") languageBarX = x
        else if (name === "network") networkBarX = x
        else if (name === "battery") batteryBarX = x
        else if (name === "memory") memoryBarX = x
        else if (name === "cpu") cpuBarX = x
        else if (name === "ai") aiBarX = x
        else if (name === "workspace") workspaceBarX = x
        else if (name === "bluetooth") bluetoothBarX = x
        else if (name === "brightness") brightnessBarX = x
        else if (name === "power") powerBarX = x
        else if (name === "mpris") mprisBarX = x
        else if (name === "weather") weatherBarX = x
        else if (name === "launcher") launcherBarX = x
        else if (name === "calendar") calendarBarX = x
        else if (name === "gpu") gpuBarX = x
        else if (name === "thermal") thermalBarX = x
        else if (name === "storage") storageBarX = x
        else if (name === "github") githubBarX = x
        else if (name === "trayMenu") trayMenuX = x
    }

    function applyActiveBarAnchors() {
        var anchors = activePopupScreenName ? barAnchorsByScreen[activePopupScreenName] : null
        if (!anchors) return

        for (var name in anchors) applyAnchor(name, anchors[name])
    }

    function publishBarAnchors(screenName, anchors) {
        if (!screenName || !anchors) return

        var next = {}
        for (var screen in barAnchorsByScreen) next[screen] = barAnchorsByScreen[screen]
        next[screenName] = anchors
        barAnchorsByScreen = next

        if (screenName === activePopupScreenName) applyActiveBarAnchors()
    }

    function setPanelAnchor(name, x, screenName) {
        var targetScreen = screenName || activePopupScreenName
        if (targetScreen) {
            var next = {}
            for (var screen in barAnchorsByScreen) next[screen] = barAnchorsByScreen[screen]

            var current = next[targetScreen] || {}
            var anchors = {}
            for (var key in current) anchors[key] = current[key]
            anchors[name] = x
            next[targetScreen] = anchors
            barAnchorsByScreen = next
        }

        if (!targetScreen || targetScreen === activePopupScreenName) applyAnchor(name, x)
    }

    function closePopups(except) {
        _closingPopups = true
        if (except !== "calendarVisible") calendarVisible = false
        if (except !== "cpuVisible") cpuVisible = false
        if (except !== "aiUsageVisible") aiUsageVisible = false
        if (except !== "memVisible") memVisible = false
        if (except !== "volVisible") volVisible = false
        if (except !== "langVisible") langVisible = false
        if (except !== "controlVisible") controlVisible = false
        if (except !== "networkVisible") networkVisible = false
        if (except !== "bluetoothVisible") bluetoothVisible = false
        if (except !== "batteryVisible") batteryVisible = false
        if (except !== "brightnessVisible") brightnessVisible = false
        if (except !== "mprisVisible") mprisVisible = false
        if (except !== "weatherVisible") weatherVisible = false
        if (except !== "keybindsVisible") keybindsVisible = false
        if (except !== "workspaceVisible") workspaceVisible = false
        if (except !== "imagePickerVisible") imagePickerVisible = false
        if (except !== "mediaBrowserVisible") mediaBrowserVisible = false
        if (except !== "notifVisible") notifVisible = false
        if (except !== "powerProfileVisible") powerProfileVisible = false
        if (except !== "trayVisible") trayVisible = false
        if (except !== "trayMenuVisible") trayMenuVisible = false
        if (except !== "githubVisible") githubVisible = false
        if (except !== "utilitiesVisible") utilitiesVisible = false
        if (except !== "dashboardVisible") dashboardVisible = false
        if (except !== "drawerVisible") drawerVisible = false
        if (except !== "sessionVisible") sessionVisible = false
        if (except !== "windowInfoVisible") windowInfoVisible = false
        if (except !== "settingsVisible") settingsVisible = false
        hideTooltip()
        _closingPopups = false
    }

    function popupOpened(prop) {
        if (!_closingPopups && theme[prop]) closePopups(prop)
    }

    function openImagePicker(mode, screen) {
        if (imagePickerVisible && imagePickerMode !== mode)
            imagePickerVisible = false
        if (screen && screen.name !== "") activatePopupScreen(screen)
        else activateFocusedPopupScreen()
        mediaBrowserVisible = false
        imagePickerMode = mode
        imagePickerVisible = true
    }

    function toggleImagePicker(mode, screen) {
        if (imagePickerVisible && imagePickerMode === mode) {
            imagePickerVisible = false
            return
        }

        openImagePicker(mode, screen)
    }

    function openMediaBrowser(mode) {
        activateFocusedPopupScreen()
        imagePickerVisible = false
        mediaBrowserMode = mode
        mediaBrowserVisible = true
    }

    // ── pill/card border (default, non-borderless mode) ──
    // A premium "inactive window border" look: the surface tone (paper) nudged a
    // tick toward the foreground (ink) → a quiet edge a touch brighter than the
    // background, theme-aware in BOTH dark and light palettes. Tune via pillBorderMix.
    property real pillBorderMix: 0.13
    readonly property color pillBorder: Qt.rgba(
        paper.r * (1 - pillBorderMix) + ink.r * pillBorderMix,
        paper.g * (1 - pillBorderMix) + ink.g * pillBorderMix,
        paper.b * (1 - pillBorderMix) + ink.b * pillBorderMix, 1.0)
    // outer frame (the island edge against the wallpaper): a tick brighter than
    // the inner pill border so the bar lifts off the background → two readable
    // borders (subtle inner pills + a defined outer frame).
    property real islandBorderMix: 0.16
    readonly property color islandBorder: Qt.rgba(
        paper.r * (1 - islandBorderMix) + ink.r * islandBorderMix,
        paper.g * (1 - islandBorderMix) + ink.g * islandBorderMix,
        paper.b * (1 - islandBorderMix) + ink.b * islandBorderMix, 1.0)

    // ── bar style tokens (persisted; consumed by every pill/card surface) ──
    // Single source for the pill recipe; consumed by 37 surfaces (12 widgets +
    // 3 group pills + island + 20 cards + tooltip) — change the recipe here once.
    // border on/off and shadow on/off are INDEPENDENT (4 combos possible).
    property bool styleBorder:      true    // pill/card 1px border on/off
    property bool styleShadow:      false   // box-shadow on/off
    property bool styleFrost:       false   // lower bar-island opacity; theme blur may show through
    property bool styleRadiusSmall: false   // radius 12 ⇄ 6
    property bool styleHeightMin:   false   // inner pill 24 ⇄ 20 (slot stays 28)
    property bool styleIconLabels:  false   // CPU/MEM/VOL/… text labels ⇄ Material Symbols glyphs
    readonly property int   pillRadius:   styleRadiusSmall ? 6 : 12
    readonly property int   pillH:        styleHeightMin ? 20 : 24
    readonly property int   pillBorderW:  styleBorder && !frameOn ? 1 : 0
    readonly property int   islandRadius: styleRadiusSmall ? 8 : 16
    readonly property int   tileRadius:   pillRadius - 2   // inner panel buttons: 2 less than global (10 ⇄ 4)
    readonly property int v2ActionIconCellWidth: 22
    readonly property int v2IconGroupPadding: 5
    property real v2BarBorderMix: 0.22
    readonly property color v2BarBorder: Qt.rgba(
        paper.r * (1 - v2BarBorderMix) + ink.r * v2BarBorderMix,
        paper.g * (1 - v2BarBorderMix) + ink.g * v2BarBorderMix,
        paper.b * (1 - v2BarBorderMix) + ink.b * v2BarBorderMix, 1.0)
    readonly property color v2BarShadow: Qt.rgba(0, 0, 0, 0.46)
    property bool panelTooltipBorderEnabled: true
    property string barShellStyle: "full"
    property bool barBorderEnabled: true
    function barShellStyleValid(value) {
        return value === "full" || value === "fit"
            || value === "dock" || value === "notch"
    }
    readonly property int v2BarHeight: 33
    readonly property int v2NotchFrameThickness: 6
    readonly property int v2NotchFrameRadius: 14
    readonly property int   panelRadius:       6
    readonly property int   panelButtonRadius: 6
    readonly property color panelBorder:       v2BarBorder
    readonly property int   panelBorderW:      1
    readonly property color panelOuterBorderColor: panelTooltipBorderEnabled
        ? panelBorder : Qt.rgba(0, 0, 0, 0)
    readonly property int panelOuterBorderW: panelTooltipBorderEnabled ? panelBorderW : 0
    property real panelInsetX: 0
    function setPanelInsetX(x) {
        if (isFinite(x) && x > 0) panelInsetX = x
    }
    readonly property bool anchoredPanelVisible: calendarVisible || cpuVisible || gpuVisible
        || thermalVisible || aiUsageVisible || langVisible || keybindsVisible
        || memVisible || volVisible || controlVisible || networkVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible
        || workspaceVisible || notifVisible || powerProfileVisible || storageVisible
        || trayVisible

    readonly property real activePanelCaretX:
        calendarVisible ? calendarBarX
        : cpuVisible ? cpuBarX
        : gpuVisible ? gpuBarX
        : thermalVisible ? thermalBarX
        : aiUsageVisible ? aiBarX
        : memVisible ? memoryBarX
        : volVisible ? volumeBarX
        : langVisible ? languageBarX
        : keybindsVisible ? quickActionsBarX
        : controlVisible ? launcherBarX
        : networkVisible ? networkBarX
        : bluetoothVisible ? bluetoothBarX
        : batteryVisible ? batteryBarX
        : brightnessVisible ? brightnessBarX
        : mprisVisible ? mprisBarX
        : weatherVisible ? weatherBarX
        : workspaceVisible ? workspaceBarX
        : notifVisible ? notifBarX
        : powerProfileVisible ? powerBarX
        : storageVisible ? storageBarX
        : trayVisible ? trayBarX
        : 0

    property real panelInsetReveal: anchoredPanelVisible ? 1 : 0
    Behavior on panelInsetReveal {
        NumberAnimation {
            duration: theme.anchoredPanelVisible ? 160 : 120
            easing.type: theme.anchoredPanelVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    // horizontal padding of the workspace pill (overhang each side, mirrored by the
    // G2 slot pad). In "numbers" the wide digit badges should nestle concentrically
    // into the pill's inner radius → pad = pillRadius - badgeRadius; else a fixed 4.
    readonly property int   wsPillPad:    workspaceStyle === "numbers"
                                          ? Math.max(1, pillRadius - (styleRadiusSmall ? 5 : 10))
                                          : 4
    readonly property color pillShadow:   Qt.rgba(0, 0, 0, 0.55)   // dark, theme-independent

    property string lastAppliedName: ""

    // ── Tooltip state ──
    property string tooltipText: ""
    property real tooltipX: 0
    property real tooltipY: 0
    property real tooltipTopY: 0
    property real tooltipBottomY: 0
    property bool tooltipShown: false
    property var tooltipOwner: null   // the widget currently owning the tooltip

    function showTooltip(text, x, topY, bottomY, owner) {
        if (!text) return;
        tooltipText = text;
        tooltipX = x;
        tooltipTopY = topY;
        tooltipBottomY = bottomY;
        tooltipY = (topY + bottomY) / 2;
        tooltipOwner = owner !== undefined ? owner : null;
        tooltipShown = true;
    }

    // hide only if the caller owns the current tooltip (owner match is stable
    // even when the tooltip text changes, e.g. a live timer). A null/undefined
    // owner force-hides. Legacy string args fall back to a text match.
    function hideTooltip(owner) {
        if (owner === undefined || owner === null) {
            tooltipShown = false; tooltipOwner = null;
        } else if (typeof owner === "object") {
            if (tooltipOwner === owner) { tooltipShown = false; tooltipOwner = null; }
        } else if (tooltipText === owner) {
            tooltipShown = false; tooltipOwner = null;
        }
    }

    // safety net: if the owning widget disappears while its tooltip is shown
    // (e.g. ScreenRecord stops mid-hover, or a slot widget gets disabled), force-hide.
    // Via Connections — NOT a `_visible` property whose change-handler writes
    // tooltipOwner (that property read tooltipOwner → binding loop).
    Connections {
        target: theme.tooltipOwner
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (theme.tooltipOwner && !theme.tooltipOwner.visible) {
                theme.tooltipShown = false; theme.tooltipOwner = null;
            }
        }
    }

    // ── Calendar state ──
    property bool calendarVisible: false
    onCalendarVisibleChanged: popupOpened("calendarVisible")
    property int calendarMonthOffset: 0
    property int calendarTick: 0
    property int selectedDay: 0

    readonly property var calendarCells: {
        calendarTick;
        const now = new Date();
        const first = new Date(now.getFullYear(), now.getMonth() + calendarMonthOffset, 1);
        const year = first.getFullYear();
        const month = first.getMonth();
        const lastDay = new Date(year, month + 1, 0).getDate();
        const startDay = (first.getDay() + 6) % 7;
        const today = new Date();
        const isCurrentMonth = year === today.getFullYear() && month === today.getMonth();
        const cells = [];
        for (let i = 0; i < startDay; i++) cells.push({day: 0, today: false});
        for (let d = 1; d <= lastDay; d++) {
            cells.push({day: d, today: isCurrentMonth && d === today.getDate()});
        }
        while (cells.length < 42) cells.push({day: 0, today: false});
        return cells;
    }

    readonly property string calendarMonthName: {
        const months = ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
                        "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"];
        const now = new Date();
        return months[(now.getMonth() + calendarMonthOffset + 12000) % 12];
    }

    readonly property string calendarYear: {
        const now = new Date();
        const d = new Date(now.getFullYear(), now.getMonth() + calendarMonthOffset, 1);
        return String(d.getFullYear());
    }

    function openCalendar() {
        calendarMonthOffset = 0;
        calendarTick++;
        selectedDay = (new Date()).getDate();
        calendarVisible = true;
    }

    // ── CPU panel state ──
    property bool cpuVisible: false
    onCpuVisibleChanged: popupOpened("cpuVisible")
    property bool gpuVisible: false
    onGpuVisibleChanged: popupOpened("gpuVisible")
    property bool thermalVisible: false
    onThermalVisibleChanged: popupOpened("thermalVisible")
    property bool storageVisible: false
    onStorageVisibleChanged: popupOpened("storageVisible")
    property bool utilitiesVisible: false
    property bool dashboardVisible: false
    onDashboardVisibleChanged: {
        if (!dashboardVisible) dashboardHoverOpened = false
        popupOpened("dashboardVisible")
    }
    property bool sessionVisible: false
    onSessionVisibleChanged: popupOpened("sessionVisible")
    property bool windowInfoVisible: false
    onWindowInfoVisibleChanged: popupOpened("windowInfoVisible")
    property bool settingsVisible: false
    onSettingsVisibleChanged: popupOpened("settingsVisible")
    property bool drawerVisible: false
    onDrawerVisibleChanged: {
        if (!drawerVisible) drawerHoverOpened = false
        popupOpened("drawerVisible")
    }
    onUtilitiesVisibleChanged: {
        if (!utilitiesVisible) utilitiesHoverOpened = false
        popupOpened("utilitiesVisible")
    }




    // ── Memory panel state ──
    property bool memVisible: false
    onMemVisibleChanged: popupOpened("memVisible")

    // ── Volume panel state ──
    property bool volVisible: false
    onVolVisibleChanged: popupOpened("volVisible")

    // ── Language panel state ──
    property bool langVisible: false
    onLangVisibleChanged: popupOpened("langVisible")

    // ── Control center state ──
    property bool controlVisible: false
    onControlVisibleChanged: {
        popupOpened("controlVisible")
        if (!controlVisible) { splitsSubVisible = false; wwSubVisible = false }
    }

    // ── Split state (controlled by Bar + ControlPanel) ──
    property bool splitLeft:   false
    property bool splitRight:  false
    property bool splitArch:   false
    property bool splitMon:    false
    property bool splitNet:    false
    property bool splitMprisL: false
    readonly property int specBands: 32
    property var spectrum: []
    property var spectrumPeak: []
    MprisSelect { id: specSel }
    readonly property bool specWanted: theme.barAnim === 14 && specSel.playing

    Process {
        id: specCava
        running: theme.specWanted
        command: ["bash", "-c",
            "command -v cava >/dev/null 2>&1 || exit 0; " +
            "exec cava -p <(printf '%s\\n' " +
            "'[general]' 'bars = 32' 'framerate = 60' 'autosens = 1' 'sleep_timer = 0' " +
            "'[input]' 'method = pipewire' 'source = auto' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'[smoothing]' 'monstercat = 0' 'waves = 0' 'noise_reduction = 20')"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!theme.specWanted) return
                var parts = line.split(";")
                var cur = theme.spectrum
                var pks = theme.spectrumPeak
                var out = []
                var opk = []
                for (var i = 0; i < theme.specBands; i++) {
                    var raw = parseInt(parts[i])
                    raw = isNaN(raw) ? 0 : Math.min(1, raw / 100)
                    var prev = i < cur.length ? cur[i] : 0
                    var v = raw > prev ? raw : prev + (raw - prev) * 0.34
                    out.push(v)
                    var pp = i < pks.length ? pks[i] : 0
                    opk.push(v > pp ? v : Math.max(v, pp - 0.011))
                }
                theme.spectrum = out
                theme.spectrumPeak = opk
            }
        }
    }

    // per-frame decay (vsync-smooth at any refresh rate); constants are the
    // tuned 30 Hz per-tick values, scaled by the real frame time
    FrameAnimation {
        running: !theme.specWanted && theme.spectrum.length > 0
        onTriggered: {
            var k = Math.min(frameTime, 0.1) / 0.033
            var keep = Math.pow(0.80, k)
            var s = theme.spectrum
            var p = theme.spectrumPeak
            var a = []
            var b = []
            var live = false
            for (var i = 0; i < s.length; i++) {
                var v = s[i] * keep
                if (v < 0.005) v = 0; else live = true
                var q = (i < p.length ? p[i] : 0) - 0.022 * k
                if (q < v) q = v
                if (q < 0.005) q = 0; else live = true
                a.push(v); b.push(q)
            }
            if (live) { theme.spectrum = a; theme.spectrumPeak = b }
            else      { theme.spectrum = []; theme.spectrumPeak = [] }
        }
    }

    property int barAnim: 0   // 0=off, 1=stream, 2=surge, 3=bolt, 4=bolt2, 5=stream2, 6=surge2, 7=reactor, 8=quotes, 9=weave, 10=pluck, 11=embers, 12=mercury, 13=harmonic, 14=scope

    // ── Bar layout / unlock (drag&drop reorder). barUnlocked is transient. ──
    property bool barUnlocked: false
    // split-control hooks called by the ControlPanel split sub-panel.
    property var  fnSplitAll:      function () { theme.splitAllBars() }
    property var  fnMergeAll:      function () { theme.mergeAllBars() }
    property var  fnDefaultLayout: function () { theme.resetAllBarLayouts() }
    property bool splitsSubVisible: false
    property bool wwSubVisible: false   // "Widgets & Workspaces" fly-out

    // Legacy split booleans are kept only for cache compatibility. The active
    // split system lives in BarSlot's per-gap arrays; ParticleStream is gated by
    // the real run count there, so barAnim no longer follows these old flags.
    function mergeAllSplits() {
        splitLeft = false; splitRight = false; splitArch = false;
        splitMon = false; splitNet = false; splitMprisL = false;
    }

    // ── Control-panel state persistence (splits / anim / accent) ──
    // Survives bar restarts via a tiny cache file; no extra deps (same Process+cat
    // pattern used elsewhere). _splitsLoaded gates saving so the initial restore
    // doesn't immediately write back over itself.
    readonly property string splitsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_splits"
    property bool _splitsLoaded: false


    // Build the command imperatively (not as a binding): a bound `command` can
    // still hold the pre-toggle value when the Process runs, saving stale state.
    function saveSplits() { scheduleSettingsSave() }

    Process {
        id: splitLoadProc
        command: ["cat", theme.splitsCachePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(" ")
                if (parts.length >= 5) {
                    theme.splitArch      = parts[0] === "1"
                    theme.splitMon       = parts[1] === "1"
                    theme.splitMprisL    = parts[2] === "1"
                    theme.splitNet       = parts[3] === "1"
                    var ba = parseInt(parts[4]); theme.barAnim = (ba >= 0 && ba <= 14) ? ba : 0
                    if (parts.length >= 6) {
                        var bc = parts[5]
                        if (bc === "1" || bc === "0") theme.barColor = "color01"
                        else if (bc === "green" || bc === "color2") theme.barColor = "color02"
                        else if (bc === "yellow" || bc === "color3") theme.barColor = "color03"
                        else if (theme.barColorValid(bc)) theme.barColor = theme.normalizedPaletteId(bc)
                    }
                }
                theme._splitsLoaded = true
                theme._finishLegacyMigration()
            }
        }
    }


    // ── module enable flags (controlled by ControlPanel) ──
    property bool modStatus:     true
    property bool modMemory:     true
    property bool modCpu:        true
    property bool modGpu:        true
    property bool modCpuTemperature: true
    property bool modStorage:    true
    property bool modVolume:     true
    property bool modWeather:    true
    property bool modNetwork:    true
    property string networkMode: "none"   // mirrored from NetworkWidget: wifi/ethernet/none
    property bool dotsUpdateAvail: false   // mirrored from UpdateWidget (6h poll)
    property int dotsUpdateCheckTick: 0    // ++ re-runs UpdateWidget's check (ipc dots.system-update refresh)
    // Centralized status indicators. These live on Theme so BarSlot-per-monitor
    // widgets don't each spawn their own status poller.
    property bool stayAwake: false            // idle lock disabled / stay-awake indicator
    readonly property bool hypridleAwake: stayAwake // compatibility alias for older modules
    property bool _idleBackendChecked: false
    property bool _idleNixOSShellBackend: false
    property bool _idleNixOSShellSystem: false
    property bool _dotsBackendReprobePending: false
    property int _dotsBackendRetryIndex: 0
    readonly property var _dotsBackendRetryDelays: [2000, 5000, 15000]
    readonly property string dotsShellConfigPath: Quickshell.env("HOME") + "/.local/state/dots/shell/shell.json"
    readonly property string idleStatePath: Quickshell.env("HOME") + "/.local/state/dots/indicators/stay-awake"
    readonly property string voxPhasePath: Quickshell.env("HOME") + "/.local/state/dots/voxtype/phase"
    property bool notifSilenced: false        // notification do-not-disturb mode
    property var notifService: null           // NotificationService, set by VariantRoot
    property bool capsLockOn: false           // any keyboard's capslock LED lit

    // Every keyboard has its own LED. Builtin reads and a read -t sleep keep
    // the loop fork-free; it prints only on change.
    Process {
        running: true
        command: ["bash", "-c",
            "exec {t}<> <(:); last=; while :; do on=0; " +
            "for f in /sys/class/leds/*::capslock/brightness; do read -r v < \"$f\" && [ \"$v\" != 0 ] && on=1; done; " +
            "[ \"$on\" != \"$last\" ] && echo $on && last=$on; read -t 0.25 -u $t; done"]
        stdout: SplitParser { onRead: function(line) { theme.capsLockOn = line.trim() === "1" } }
    }
    property bool _notifBackendChecked: false
    property bool _notifNixOSShellBackend: false
    property bool _notifNixOSShellSystem: false
    readonly property string notificationsStatePath: Quickshell.env("HOME") + "/.local/state/dots/notifications.json"
    property bool screenRecording: false
    property int screenRecordingElapsed: 0
    property string _screenRecordingPid: ""
    property string _screenRecordingElapsedProbePid: ""
    property int _screenRecordingBaseElapsed: 0
    property real _screenRecordingBaseMs: 0
    readonly property string screenRecordingStatePath: "/tmp/dots-screenrecord-filename"
    property bool _recordingRefreshPending: false
    property string voxState: "idle"          // idle/recording/transcribing
    property string voxHint: ""
    property bool voxAvailable: true
    readonly property bool _statusPollingWanted: modStatus || barAnim === 7
    readonly property bool _voxActive: voxState === "recording" || voxState === "transcribing"

    function refreshIdleStatus() {
        if (!_idleBackendChecked) return
        if (_idleNixOSShellSystem) {
            idleStateFile.reload()
            return
        }
        if (!idleProc.running) idleProc.running = true
    }
    function refreshStatusIndicators() {
        refreshIdleStatus()
        refreshNotificationStatus()
    }
    function reprobeNixOSShellBackends() {
        if (idleBackendProc.running || notifBackendProc.running) {
            _dotsBackendReprobePending = true
            return
        }
        _dotsBackendReprobePending = false
        idleBackendProc.running = true
        notifBackendProc.running = true
    }
    function finishNixOSBackendReprobe() {
        if (idleBackendProc.running || notifBackendProc.running) return
        if (_dotsBackendReprobePending) {
            dotsBackendProbeDebounce.restart()
            return
        }
        scheduleNixOSBackendRetry()
    }
    function dotsBackendRetryNeeded() {
        return (_idleNixOSShellSystem && !_idleNixOSShellBackend)
            || (_notifNixOSShellSystem && !_notifNixOSShellBackend)
    }
    function scheduleNixOSBackendRetry() {
        if (!dotsBackendRetryNeeded()) {
            dotsBackendRetryTimer.stop()
            _dotsBackendRetryIndex = 0
            return
        }
        if (dotsBackendConfirmTimer.running || dotsBackendRetryTimer.running
                || _dotsBackendRetryIndex >= _dotsBackendRetryDelays.length) return
        dotsBackendRetryTimer.interval = _dotsBackendRetryDelays[_dotsBackendRetryIndex]
        _dotsBackendRetryIndex++
        dotsBackendRetryTimer.restart()
    }
    function resetNixOSBackendProbes() {
        dotsBackendRetryTimer.stop()
        _dotsBackendRetryIndex = 0
        dotsBackendProbeDebounce.restart()
        dotsBackendConfirmTimer.restart()
    }
    function parseNotificationsState(text) {
        try {
            var parsed = JSON.parse(String(text || "{}"))
            notifSilenced = parsed && parsed.dnd === true
        } catch (e) {
            notifSilenced = false
        }
    }
    function refreshNotificationStatus() {
        if (!_notifBackendChecked) return
        if (_notifNixOSShellSystem) {
            notificationsStateFile.reload()
            return
        }
        if (!dndProc.running) dndProc.running = true
    }
    function refreshRecordingStatus() {
        if (recordingPidProc.running) {
            _recordingRefreshPending = true
            return
        }
        recordingPidProc.running = true
    }
    function reconcileSlowStatusIndicators() {
        refreshRecordingStatus()
    }
    function setScreenRecordingPid(pid) {
        pid = String(pid || "").trim()
        if (pid === _screenRecordingPid) return

        _screenRecordingPid = pid
        if (pid === "") {
            screenRecording = false
            screenRecordingElapsed = 0
            _screenRecordingBaseElapsed = 0
            _screenRecordingBaseMs = 0
            _screenRecordingElapsedProbePid = ""
            return
        }

        screenRecording = true
        screenRecordingElapsed = 0
        _screenRecordingBaseElapsed = 0
        _screenRecordingBaseMs = Date.now()
        _screenRecordingElapsedProbePid = pid
        recordingElapsedProc.command = ["ps", "-o", "etimes=", "-p", pid]
        recordingElapsedProc.running = false
        recordingElapsedProc.running = true
    }
    function updateScreenRecordingElapsed() {
        if (!screenRecording || _screenRecordingBaseMs <= 0) return
        screenRecordingElapsed = _screenRecordingBaseElapsed + Math.floor((Date.now() - _screenRecordingBaseMs) / 1000)
    }
    function refreshVoxtypeStatus() {
        if (!voxAvailable && !modStatus && barAnim !== 7) return
        if (voxProc.running) return
        voxProc.running = true
    }

    Process {
        id: idleBackendProc
        command: ["bash", "-c", "root=${DOTS_SHELL_PATH:-/usr/share/dots}; [[ -f $root/shell/plugins/services/idle/manifest.json ]] || exit 2; command -v dots-shell >/dev/null 2>&1 && DOTS_SHELL_PATH=$root dots-shell idle status >/dev/null 2>&1"]
        running: true
        onExited: (exitCode) => {
            theme._idleNixOSShellSystem = exitCode !== 2
            theme._idleNixOSShellBackend = exitCode === 0
            theme._idleBackendChecked = true
            theme.refreshIdleStatus()
            theme.finishNixOSBackendReprobe()
        }
    }

    FileView {
        id: voxPhaseFile
        path: theme.voxPhasePath
        watchChanges: true
        printErrors: false
        onFileChanged: voxPhaseFile.reload()
        onLoaded: {
            var p = voxPhaseFile.text().trim()
            if (p !== "recording" && p !== "transcribing" && p !== "idle") return
            if (p === theme.voxState) return
            theme.voxState = p
            theme.voxAvailable = true
            theme.refreshVoxtypeStatus()
        }
        onLoadFailed: {}
    }

    FileView {
        id: idleStateFile
        path: theme.idleStatePath
        watchChanges: theme._idleNixOSShellSystem
        printErrors: false
        onFileChanged: idleStateFile.reload()
        onLoaded: {
            if (theme._idleNixOSShellSystem) theme.stayAwake = true
        }
        onLoadFailed: {
            if (theme._idleNixOSShellSystem) theme.stayAwake = false
        }
    }

    Process {
        id: notifBackendProc
        command: ["bash", "-c", "root=${DOTS_SHELL_PATH:-/usr/share/dots}; [[ -f $root/shell/plugins/notifications/manifest.json ]] || exit 2; command -v dots-shell >/dev/null 2>&1 && DOTS_SHELL_PATH=$root dots-shell notifications ping 2>/dev/null | grep -Fxq ok"]
        running: true
        onExited: (exitCode) => {
            theme._notifNixOSShellSystem = exitCode !== 2
            theme._notifNixOSShellBackend = exitCode === 0
            theme._notifBackendChecked = true
            theme.refreshNotificationStatus()
            theme.finishNixOSBackendReprobe()
        }
    }

    FileView {
        id: notificationsStateFile
        path: theme.notificationsStatePath
        watchChanges: theme._notifNixOSShellSystem
        printErrors: false
        onFileChanged: notificationsStateFile.reload()
        onLoaded: {
            if (theme._notifNixOSShellSystem) theme.parseNotificationsState(notificationsStateFile.text())
        }
        onLoadFailed: {
            if (theme._notifNixOSShellSystem) theme.notifSilenced = false
        }
    }

    Timer {
        id: dotsBackendProbeDebounce
        interval: 250
        repeat: false
        onTriggered: theme.reprobeNixOSShellBackends()
    }

    Timer {
        id: dotsBackendRetryTimer
        repeat: false
        onTriggered: theme.reprobeNixOSShellBackends()
    }

    Timer {
        id: dotsBackendConfirmTimer
        interval: 2000
        repeat: false
        onTriggered: {
            theme._dotsBackendRetryIndex = Math.max(1, theme._dotsBackendRetryIndex)
            theme.reprobeNixOSShellBackends()
        }
    }

    FileView {
        id: dotsShellConfigFile
        path: theme.dotsShellConfigPath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            dotsShellConfigFile.reload()
            theme.resetNixOSBackendProbes()
        }
    }

    Process {
        id: idleProc
        command: ["pgrep", "-x", "hypridle"]
        running: false
        onExited: (exitCode) => {
            if (!theme._idleNixOSShellSystem) theme.stayAwake = exitCode !== 0
        }
    }

    Process {
        id: dndProc
        // fallback when the dots-shell notifications backend is missing; the
        // quickshell notification service keeps DND in the same state file
        command: ["bash", "-c", "grep -q '\"dnd\":true' ~/.local/state/dots/notifications.json 2>/dev/null && echo do-not-disturb || echo default"]
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0 && !theme._notifNixOSShellSystem) theme.notifSilenced = false
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!theme._notifNixOSShellSystem) theme.notifSilenced = this.text.indexOf("do-not-disturb") >= 0
            }
        }
    }

    Process {
        id: recordingPidProc
        command: ["bash", "-c", "systemctl --user show dots-gsr.service -p MainPID --value 2>/dev/null | grep -qxE '[1-9][0-9]*' && systemctl --user show dots-gsr.service -p MainPID --value || exit 1"]
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0) theme.setScreenRecordingPid("")
            if (theme._recordingRefreshPending) {
                theme._recordingRefreshPending = false
                theme.refreshRecordingStatus()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(/\s+/)
                theme.setScreenRecordingPid(parts[0] || "")
            }
        }
    }

    FileView {
        id: screenRecordingStateFile
        path: theme.screenRecordingStatePath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            screenRecordingStateFile.reload()
            theme.refreshRecordingStatus()
        }
        onLoaded: theme.refreshRecordingStatus()
        onLoadFailed: theme.refreshRecordingStatus()
    }

    Process {
        id: recordingElapsedProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (theme._screenRecordingElapsedProbePid !== theme._screenRecordingPid) return
                var elapsed = parseInt(this.text.trim())
                if (isNaN(elapsed)) elapsed = 0
                theme._screenRecordingBaseElapsed = Math.max(0, elapsed)
                theme._screenRecordingBaseMs = Date.now()
                theme.updateScreenRecordingElapsed()
            }
        }
    }

    Timer {
        interval: 1500
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.refreshStatusIndicators()
    }

    Timer {
        interval: 45000
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.reconcileSlowStatusIndicators()
    }

    Timer {
        interval: 1000
        running: theme.screenRecording
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.updateScreenRecordingElapsed()
    }

    Process {
        id: voxProc
        command: ["bash", "-c",
            "if command -v voxtype >/dev/null 2>&1; then " +
            "timeout 1 voxtype status --extended --format json 2>/dev/null | jq -r '[(.class // .alt // \"idle\"), ((.tooltip // \"\") | split(\"\\n\")[0])] | @tsv' 2>/dev/null; " +
            "else echo 'MISSING'; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                if (parts[0] === "MISSING") {
                    theme.voxAvailable = false
                    theme.voxState = "idle"
                    theme.voxHint = ""
                    return
                }
                theme.voxAvailable = true
                theme.voxState = parts[0] || "idle"
                theme.voxHint = parts[1] || ""
            }
        }
    }
    Timer {
        interval: theme._voxActive ? 1000 : (theme.voxAvailable ? 10000 : 60000)
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.refreshVoxtypeStatus()
    }
    // battery presence (laptop) — drives the Battery indicator tile's visibility (shown only
    // where a battery exists, like Brightness uses hasBacklight). Direct UPower check, event-driven.
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    // NetworkManager active (NixOS 4.0) → the panel's iwctl scan/connect won't work,
    // so it shows an "open nmtui" button instead of an empty list
    property bool useNM: false
    Process {
        command: ["bash", "-c", "systemctl is-active --quiet NetworkManager && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector { onStreamFinished: theme.useNM = this.text.trim() === "1" }
    }

    // ── wifi/bluetooth settings launchers (NixOS way, via uwsm-app) ──
    // iwd (NixOS 3.8.x) → impala/bluetui through dots-launch-*; if NetworkManager
    // is the active backend (NixOS 4.0) → nmtui instead. Quattro removed the
    // dedicated Bluetooth launcher; prefer a retained bluetui, then bluetoothctl.
    readonly property string launchWifiCmd: "if systemctl is-active --quiet NetworkManager 2>/dev/null; then dots-launch-or-focus-tui nmtui; else dots-launch-wifi; fi"
    readonly property string launchBtCmd:   "if command -v dots-launch-bluetooth >/dev/null 2>&1; then exec dots-launch-bluetooth; elif command -v dots-launch-or-focus-tui >/dev/null 2>&1; then if command -v bluetui >/dev/null 2>&1; then command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true; exec dots-launch-or-focus-tui bluetui; elif command -v bluetoothctl >/dev/null 2>&1; then command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true; exec dots-launch-or-focus-tui bluetoothctl; fi; fi; command -v notify-send >/dev/null 2>&1 && notify-send -a QS-Shell -u critical 'Bluetooth settings unavailable' 'No supported Bluetooth settings backend was found' || true; exit 0"
    property bool modPower:      false   // default off (toggle in ControlPanel)
    property bool modBluetooth:  false   // default off (toggle in ControlPanel)
    property bool modBrightness: true
    property bool modMedia:      true
    property bool modQuick:      true    // G10 group pill (idle-inhibitor · media · theme)
    property bool modMpris:      true    // G9 now-playing / mpris pill
    property bool modAi:         false   // default off (toggle in ControlPanel)
    property bool modGithub:     true

    // Per-widget compact display modes. Defaults are full-width for backwards
    // compatibility; ControlPanel toggles persist these below.
    property bool compactNetwork:    false
    property bool compactBattery:    false
    property bool compactBrightness: false
    property bool compactCpu:        false
    property bool compactMemory:     false
    property bool compactVolume:     false
    property bool compactBluetooth:  false
    property bool compactPower:      false
    property bool compactMpris:      false

    // backlight presence — set by BrightnessWidget once it probes /sys/class/backlight.
    // ControlPanel uses this to hide the Brightness toggle on desktops without one.
    property bool hasBacklight:  false

    // ── which monitor gets the bar (and its frame, desk clock and visualiser):
    //    an output name, or "all"; a named output that isn't connected falls back
    //    to the first screen so there's always a bar ──
    property string barMonitor: "DP-1"
    // ── workspace display mode ──
    property string workspaceMode: "10"   // "10", "5", "active"
    // ── workspace display style (orthogonal to mode; persisted) ──
    property string workspaceStyle: "default"   // "default", "numbers", "magic", "comet", "segments", "occupancy", "icons", "kanji"

    // ── motion (persisted) ──
    property bool motionHover:  true
    property bool motionSweep:  true
    property bool motionDigits: true
    signal barPulse(string kind)

    // ── bar screen position (persisted) ──
    property string barPosition: "top"   // "top" or "bottom"

    // ── picker visual style (theme/wallpaper/screenshot/video pickers) ──
    property string pickerStyle: "tanzaku"   // "tanzaku", "hearthstone", "carousel"
    property bool appLauncherVisible: false
    property bool clipboardVisible: false
    property string launcherLogoMode: "text"     // "text" or "icon"
    property string launcherLogoText: "nixos"  // "dots", "hyprland", or "nixos"
    property string launcherLogoIcon: "nix"  // see launcherLogoIconGlyph()
    property bool   weatherImperial: false   // false = °C / km·h, true = °F / mph
    property bool   clock12h:        false   // false = 24h, true = 12h (AM/PM)

    // ── widget/workspace state persistence ──
    readonly property string widgetsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_widgets"

    property var widgetColorStyles: ({})
    property bool _widgetColorsLoaded: false

    function widgetGidValid(gid) {
        var m = String(gid || "").match(/^G(\d{1,2})$/)
        if (!m) return false
        var n = Number(m[1])
        return n >= 1 && n <= 18
    }
    function widgetColorModeValid(mode) {
        return mode === "fill" || mode === "border" || mode === "both"
    }
    function normalizedWidgetColorMode(mode, colorId) {
        var borderOn = mode === "both" || mode === "border"
        if (!borderOn) return "fill"
        return colorId === "inherit" ? "border" : "both"
    }
    function widgetToneValid(tone) {
        return tone === "auto" || tone === "background" || tone === "foreground"
    }
    function widgetColorStyle(gid) {
        var raw = widgetColorStyles[gid]
        var colorId = raw && (raw.color === "inherit" || paletteColorValid(raw.color))
            ? raw.color : "inherit"
        return {
            color: colorId,
            mode: raw && widgetColorModeValid(raw.mode)
                ? normalizedWidgetColorMode(raw.mode, colorId) : "fill",
            tone: raw && widgetToneValid(raw.tone) ? raw.tone : "auto"
        }
    }
    function setWidgetColorStyle(gid, colorId, mode, tone) {
        if (!widgetGidValid(gid)) return
        var next = {}
        for (var key in widgetColorStyles) next[key] = widgetColorStyles[key]
        var storedColor = colorId === "inherit"
            ? "inherit" : (paletteColorValid(colorId) ? colorId : "color01")
        var storedMode = normalizedWidgetColorMode(mode, storedColor)
        if (storedColor === "inherit" && storedMode !== "border") delete next[gid]
        else next[gid] = {
            color: storedColor,
            mode: storedMode,
            tone: widgetToneValid(tone) ? tone : "auto"
        }
        widgetColorStyles = next
        if (_widgetColorsLoaded) saveWidgetColors()
    }
    function setWidgetPaletteColor(gid, colorId) {
        var s = widgetColorStyle(gid); setWidgetColorStyle(gid, colorId, s.mode, s.tone)
    }
    function setWidgetColorMode(gid, mode) {
        var s = widgetColorStyle(gid); setWidgetColorStyle(gid, s.color, mode, s.tone)
    }
    function setWidgetBorderEnabled(gid, enabled) {
        var s = widgetColorStyle(gid)
        setWidgetColorStyle(gid, s.color,
            enabled ? (s.color === "inherit" ? "border" : "both") : "fill", s.tone)
    }
    function setWidgetTone(gid, tone) {
        var s = widgetColorStyle(gid)
        if (s.color !== "inherit") setWidgetColorStyle(gid, s.color, s.mode, tone)
    }
    function resetWidgetColor(gid) {
        var s = widgetColorStyle(gid)
        setWidgetColorStyle(gid, "inherit",
            s.mode === "both" || s.mode === "border" ? "border" : "fill", "auto")
    }
    function resetAllWidgetColors() {
        widgetColorStyles = ({})
        if (_widgetColorsLoaded) saveWidgetColors()
    }
    function widgetPaletteId(gid) { return widgetColorStyle(gid).color }
    function widgetColorMode(gid) { return widgetColorStyle(gid).mode }
    function widgetTone(gid) { return widgetColorStyle(gid).tone }
    function widgetHasFill(gid) { return widgetColorStyle(gid).color !== "inherit" }
    function widgetHasBorder(gid) {
        var m = widgetColorStyle(gid).mode
        return m === "border" || m === "both"
    }
    function widgetAssignedColor(gid) {
        var id = widgetPaletteId(gid)
        return id === "inherit" ? seal : paletteColor(id)
    }
    function widgetContrastColor(gid) {
        var fill = widgetAssignedColor(gid)
        var tone = widgetTone(gid)
        if (tone === "background") return paper
        if (tone === "foreground") return ink
        return _contrastRatio(fill, paper) >= _contrastRatio(fill, ink) ? paper : ink
    }
    function widgetContentColor(gid, fallback) {
        return widgetHasFill(gid) ? widgetContrastColor(gid) : fallback
    }
    function widgetFillColor(gid) {
        return widgetHasFill(gid) ? widgetAssignedColor(gid) : pill
    }
    function widgetBorderColor(gid) {
        return widgetHasBorder(gid) ? panelBorder : pillBorder
    }
    function widgetBorderWidth(gid) {
        return widgetHasBorder(gid) ? Math.max(1, pillBorderW) : pillBorderW
    }
    function serializeWidgetColorStyles() {
        var out = []
        for (var n = 1; n <= 18; n++) {
            var gid = "G" + n
            var s = widgetColorStyle(gid)
            if (s.color !== "inherit" || s.mode === "border")
                out.push(gid + "~" + s.color + "~" + s.mode + "~" + s.tone)
        }
        return out.length ? out.join(",") : "-"
    }
    function parseWidgetColorStyles(raw) {
        var out = {}
        if (!raw || raw === "-") return out
        var entries = String(raw).split(",")
        for (var i = 0; i < entries.length; i++) {
            var f = entries[i].split("~")
            if (f.length !== 4 || !widgetGidValid(f[0])
                    || (f[1] !== "inherit" && !paletteColorValid(f[1]))
                    || !widgetColorModeValid(f[2]) || !widgetToneValid(f[3])) continue
            out[f[0]] = { color: f[1], mode: normalizedWidgetColorMode(f[2], f[1]), tone: f[3] }
        }
        return out
    }

    readonly property string widgetColorsCachePath:
        Quickshell.env("HOME") + "/.cache/quickshell_widget_colors"

    function saveWidgetColors() { scheduleSettingsSave() }


    Process {
        id: widgetColorLoadProc
        running: false
        command: ["cat", theme.widgetColorsCachePath]
        stdout: StdioCollector {
            onStreamFinished: {
                theme.widgetColorStyles =
                    theme.parseWidgetColorStyles(String(this.text || "").trim())
                theme._widgetColorsLoaded = true
                theme._finishLegacyMigration()
            }
        }
        onExited: { theme._widgetColorsLoaded = true; theme._finishLegacyMigration() }
    }
    property bool _widgetsLoaded: false
    property bool _compactResetting: false


    function saveWidgets() { scheduleSettingsSave() }

    readonly property var launcherLogoTextOptions: ["nixos", "hyprland"]
    readonly property var launcherLogoIconOptions: ["dots", "hyprland", "arch", "grid", "spark", "power", "dragon", "mark", "nix", "branch", "rebel"]

    function launcherLogoTextIndex(id) {
        for (var i = 0; i < launcherLogoTextOptions.length; i++)
            if (launcherLogoTextOptions[i] === id) return i
        return 0
    }
    function launcherLogoIconIndex(id) {
        for (var i = 0; i < launcherLogoIconOptions.length; i++)
            if (launcherLogoIconOptions[i] === id) return i
        return 0
    }
    function launcherLogoTextValid(id) {
        return launcherLogoTextIndex(id) >= 0 && launcherLogoTextOptions[launcherLogoTextIndex(id)] === id
    }
    function launcherLogoIconValid(id) {
        return launcherLogoIconIndex(id) >= 0 && launcherLogoIconOptions[launcherLogoIconIndex(id)] === id
    }
    function nextLauncherLogoText() {
        launcherLogoText = launcherLogoTextOptions[(launcherLogoTextIndex(launcherLogoText) + 1) % launcherLogoTextOptions.length]
    }
    function nextLauncherLogoIcon() {
        launcherLogoIcon = launcherLogoIconOptions[(launcherLogoIconIndex(launcherLogoIcon) + 1) % launcherLogoIconOptions.length]
    }
    function launcherConfigValue(config, a, b, c) {
        if (!config) return undefined
        if (config[a] !== undefined) return config[a]
        if (b && config[b] !== undefined) return config[b]
        if (c && config[c] !== undefined) return config[c]
        return undefined
    }
    function applyLauncherConfig(config) {
        if (!config) return

        var launcher = config.launcher || config.logo || config
        var mode = launcherConfigValue(launcher, "launcherLogoMode", "logoMode", "mode")
        var text = launcherConfigValue(launcher, "launcherLogoText", "textLogo", "text")
        var icon = launcherConfigValue(launcher, "launcherLogoIcon", "iconLogo", "icon")

        if (mode === "text" || mode === "icon") launcherLogoMode = mode
        if (text !== undefined && launcherLogoTextValid(text)) launcherLogoText = text
        if (icon !== undefined && launcherLogoIconValid(icon)) launcherLogoIcon = icon
    }
    function launcherLogoLabel(id) {
        if (id === "dots") return "NixOS"
        if (id === "hyprland") return "Hyprland"
        if (id === "arch") return "Arch"
        if (id === "omacom") return "Omacom"
        if (id === "grid") return "Grid"
        if (id === "spark") return "Spark"
        if (id === "power") return "Power"
        if (id === "dragon") return "Dragon"
        if (id === "mark") return "Mark"
        if (id === "nix") return "Nix"
        if (id === "branch") return "Branch"
        if (id === "rebel") return "Rebel"
        return "NixOS"
    }
    function launcherLogoIconGlyph(id) {
        if (id === "dots") return String.fromCodePoint(0xE900)
        if (id === "hyprland") return ""
        if (id === "arch") return ""
        if (id === "grid") return ""
        if (id === "spark") return ""
        if (id === "power") return ""
        if (id === "dragon") return "⻯"
        if (id === "mark") return ""
        if (id === "nix") return String.fromCodePoint(0xF313)
        if (id === "branch") return ""
        if (id === "rebel") return ""
        return String.fromCodePoint(0xE900)
    }
    function launcherLogoIconFont(id) {
        return id === "dots" ? "dots" : mono
    }
    function launcherLogoIconSize(id) {
        if (id === "dots") return 15
        if (id === "arch") return 17
        if (id === "dragon") return 16
        if (id === "nix") return 17
        return 16
    }
    function launcherLogoIconXOffset(id) {
        if (id === "dots") return 0.5
        if (id === "hyprland") return 0
        if (id === "arch") return 1
        if (id === "grid") return -1
        if (id === "spark") return 0
        if (id === "power") return 0
        if (id === "dragon") return 0
        if (id === "mark") return 0.5
        if (id === "nix") return 0
        if (id === "branch") return 0
        return 0
    }
    function launcherLogoIconYOffset(id) {
        if (id === "dots") return 0
        if (id === "hyprland") return 0
        if (id === "arch") return 0
        if (id === "mark") return 0.5
        if (id === "branch") return 0
        if (id === "dragon") return 0
        return 0
    }

    Process {
        id: widgetLoadProc
        command: ["cat", theme.widgetsCachePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(" ")
                if (parts.length >= 4) {
                    theme.modMemory    = parts[0] !== "0"
                    theme.modBrightness = parts[1] !== "0"
                    theme.modAi        = parts[2] !== "0"
                    theme.modPower     = parts[3] !== "0"
                }
                // parts[4] is the bluetooth flag in the new format, but in the OLD
                // format it was the workspace mode ("10"/"5"/"active") — detect which.
                var wsField = -1
                if (parts.length >= 5) {
                    if (parts[4] === "5" || parts[4] === "active" || parts[4] === "10") {
                        wsField = 4                         // old format: no bluetooth field
                    } else {
                        theme.modBluetooth = parts[4] !== "0"
                        wsField = 5
                    }
                }
                if (wsField >= 0 && parts.length > wsField) {
                    var m = parts[wsField]
                    theme.workspaceMode = (m === "5" || m === "active") ? m : "10"
                    // pickerStyle is the field right after the workspace mode
                    if (parts.length > wsField + 1) {
                        var ps = parts[wsField + 1]
                        if (ps === "hearthstone" || ps === "carousel" || ps === "tanzaku")
                            theme.pickerStyle = ps
                    }
                    // weatherImperial / clock12h follow pickerStyle
                    if (parts.length > wsField + 2) theme.weatherImperial = parts[wsField + 2] === "1"
                    if (parts.length > wsField + 3) theme.clock12h        = parts[wsField + 3] === "1"
                    if (parts.length > wsField + 4) theme.modNetwork      = parts[wsField + 4] === "1"
                    // style tokens — appended after modNetwork, each guarded
                    if (parts.length > wsField + 5) theme.styleShadow      = parts[wsField + 5] === "1"
                    if (parts.length > wsField + 6) theme.styleRadiusSmall = parts[wsField + 6] === "1"
                    // field wsField+7 (styleHeightMin) is reserved for offset
                    // stability only — the Height toggle was removed (plan §1.4), so
                    // it is intentionally NOT parsed: a stray "1" must not shrink pills
                    // when there is no UI to undo it. (saveWidgets still writes "0".)
                    if (parts.length > wsField + 8) {
                        var wss = parts[wsField + 8]
                        if (["default", "numbers", "magic", "comet", "segments", "occupancy", "icons", "kanji"].indexOf(wss) >= 0)
                            theme.workspaceStyle = wss
                    }
                    if (parts.length > wsField + 9) {
                        var bp = parts[wsField + 9]
                        if (bp === "top" || bp === "bottom") theme.barPosition = bp
                    }
                    // +10 styleBorder (independent border on/off). Old caches lack it →
                    // migrate from the old coupled meaning: border = NOT shadow.
                    // Default-true → parse "!== 0" so a corrupted token keeps borders ON.
                    if (parts.length > wsField + 10) theme.styleBorder = parts[wsField + 10] !== "0"
                    else if (parts.length > wsField + 5) theme.styleBorder = !theme.styleShadow
                    // +11..+15 widget-group toggles (default ON → only an explicit "0"
                    // hides; old caches lack these fields → groups stay visible)
                    if (parts.length > wsField + 11) theme.modStatus = parts[wsField + 11] !== "0"
                    if (parts.length > wsField + 12) theme.modQuick  = parts[wsField + 12] !== "0"
                    if (parts.length > wsField + 13) theme.modCpu    = parts[wsField + 13] !== "0"
                    if (parts.length > wsField + 14) theme.modVolume = parts[wsField + 14] !== "0"
                    if (parts.length > wsField + 15) theme.modMpris  = parts[wsField + 15] !== "0"
                    if (parts.length > wsField + 16) {
                        var at = parts[wsField + 16]
                        if (at === "codex" || at === "opencode") theme.aiTool = at
                    }
                    if (parts.length > wsField + 17) theme.styleFrost = parts[wsField + 17] === "1"
                    if (parts.length > wsField + 18) {
                        var lm = parts[wsField + 18]
                        if (lm === "text" || lm === "icon") {
                            theme.launcherLogoMode = lm
                            if (parts.length > wsField + 19 && theme.launcherLogoTextValid(parts[wsField + 19]))
                                theme.launcherLogoText = parts[wsField + 19]
                            if (parts.length > wsField + 20 && theme.launcherLogoIconValid(parts[wsField + 20]))
                                theme.launcherLogoIcon = parts[wsField + 20]
                        } else if (lm === "dots" || lm === "hyprland") {
                            // Legacy cache field from the first text-logo picker.
                            theme.launcherLogoMode = "text"
                            theme.launcherLogoText = lm
                        }
                    }
                    if (parts.length > wsField + 21) theme.archBadgePackages = parts[wsField + 21] !== "0"
                    if (parts.length > wsField + 22) theme.archBadgeThemes   = parts[wsField + 22] !== "0"
                    if (parts.length > wsField + 23) theme.compactNetwork    = parts[wsField + 23] === "1"
                    if (parts.length > wsField + 24) theme.compactBattery    = parts[wsField + 24] === "1"
                    if (parts.length > wsField + 25) theme.compactBrightness = parts[wsField + 25] === "1"
                    if (parts.length > wsField + 26) theme.compactCpu        = parts[wsField + 26] === "1"
                    if (parts.length > wsField + 27) theme.compactMemory     = parts[wsField + 27] === "1"
                    if (parts.length > wsField + 28) theme.compactVolume     = parts[wsField + 28] === "1"
                    if (parts.length > wsField + 29) theme.compactBluetooth  = parts[wsField + 29] === "1"
                    if (parts.length > wsField + 30) theme.compactPower      = parts[wsField + 30] === "1"
                    if (parts.length > wsField + 31) theme.archBadgeShell    = parts[wsField + 31] !== "0"
                    if (parts.length > wsField + 32) theme.compactMpris      = parts[wsField + 32] === "1"
                    if (parts.length > wsField + 33) theme.modGithub         = parts[wsField + 33] !== "0"
                    if (parts.length > wsField + 34) theme.motionHover       = parts[wsField + 34] !== "0"
                    if (parts.length > wsField + 35) theme.motionSweep       = parts[wsField + 35] !== "0"
                    if (parts.length > wsField + 36) theme.motionDigits      = parts[wsField + 36] !== "0"
                    if (parts.length > wsField + 37) theme.styleIconLabels   = parts[wsField + 37] === "1"
                    if (parts.length > wsField + 38) theme.styleDepth        = parts[wsField + 38] !== "0"
                }
                theme._widgetsLoaded = true
                theme._finishLegacyMigration()
            }
        }
    }


    // ── Settings: ~/.local/state/dots/shell/settings.json ──
    // One JSON object keyed by property name, validated per key on load (a bad or
    // unknown value keeps the default). Every key's change signal schedules a
    // save, so a new setting only needs a schema entry. The positional caches in
    // ~/.cache (quickshell_widgets / _splits / _widget_colors) are read once to
    // migrate when settings.json does not exist yet, then left alone.
    readonly property string settingsPath: Quickshell.env("HOME") + "/.local/state/dots/shell/settings.json"
    property bool _settingsReady: false
    readonly property var _settingsSchema: ({
        modStatus: "bool", modQuick: "bool", modMemory: "bool", modCpu: "bool",
        modVolume: "bool", modMpris: "bool", modBrightness: "bool", modAi: "bool",
        modPower: "bool", modBluetooth: "bool", modNetwork: "bool", modGithub: "bool",
        modGpu: "bool", modWeather: "bool", modStorage: "bool", modCpuTemperature: "bool",
        compactNetwork: "bool", compactBattery: "bool", compactBrightness: "bool",
        compactCpu: "bool", compactMemory: "bool", compactVolume: "bool",
        compactBluetooth: "bool", compactPower: "bool", compactMpris: "bool",
        archBadgePackages: "bool", archBadgeThemes: "bool", archBadgeShell: "bool",
        styleBorder: "bool", styleShadow: "bool", styleFrost: "bool",
        styleRadiusSmall: "bool", styleIconLabels: "bool", styleDepth: "bool",
        styleFrame: "bool", styleFrameEdge: "bool", styleAutoHide: "bool", styleDeskClock: "bool", styleDeskVisualiser: "bool",
        motionHover: "bool", motionSweep: "bool", motionDigits: "bool",
        weatherImperial: "bool", clock12h: "bool",
        splitArch: "bool", splitMon: "bool", splitMprisL: "bool", splitNet: "bool",
        workspaceMode: ["10", "5", "active"],
        workspaceStyle: ["default", "numbers", "magic", "comet", "segments", "occupancy", "icons", "kanji"],
        pickerStyle: ["hearthstone", "carousel", "tanzaku"],
        barPosition: ["top", "bottom"],
        barMonitor: function (v) { return typeof v === "string" && v !== "" },
        aiTool: ["codex", "opencode"],
        launcherLogoMode: ["text", "icon"],
        launcherLogoText: function (v) { return theme.launcherLogoTextValid(v) },
        launcherLogoIcon: function (v) { return theme.launcherLogoIconValid(v) },
        barAnim: function (v) { return Number.isInteger(v) && v >= 0 && v <= 14 },
        barColor: function (v) { return typeof v === "string" && theme.barColorValid(v) },
        widgetColorStyles: "widgetColors"
    })

    function _settingValid(rule, v) {
        if (rule === "bool") return typeof v === "boolean"
        if (Array.isArray(rule)) return rule.indexOf(v) >= 0
        if (typeof rule === "function") return rule(v)
        return false
    }
    function _widgetColorsFromJson(obj) {
        // reuse the legacy validator: rebuild its gid~color~mode~tone entries
        var parts = []
        for (var gid in obj) {
            var e = obj[gid] || {}
            parts.push([gid, e.color, e.mode, e.tone].join("~"))
        }
        return parseWidgetColorStyles(parts.length ? parts.join(",") : "-")
    }
    function applySettings(obj) {
        if (!obj || typeof obj !== "object") return
        for (var key in _settingsSchema) {
            if (!(key in obj)) continue
            var rule = _settingsSchema[key], v = obj[key]
            if (rule === "widgetColors") {
                if (v && typeof v === "object") widgetColorStyles = _widgetColorsFromJson(v)
            } else if (_settingValid(rule, v)) {
                theme[key] = key === "barColor" ? normalizedPaletteId(v) : v
            } else {
                console.warn("[settings] ignoring invalid " + key + ": " + JSON.stringify(v))
            }
        }
    }
    function settingsSnapshot() {
        var out = { version: 1 }
        for (var key in _settingsSchema) {
            if (_settingsSchema[key] === "widgetColors") {
                var colors = {}
                for (var gid in widgetColorStyles) colors[gid] = widgetColorStyles[gid]
                out[key] = colors
            } else {
                out[key] = theme[key]
            }
        }
        return out
    }
    function scheduleSettingsSave() {
        if (_settingsReady) settingsSaveDebounce.restart()
    }
    function _markSettingsReady() {
        _widgetsLoaded = true
        _splitsLoaded = true
        _widgetColorsLoaded = true
        _settingsReady = true
    }
    function _finishLegacyMigration() {
        if (_settingsReady || !_widgetsLoaded || !_splitsLoaded || !_widgetColorsLoaded) return
        _markSettingsReady()
        settingsSaveDebounce.restart()   // write settings.json once from the migrated values
    }

    Timer {
        id: settingsSaveDebounce
        interval: 150
        onTriggered: settingsFile.setText(JSON.stringify(theme.settingsSnapshot(), null, 2) + "\n")
    }

    FileView {
        id: settingsFile
        path: theme.settingsPath
        atomicWrites: true
        printErrors: false
        onLoaded: {
            var obj = null
            try { obj = JSON.parse(settingsFile.text()) } catch (e) {
                console.warn("[settings] " + theme.settingsPath + " is not valid JSON; using defaults")
            }
            theme.applySettings(obj)
            theme._markSettingsReady()
        }
        onLoadFailed: function (error) {
            // no settings.json yet: migrate from the legacy positional caches
            splitLoadProc.running = true
            widgetLoadProc.running = true
            widgetColorLoadProc.running = true
        }
        onSaveFailed: function (error) {
            console.warn("[settings] could not write " + theme.settingsPath + ": " + error)
        }
    }

    Component.onCompleted: {
        for (var key in _settingsSchema) {
            var sig = theme[key + "Changed"]
            if (sig) sig.connect(theme.scheduleSettingsSave)
            else console.warn("[settings] schema key without a property: " + key)
        }
    }

    // ── New widget panel states ──
    property bool networkVisible:   false
    onNetworkVisibleChanged: popupOpened("networkVisible")
    property bool bluetoothVisible: false
    onBluetoothVisibleChanged: popupOpened("bluetoothVisible")
    property bool batteryVisible:   false
    onBatteryVisibleChanged: popupOpened("batteryVisible")
    property bool brightnessVisible: false
    onBrightnessVisibleChanged: popupOpened("brightnessVisible")
    property bool mprisVisible:     false
    onMprisVisibleChanged: popupOpened("mprisVisible")
    property bool weatherVisible:   false
    onWeatherVisibleChanged: popupOpened("weatherVisible")
    property bool keybindsVisible:  false
    onKeybindsVisibleChanged: popupOpened("keybindsVisible")
    property bool workspaceVisible: false
    onWorkspaceVisibleChanged: popupOpened("workspaceVisible")

    // ── Image picker state (theme/wallpaper carousel) ──
    property bool   imagePickerVisible:  false
    onImagePickerVisibleChanged: popupOpened("imagePickerVisible")
    property string imagePickerMode:     "wallpaper"   // "theme" or "wallpaper"
    property real   quickActionsBarX:    0
    // ── Media browser state (screenshots/videos carousel) ──
    property bool   mediaBrowserVisible: false
    onMediaBrowserVisibleChanged: popupOpened("mediaBrowserVisible")
    property string mediaBrowserMode:    "screenshots"  // "screenshots" or "videos"
    // ── Idle inhibitor (Wayland idle-inhibit protocol) ──
    property bool   idleInhibited:       false
    // ── Notification state ──
    property bool notifVisible: false
    onNotifVisibleChanged: {
        if (!notifVisible) notifHoverOpened = false
        popupOpened("notifVisible")
    }
    property int  notifCount:   0
    property real notifBarX:    0

    // ── Power Profile state ──
    property bool powerProfileVisible: false
    onPowerProfileVisibleChanged: popupOpened("powerProfileVisible")
    property string powerProfileCurrent: ""

    Process {
        id: initPowerProfile
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p) theme.powerProfileCurrent = p
            }
        }
    }

    // ── Hyprland workspace dispatch (config-mode-aware) ──
    // Hyprland 0.55 added Lua configs but still supports classic hyprlang, and
    // BOTH ship the same version number — so the dispatch form depends on which
    // config is ACTIVE, not the version: classic wants "workspace N", Lua wants
    // hl.dsp.focus({ workspace = N }). Probe the mode once: `hyprctl eval` runs
    // Lua and answers "ok" only under a Lua config (classic has no eval). An
    // invalid dispatch would also tell them apart, but it lands in Hyprland's
    // config-error list on every bar start.
    property bool hyprUsesLua: false
    Process {
        id: hyprDispatchProbe
        command: ["bash", "-c", "[ \"$(hyprctl eval 'return 1' 2>&1)\" = ok ] && echo lua || echo classic"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { theme.hyprUsesLua = (this.text.trim() === "lua") }
        }
    }
    property bool openRouterVisible: false
    onOpenRouterVisibleChanged: popupOpened("openRouterVisible")

    property bool overviewVisible: false
    onOverviewVisibleChanged: popupOpened("overviewVisible")

    function gotoWorkspace(id) {
        if (hyprUsesLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        else
            Hyprland.dispatch("workspace " + id)
    }

    // Positions 21, 22 and 31 of the widget cache line (saveWidgets) belonged to
    // the Arch updater's bar badges. Nothing reads them now; they stay so the
    // fields after them keep their indices.
    property bool   archBadgePackages: true
    property bool   archBadgeThemes: true
    property bool   archBadgeShell: true

    // ── Tray state ──
    property bool trayVisible: false
    onTrayVisibleChanged: popupOpened("trayVisible")
    property var trayPinned: []
    property real trayBarX: 10

    // ── slot-aware panel X anchors (center-X of each group; set by BarSlot) ──
    property real volumeBarX:     0
    property real languageBarX:   0
    property real networkBarX:    0
    property real batteryBarX:    0
    property real memoryBarX:     0
    property real cpuBarX:        0
    property real aiBarX:         0
    property real githubBarX:     0
    property real workspaceBarX:  0
    property real bluetoothBarX:  0
    property real brightnessBarX: 0
    property real powerBarX:      0
    property real mprisBarX:      0
    property real weatherBarX:    0
    property real launcherBarX:   6   // ControlPanel follows the Launcher/Control group
    property real calendarBarX:   0
    property real gpuBarX:        0
    property real thermalBarX:    0
    property real storageBarX:    0

    // ── Tray context-menu state (themed menu, rendered by TrayMenu.qml) ──
    property bool trayMenuVisible: false
    onTrayMenuVisibleChanged: popupOpened("trayMenuVisible")
    property var  trayMenuHandle: null   // the QsMenuHandle of the clicked item
    property real trayMenuX: 0           // global x to anchor the menu under the icon
    property string trayMenuTitle: ""
    property string trayMenuIcon: ""

    function trayDisplayName(item) {
        if (!item) return "Tray App"

        var title = String(item.title || "").trim()
        if (title !== "") return title

        var tooltipTitle = String(item.tooltipTitle || "").trim()
        if (tooltipTitle !== "") return tooltipTitle

        var fallback = String(item.id || "").trim()
        var slash = fallback.lastIndexOf("/")
        if (slash >= 0 && slash < fallback.length - 1)
            fallback = fallback.substring(slash + 1)
        fallback = fallback.replace(/^org\.(kde|ayatana|freedesktop)\./i, "")
                           .replace(/[_-]+/g, " ")
        return fallback !== "" ? fallback : "Tray App"
    }

    function trayDescription(item, displayName) {
        if (!item) return ""

        var description = String(item.tooltipDescription || "").trim()
        var tooltipTitle = String(item.tooltipTitle || "").trim()
        var name = String(displayName || "").trim().toLowerCase()
        if (description !== "" && description.toLowerCase() !== name)
            return description
        if (tooltipTitle !== "" && tooltipTitle.toLowerCase() !== name)
            return tooltipTitle
        return ""
    }

    function openTrayMenu(handle, x, title, icon) {
        if (!handle) return
        trayMenuHandle = handle
        trayMenuTitle = String(title || "App Menu")
        trayMenuIcon = String(icon || "")
        setPanelAnchor("trayMenu", x)
        trayMenuVisible = true
    }

    function trayIsHidden(item) {
        return trayPinned.indexOf(item.id) < 0
    }

    // toggle: hidden items get pinned (shown in bar); pinned items get unpinned (back to panel)
    function trayToggleHide(item) {
        var key = item.id
        if (!key) return
        var i = trayPinned.indexOf(key)
        if (i >= 0) {
            var a = trayPinned.slice(0, i)
            var b = trayPinned.slice(i + 1)
            trayPinned = a.concat(b)
            trayVisible = false
        } else {
            trayPinned = trayPinned.concat([key])
        }
    }

    Process {
        id: dotsStateRootProbe
        command: ["bash", "-c",
            "state=\"$HOME/.local/state/dots/current\"; legacy=\"$HOME/.local/state/dots/shell/current\"; " +
            "if command -v dots-shell >/dev/null 2>&1 && [ -d \"$state\" ] && [ -d /usr/share/dots ]; then printf '%s\\t%s\\n' \"$state\" /usr/share/dots; " +
            "elif [ -d \"$legacy\" ]; then printf '%s\\t%s\\n' \"$legacy\" \"${DOTS_SHELL_PATH:-$HOME/dots/config/quickshell/rise}\"; " +
            "else printf '%s\\t%s\\n' \"$legacy\" \"${DOTS_SHELL_PATH:-$HOME/dots/config/quickshell/rise}\"; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                var resolved = parts.length > 0 ? parts[0] : ""
                var installRoot = parts.length > 1 ? parts[1] : ""
                if (resolved) theme.dotsStateRoot = resolved
                if (installRoot) theme.dotsShellRoot = installRoot
                theme.dotsStateRootResolved = true
                currentThemeNameWatcher.reload()
                theme.reloadCurrentThemeFiles()
            }
        }
    }

    Timer {
        id: themeReloadDebounce
        interval: 40
        repeat: false
        onTriggered: {
            paletteReader.running = false
            paletteReader.running = true
        }
    }

    // NixOS writes theme.name immediately after the complete theme directory
    // swap, before its slower application retint commands and final hooks.
    FileView {
        id: currentThemeNameWatcher
        path: theme.themeNamePath
        watchChanges: theme.dotsStateRootResolved
        printErrors: false
        onLoaded: {
            theme.setCurrentThemeName(currentThemeNameWatcher.text())
            theme.reloadCurrentThemeFiles()
        }
        onLoadFailed: theme.setCurrentThemeName("")
        onFileChanged: {
            reload()
            theme.reloadCurrentThemeFiles()
        }
    }

    Process {
        id: paletteReader
        command: ["cat", theme.colorsPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                Palette.apply(theme, Palette.parse(this.text));
            }
        }
    }

    function ipcApplyTheme(payload) {
        let p;
        try { p = JSON.parse(payload); }
        catch (e) { console.warn("theme.apply: bad payload —", e); return; }
        if (!p || !p.colors) return;
        Palette.apply(theme, Palette.mapKeys(p.colors));
        theme.lastAppliedName = p.name || "";
    }

    function ipcApplyLauncher(payload) {
        let p;
        try { p = JSON.parse(payload); }
        catch (e) { console.warn("theme.applyLauncher: bad payload —", e); return; }
        theme.applyLauncherConfig(p);
    }

    function ipcReloadTheme() {
        paletteReader.running = false;
        paletteReader.running = true;
    }

    function ipcOpenPicker(mode) {
        if (mode === "theme" || mode === "wallpaper") openImagePicker(mode)
        else if (mode === "screenshots" || mode === "videos") openMediaBrowser(mode)
    }

    // Standalone compatibility while the integrated bootstrap is being rolled
    // out. VariantRoot supplies variantHost, so only the common IPC router owns
    // these targets in integrated mode.
    LazyLoader {
        active: theme.variantHost === null
        IpcHandler {
            target: "theme"
            function apply(payload: string): void { theme.ipcApplyTheme(payload) }
            function applyLauncher(payload: string): void { theme.ipcApplyLauncher(payload) }
            function reload(): void { theme.ipcReloadTheme() }
        }
    }

    LazyLoader {
        active: theme.variantHost === null
        IpcHandler {
            target: "picker"
            function theme(): void { ipcOpenPicker("theme") }
            function wallpaper(): void { ipcOpenPicker("wallpaper") }
            function screenshots(): void { ipcOpenPicker("screenshots") }
            function videos(): void { ipcOpenPicker("videos") }
        }
    }
}
