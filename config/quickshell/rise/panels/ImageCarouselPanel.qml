import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import "ImagePickerModel.js" as Model

// Tanzaku filmstrip picker for theme & wallpaper.
// sumi-e language: lots of empty space (ma), the focused image centred & full,
// the rest as thin desaturated paper strips (tanzaku), and ONE seal brush-stroke
// gliding under the focus as the single confident accent line.
PanelWindow {
    id: panel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dots-image-carousel"
    WlrLayershell.keyboardFocus: panel.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool active: root.pickerStyle === "tanzaku" || root.pickerStyle === ""   // default
    readonly property bool isThemeMode: root.imagePickerMode === "theme"
    readonly property bool ready: root.imagePickerVisible && active && imagesLoaded && layoutSettled

    property bool imagesLoaded:  false
    property bool layoutSettled: false
    property bool scanDone:      false   // a scan finished (distinguishes "loading" from "nothing found")
    property var  imageArray:    []
    property int  selFilt:       0
    property string filterText:  ""
    property string currentImage: ""
    property int thumbEpoch:      0
    property string readyThumbUrl: ""

    visible: root.imagePickerVisible && active

    // ── reveal (fade + subtle rise) ──
    property real reveal: 0
    Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    onReadyChanged: reveal = ready ? 1 : 0

    // ── filtered list (each entry keeps its original index) ──
    readonly property var filtered: {
        var out = [], arr = imageArray, ids = Model.matchList(arr, filterText)
        for (var k = 0; k < ids.length; k++) {
            var img = arr[ids[k]]
            out.push({
                idx:      ids[k],
                filePath: img.filePath,
                thumb:    panel.thumbUrlFor(img),
                label:    img.label,
                dir:      img.dir || "",
                current:  img.filePath === panel.currentImage
            })
        }
        return out
    }
    onFilteredChanged: if (selFilt >= filtered.length) selFilt = Math.max(0, filtered.length - 1)

    // ── windowed view ──
    readonly property int winRadius: maxVisible + 8
    readonly property int winCount:  Math.min(filtered.length, 2 * winRadius + 1)
    readonly property int winStart:  Math.max(0, Math.min(selFilt - winRadius, filtered.length - winCount))
    function absForSlot(slot) {
        var n = panel.winCount; if (n <= 0) return -1
        var s = panel.winStart
        return s + ((slot - s) % n + n) % n
    }


    readonly property string currentLabel:
        (filtered.length > 0 && selFilt >= 0 && selFilt < filtered.length)
            ? filtered[selFilt].label
            : (filterText ? "No matches" : "")
    function thumbUrlFor(img) {
        if (!img || !img.thumbnailPath || img.thumbnailPath === img.filePath) return ""
        return "file://" + img.thumbnailPath
    }

    // ── open / style gating ──
    function syncOpen() {
        if (root.imagePickerVisible && active) {
            if (!imagesLoaded) {
                panel.layoutSettled = false
                panel.filterText    = ""
                panel.imageArray    = []
                panel.selFilt       = 0
                panel.reveal        = 0
                currentProc.running = false; currentProc.running = true
            }
        } else {
            panel.imagesLoaded  = false; panel.scanDone = false
            panel.layoutSettled = false
            panel.reveal        = 0
        }
    }
    Connections {
        target: root
        function onImagePickerVisibleChanged() { panel.syncOpen() }
        function onPickerStyleChanged()         { panel.syncOpen() }
    }
    Component.onCompleted: panel.syncOpen()

    // step 1: current image
    Process {
        id: currentProc
        command: panel.isThemeMode
            ? ["bash", "-c",
               "CACHE=$HOME/.cache/quickshell-theme-picker; " +
               "name=$(cat " + panel.shq(root.themeNamePath) + " 2>/dev/null || true); " +
               "for ext in png jpg jpeg webp; do f=\"$CACHE/$name.$ext\"; [ -L \"$f\" ] && echo \"$f\" && exit 0; done; echo ''"]
            : ["bash", "-c", "readlink -f " + panel.shq(root.currentBackgroundPath) + " 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                panel.currentImage = this.text.trim()
                cacheProc.running = false; cacheProc.running = true   // instant from cache
                var cmd = panel.buildScanCmd()
                cmd[2] = cmd[2] + " | tee " + panel.shq(panel.scanCachePath)
                scanProc.command = cmd
                scanProc.running = false; scanProc.running = true
            }
        }
    }

    // step 2: scan images (live refresh; writes the cache via tee)
    Process {
        id: scanProc
        command: []
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: panel.applyScan(text, false)
        }
    }

    // scan-result cache → instant (re)open
    readonly property string scanCachePath: Quickshell.env("HOME") + "/.cache/quickshell-scan-" + (isThemeMode ? "theme" : "wallpaper")
    property string _lastScan: ""
    function scanHasOriginalThumbs(text) {
        var rows = String(text || "").split("\n")
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            if (!row) continue
            var cols = row.split("\t")
            if (cols.length < 2 || !cols[1] || cols[0] === cols[1]) return true
        }
        return false
    }
    Process {
        id: cacheProc
        command: ["cat", panel.scanCachePath]
        stdout: StdioCollector { onStreamFinished: panel.applyScan(this.text, true) }
    }
    function applyScan(text, fromCache) {
        var t = String(text || "")
        if (fromCache && !t.trim()) return   // cache empty → wait for live scan; live empty → fall through to empty-state
        if (fromCache && scanHasOriginalThumbs(t)) return
        if (fromCache && imagesLoaded) return
        if (!fromCache && t.trim() === _lastScan.trim() && imagesLoaded) { panel.warmVisible(); warmTimer.restart(); return }
        _lastScan = t
        var images = Model.loadRows(t)
        panel.imageArray   = images
        panel.selFilt      = Model.indexForSelectedImage(images, panel.currentImage)
        panel.imagesLoaded = images.length > 0; panel.scanDone = true
        Qt.callLater(function() {
            if (root.imagePickerVisible && panel.active) {
                panel.layoutSettled = true
                if (panel.imageArray.length > 0) stage.forceActiveFocus()   // keep Esc-catcher focused when empty
                panel.fetchMeta()
                if (!fromCache) { panel.warmMeta(); panel.warmVisible(); warmTimer.restart() }
            }
        })
    }

    function buildScanCmd() {
        if (isThemeMode) {
            return ["bash", "-c", "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\"; HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\"; TL=$(mktemp); TK=$(mktemp); TM=$(mktemp); TD=$(mktemp); TW=$(mktemp); trap 'rm -f \"$TL\" \"$TK\" \"$TM\" \"$TD\" \"$TW\" \"$TK.hit\" \"$TM.sha\"' EXIT; thumbs_for_list() { : > \"$TK.hit\"; [ -s \"$TL\" ] || return 0; paste \"$TL\" <(xargs -r -d '\\n' -a \"$TL\" readlink -f --) <(xargs -r -d '\\n' -a \"$TL\" stat -Lc '%s:%Y:%Z' --) > \"$TK\"; : > \"$TM\"; awk -F '\\t' -v HC=\"$HASHCACHE\" -v MISS=\"$TM\" 'BEGIN { while ((getline l < HC) > 0) { i = index(l, \"\\t\"); if (i) h[substr(l, 1, i-1)] = substr(l, i+1) } close(HC) } { k = $2 \"|\" $3; if (k in h) print $1 \"\\t\" h[k]; else print $1 \"\\t\" k > MISS }' \"$TK\" > \"$TK.hit\"; [ -s \"$TM\" ] || return 0; cut -f1 \"$TM\" | xargs -r -d '\\n' sha256sum -- 2>/dev/null | sed 's/^\\([0-9a-f]*\\)  /\\1\\t/' | awk -F '\\t' '{ s[$2] = $1 } END { for (p in s) print p \"\\t\" s[p] }' > \"$TM.sha\"; awk -F '\\t' 'NR == FNR { s[$1] = $2; next } ($1 in s) { print $2 \"\\t\" s[$1] }' \"$TM.sha\" \"$TM\" >> \"$HASHCACHE\"; awk -F '\\t' 'NR == FNR { s[$1] = $2; next } ($1 in s) { print $1 \"\\t\" s[$1] }' \"$TM.sha\" \"$TM\" >> \"$TK.hit\"; }; CACHE=$HOME/.cache/quickshell-theme-picker; mkdir -p \"$CACHE\"; shopt -s nullglob nocaseglob; : > \"$TL\"; : > \"$TD\"; for d in ~/dots/config/themes/*; do [ -d \"$d\" ] || continue; name=$(basename \"$d\"); prev=\"\"; for c in \"$d\"/preview.png \"$d\"/preview.jpg \"$d\"/preview.jpeg; do [ -f \"$c\" ] && { prev=\"$c\"; break; }; done; if [ -z \"$prev\" ]; then bgs=(\"$d\"/backgrounds/*.jpg \"$d\"/backgrounds/*.jpeg \"$d\"/backgrounds/*.png \"$d\"/backgrounds/*.webp); prev=\"${bgs[0]}\"; fi; [ -z \"$prev\" ] && continue; ext=\"${prev##*.}\"; link=\"$CACHE/$name.$ext\"; [ -L \"$link\" ] || ln -sf \"$prev\" \"$link\"; printf '%s\\n' \"$link\" >> \"$TL\"; printf '%s\\t%s\\n' \"$link\" \"$d\" >> \"$TD\"; done; thumbs_for_list; awk -F '\\t' -v D=\"$D\" 'NR == FNR { dir[$1] = $2; next } $2 != \"\" { print $1 \"\\t\" D \"/\" $2 \"-512.jpg\" \"\\t\" dir[$1] }' \"$TD\" \"$TK.hit\" | sort -u"]
        } else {
            return ["bash", "-c", "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\"; HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\"; TL=$(mktemp); TK=$(mktemp); TM=$(mktemp); TD=$(mktemp); TW=$(mktemp); trap 'rm -f \"$TL\" \"$TK\" \"$TM\" \"$TD\" \"$TW\" \"$TK.hit\" \"$TM.sha\"' EXIT; thumbs_for_list() { : > \"$TK.hit\"; [ -s \"$TL\" ] || return 0; paste \"$TL\" <(xargs -r -d '\\n' -a \"$TL\" readlink -f --) <(xargs -r -d '\\n' -a \"$TL\" stat -Lc '%s:%Y:%Z' --) > \"$TK\"; : > \"$TM\"; awk -F '\\t' -v HC=\"$HASHCACHE\" -v MISS=\"$TM\" 'BEGIN { while ((getline l < HC) > 0) { i = index(l, \"\\t\"); if (i) h[substr(l, 1, i-1)] = substr(l, i+1) } close(HC) } { k = $2 \"|\" $3; if (k in h) print $1 \"\\t\" h[k]; else print $1 \"\\t\" k > MISS }' \"$TK\" > \"$TK.hit\"; [ -s \"$TM\" ] || return 0; cut -f1 \"$TM\" | xargs -r -d '\\n' sha256sum -- 2>/dev/null | sed 's/^\\([0-9a-f]*\\)  /\\1\\t/' | awk -F '\\t' '{ s[$2] = $1 } END { for (p in s) print p \"\\t\" s[p] }' > \"$TM.sha\"; awk -F '\\t' 'NR == FNR { s[$1] = $2; next } ($1 in s) { print $2 \"\\t\" s[$1] }' \"$TM.sha\" \"$TM\" >> \"$HASHCACHE\"; awk -F '\\t' 'NR == FNR { s[$1] = $2; next } ($1 in s) { print $1 \"\\t\" s[$1] }' \"$TM.sha\" \"$TM\" >> \"$TK.hit\"; }; find -L " + wallpaperFindRoots() + " -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) 2>/dev/null | sort > \"$TL\"; thumbs_for_list; sort \"$TK.hit\" | awk -F '\\t' -v D=\"$D\" '$2 != \"\" { print $1 \"\\t\" D \"/\" $2 \"-512.jpg\" }'"]
        }
    }

    Process { id: applyThemeProc; command: [] }
    Process { id: applyBgProc;    command: [] }

    function applySelected() {
        if (!imagesLoaded || filtered.length === 0) return
        if (selFilt < 0 || selFilt >= filtered.length) return
        var path = filtered[selFilt].filePath; if (!path) return
        if (isThemeMode) {
            var name = Model.nameForPath(path)
            applyThemeProc.command = ["env", "DOTS_SHELL_PATH=" + root.dotsShellRoot, "dots-theme-set", name]
            applyThemeProc.running = false; applyThemeProc.running = true
        } else {
            applyBgProc.command = ["bash", "-c", "dots-theme-bg-set '" + path.replace(/'/g, "'\\''") + "'"]
            applyBgProc.running = false; applyBgProc.running = true
        }
        root.imagePickerVisible = false
    }

    function moveSel(delta) {
        if (filtered.length === 0) return
        selFilt = Math.max(0, Math.min(filtered.length - 1, selFilt + delta))
    }

    // the currently focused entry (or null)
    readonly property var sel: (filtered.length > 0 && selFilt >= 0 && selFilt < filtered.length)
                               ? filtered[selFilt] : null

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function wallpaperFindRoots() {
        var paths = root.wallpaperSourcePaths || []
        var args = []
        for (var i = 0; i < paths.length; i++)
            if (paths[i]) args.push(panel.shq(paths[i]))
        return args.join(" ")
    }
    function paletteReadCmd(pathExpr) {
        return "awk -F'\"' 'function valid(v){ return v ~ /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/ } { k=$1; gsub(/[[:space:]=]/,\"\",k); if (valid($2)) c[k]=$2 } END { split(\"color1 red color2 green color3 yellow color4 blue color5 magenta color6 cyan\", a, \" \"); for (i=1; i<=6; i++) { p=a[i*2-1]; q=a[i*2]; v=c[p]; if (v == \"\") v=c[q]; if (v != \"\") { if (out != \"\") out=out \",\"; out=out v } } print out }' " + pathExpr + " 2>/dev/null"
    }

    // ── pre-warm: visible entries first, the rest after the open settles. All
    // image pickers share the 512px cache family; Tanzaku lets sourceSize decode
    // the shared thumbnails down to its strip dimensions.
    Process {
        id: priorityWarmProc
        command: []
        stdout: SplitParser {
            onRead: function(line) { panel.noteThumbReady(line) }
        }
    }
    Process {
        id: warmProc
        command: []
        stdout: SplitParser {
            onRead: function(line) { panel.noteThumbReady(line) }
        }
    }
    Timer { id: warmTimer; interval: 450; onTriggered: panel.warmAll() }
    function noteThumbReady(line) {
        var path = String(line || "").trim()
        if (!path) return
        panel.readyThumbUrl = "file://" + path
        panel.thumbEpoch++
    }
    function warmCommand(srcs, niceLevel) {
        var nice = niceLevel === 10 ? 10 : 19
        return ["bash", "-c",
            "command -v magick >/dev/null 2>&1 || exit 0; D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\"; HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\"; TL=$(mktemp); TK=$(mktemp); TM=$(mktemp); TD=$(mktemp); TW=$(mktemp); trap 'rm -f \"$TL\" \"$TK\" \"$TM\" \"$TD\" \"$TW\" \"$TK.hit\" \"$TM.sha\"' EXIT; thumbs_for_list() { : > \"$TK.hit\"; [ -s \"$TL\" ] || return 0; paste \"$TL\" <(xargs -r -d '\\n' -a \"$TL\" readlink -f --) <(xargs -r -d '\\n' -a \"$TL\" stat -Lc '%s:%Y:%Z' --) > \"$TK\"; : > \"$TM\"; awk -F '\\t' -v HC=\"$HASHCACHE\" -v MISS=\"$TM\" 'BEGIN { while ((getline l < HC) > 0) { i = index(l, \"\\t\"); if (i) h[substr(l, 1, i-1)] = substr(l, i+1) } close(HC) } { k = $2 \"|\" $3; if (k in h) print $1 \"\\t\" h[k]; else print $1 \"\\t\" k > MISS }' \"$TK\" > \"$TK.hit\"; [ -s \"$TM\" ] || return 0; cut -f1 \"$TM\" | xargs -r -d '\\n' sha256sum -- 2>/dev/null | sed 's/^\\([0-9a-f]*\\)  /\\1\\t/' | awk -F '\\t' '{ s[$2] = $1 } END { for (p in s) print p \"\\t\" s[p] }' > \"$TM.sha\"; awk -F '\\t' 'NR == FNR { s[$1] = $2; next } ($1 in s) { print $2 \"\\t\" s[$1] }' \"$TM.sha\" \"$TM\" >> \"$HASHCACHE\"; awk -F '\\t' 'NR == FNR { s[$1] = $2; next } ($1 in s) { print $1 \"\\t\" s[$1] }' \"$TM.sha\" \"$TM\" >> \"$TK.hit\"; }; printf '%s\\n' \"$@\" > \"$TL\"; thumbs_for_list; while IFS=$'\\t' read -r s k; do [ -n \"$k\" ] || continue; o=\"$D/$k-512.jpg\"; [ -s \"$o\" ] || printf '%s\\n%s\\n' \"$s\" \"$o\" >> \"$TW\"; done < \"$TK.hit\"; if [ -s \"$TW\" ]; then nice -n " + nice + " xargs -d '\\n' -P 3 -n 2 sh -c 'magick -define jpeg:size=1024x1024 \"$0[0]\" -auto-orient -strip -thumbnail 512x512^ -quality 82 \"$1\" >/dev/null 2>&1 || true; [ -s \"$1\" ] && printf \"%s\\n\" \"$1\"; exit 0' < \"$TW\"; fi",
            "warm"].concat(srcs)
    }
    function startWarm(proc, srcs, niceLevel) {
        if (srcs.length === 0) return
        proc.command = panel.warmCommand(srcs, niceLevel)
        proc.running = false; proc.running = true
    }
    function visibleSourcePaths() {
        var srcs = [], seen = {}
        for (var distance = 0; distance <= maxVisible; distance++) {
            var indices = distance === 0 ? [selFilt] : [selFilt - distance, selFilt + distance]
            for (var j = 0; j < indices.length; j++) {
                var i = indices[j]
                if (i < 0 || i >= filtered.length) continue
                var p = filtered[i].filePath
                if (p && !seen[p]) { seen[p] = true; srcs.push(p) }
            }
        }
        return srcs
    }
    function backgroundSourcePaths() {
        var visible = {}, priority = visibleSourcePaths(), srcs = [], seen = {}
        for (var i = 0; i < priority.length; i++) visible[priority[i]] = true
        for (var j = 0; j < imageArray.length; j++) {
            var p = imageArray[j].filePath
            if (p && !visible[p] && !seen[p]) { seen[p] = true; srcs.push(p) }
        }
        return srcs
    }
    function warmVisible() { panel.startWarm(priorityWarmProc, panel.visibleSourcePaths(), 10) }
    function warmAll() { panel.startWarm(warmProc, panel.backgroundSourcePaths(), 19) }

    // ── lazy meta (author/repo/palette) for the FOCUSED theme only, cached by
    // dir — keeps the scan instant; enrichment lands ~110ms after the focus settles
    property var metaCache: ({})
    property string _metaDir: ""
    readonly property var selMeta: (sel && sel.dir && metaCache[sel.dir]) ? metaCache[sel.dir] : null

    Timer { id: metaTimer; interval: 60; onTriggered: panel.fetchMeta() }
    onSelChanged: if (isThemeMode && sel && sel.dir && !metaCache[sel.dir]) metaTimer.restart()

    function fetchMeta() {
        if (!isThemeMode || !sel || !sel.dir || metaCache[sel.dir]) return
        panel._metaDir = sel.dir
        metaProc.command = ["bash", "-c",
            "d=" + shq(sel.dir) + "; repo=''; author='';" +
            "if [ -f \"$d/.git/config\" ]; then " +
            "  repo=$(sed -nE 's#^[[:space:]]*url = (.*)$#\\1#p' \"$d/.git/config\" | head -1);" +
            "  author=$(printf '%s' \"$repo\" | sed -nE 's#.*github\\.com[:/]+([^/]+)/.*#\\1#p');" +
            "fi;" +
            "pal=$(" + paletteReadCmd("\"$d/colors.sh\"") + ");" +
            "printf '%s\\t%s\\t%s\\n' \"$author\" \"$repo\" \"$pal\""]
        metaProc.running = false; metaProc.running = true
    }
    Process {
        id: metaProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(this.text || "").replace(/\n+$/, "").split("\t")
                var m = panel.metaCache
                m[panel._metaDir] = { author: parts[0] || "", repo: parts[1] || "", palette: parts[2] || "" }
                panel.metaCache = m   // reassign → bindings refresh
            }
        }
    }

    function openRepo() {
        if (!selMeta || !selMeta.repo) return
        var url = String(selMeta.repo)
            .replace(/^git@github\.com:/, "https://github.com/")
            .replace(/\.git$/, "")
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", "--", "xdg-open", url])
    }

    // ── bulk meta pre-warm: author/repo/palette for ALL themes in one background
    // pass → info is instant for every theme (no lazy timing fragility) ──
    Process {
        id: metaWarmProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text || "").split("\n")
                var m = panel.metaCache
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue
                    var p = lines[i].split("\t")
                    if (p[0] && !m[p[0]]) m[p[0]] = { author: p[1] || "", repo: p[2] || "", palette: p[3] || "" }
                }
                panel.metaCache = m
            }
        }
    }
    function warmMeta() {
        if (!isThemeMode) return
        var dirs = []
        for (var i = 0; i < imageArray.length; i++)
            if (imageArray[i].dir) dirs.push(imageArray[i].dir)
        if (dirs.length === 0) return
        metaWarmProc.command = ["bash", "-c",
            "for d in \"$@\"; do repo=''; author='';" +
            "if [ -f \"$d/.git/config\" ]; then repo=$(sed -nE 's#^[[:space:]]*url = (.*)$#\\1#p' \"$d/.git/config\" | head -1);" +
            "author=$(printf '%s' \"$repo\" | sed -nE 's#.*github\\.com[:/]+([^/]+)/.*#\\1#p'); fi;" +
            "pal=$(" + paletteReadCmd("\"$d/colors.sh\"") + ");" +
            "printf '%s\\t%s\\t%s\\t%s\\n' \"$d\" \"$author\" \"$repo\" \"$pal\"; done",
            "warm"].concat(dirs)
        metaWarmProc.running = false; metaWarmProc.running = true
    }

    // ── geometry ──
    readonly property int  focusedW:   460
    readonly property int  focusedH:   259      // 16:9
    readonly property int  peekW:      104      // ONLY the immediate neighbour — preview peek
    readonly property int  stripW:     24       // every other strip — thin tanzaku (unchanged)
    readonly property int  gap:        8
    readonly property int  maxVisible: 5

    // only the first neighbour on each side widens for a preview; the rest stay thin
    function stripWidthFor(d) {
        if (d <= 0) return focusedW
        if (d === 1) return peekW
        return stripW
    }

    // ── colors (bar materials) ──
    readonly property color scrim:   Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.8)
    readonly property color frameBg: root.frameWeak
    readonly property color uiDim:   Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)

    // ── scrim ──
    Rectangle {
        anchors.fill: parent
        color: panel.scrim
        opacity: panel.reveal
    }
    MouseArea {
        anchors.fill: parent
        enabled: panel.visible
        onClicked: root.imagePickerVisible = false
        property real wheelAcc: 0
        onWheel: function(wheel) {
            if (!panel.ready) return
            var d = wheel.angleDelta.y
            if (d === 0) return
            if ((d > 0) !== (wheelAcc >= 0)) wheelAcc = 0
            wheelAcc += d
            while (wheelAcc >=  120) { wheelAcc -= 120; panel.moveSel(-1) }
            while (wheelAcc <= -120) { wheelAcc += 120; panel.moveSel(1) }
        }
    }

    // ── empty/loading state — also catches Esc to close when the stage isn't focused ──
    Item {
        anchors.fill: parent
        focus: panel.visible && !(panel.ready && panel.filtered.length > 0)
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (panel.filterText) panel.filterText = ""
                else root.imagePickerVisible = false
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (panel.filterText.length > 0) panel.filterText = panel.filterText.slice(0, -1)
                event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
                       && event.text.charCodeAt(0) !== 127
                       && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
                if (event.text !== " " || (panel.filterText.length > 0 && !panel.filterText.endsWith(" "))) panel.filterText += event.text;
                event.accepted = true
            }
        }
    }
    Text {
        visible: root.imagePickerVisible && panel.active && panel.ready && panel.filtered.length === 0
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: "No matches: " + panel.filterText + "\n\nBackspace to edit, or Esc to clear"
        color: root.ink
        font.family: root.mono; font.pixelSize: 16; font.letterSpacing: 1
    }
    Text {
        visible: root.imagePickerVisible && panel.active && !panel.ready
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: panel.scanDone
              ? (panel.isThemeMode ? "No themes found" : "No wallpapers found") + "\n\nEsc or click to close"
              : "Loading…"
        color: root.ink
        font.family: root.mono; font.pixelSize: 16; font.letterSpacing: 1
    }

    // ── header / filter (over the stage) ──
    Text {
        visible: panel.ready
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: stage.top
        anchors.bottomMargin: 22
        opacity: panel.reveal
        text: panel.isThemeMode ? "THEME" : "WALLPAPER"
        color: root.sumiHi
        font.family: root.mono; font.pixelSize: 12; font.letterSpacing: 3; font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
    }

    // ── position indicator (aligned to the right edge of the focused image) ──
    Text {
        visible: panel.ready && panel.filtered.length > 0
        anchors.bottom: stage.top
        anchors.bottomMargin: 23
        x: stage.cx + panel.focusedW / 2 - width
        opacity: panel.reveal
        text: (panel.selFilt + 1) + " / " + panel.filtered.length
        color: panel.uiDim
        font.family: root.mono; font.pixelSize: 11
    }

    // ── the stage (filmstrip) ──
    Item {
        id: stage
        visible: panel.ready && panel.filtered.length > 0
        focus: panel.ready && panel.filtered.length > 0
        opacity: panel.reveal
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -10 + (1 - panel.reveal) * 14
        width: parent.width
        height: panel.focusedH

        readonly property real cx:     width / 2
        readonly property real fLeft:  cx - panel.focusedW / 2
        readonly property real fRight: cx + panel.focusedW / 2

        // left edge x for an item at relIdx r, summing intervening (variable) widths
        function xForRel(r) {
            if (r === 0) return fLeft
            if (r < 0) {
                var n = -r
                return fLeft - n * panel.gap - panel.peekW - (n - 1) * panel.stripW
            }
            if (r === 1) return fRight + panel.gap
            return fRight + r * panel.gap + panel.peekW + (r - 2) * panel.stripW
        }

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (panel.filterText) panel.filterText = ""
                else root.imagePickerVisible = false
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                panel.applySelected(); event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (panel.filterText.length > 0) panel.filterText = panel.filterText.slice(0, -1)
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                       || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                panel.moveSel(-1); event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                panel.moveSel(1); event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
                       && event.text.charCodeAt(0) !== 127
                       && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
                if (event.text !== " " || (panel.filterText.length > 0 && !panel.filterText.endsWith(" "))) panel.filterText += event.text; event.accepted = true
            }
        }

        Repeater {
            model: panel.winCount

            delegate: Item {
                id: item
                required property int index
                readonly property int  absIdx:  panel.absForSlot(index)
                readonly property var  entry:   panel.filtered[absIdx] || null
                readonly property int  relIdx:  absIdx - panel.selFilt
                readonly property bool focused: relIdx === 0
                readonly property bool near:    Math.abs(relIdx) <= panel.maxVisible
                readonly property bool animate: Math.abs(relIdx) <= panel.maxVisible + 2

                // Cached thumbnails are resolved by the scan/warm worker, so
                // visible delegates don't start shell processes or briefly
                // switch from an empty source to a generated path.
                readonly property string thumbPath: entry ? entry.thumb : ""

                width:  panel.stripWidthFor(Math.abs(relIdx))
                height: panel.focusedH
                y: 0
                x: stage.xForRel(relIdx)
                z: focused ? 100 : 50 - Math.abs(relIdx)
                visible: near
                opacity: near ? 1 : 0

                Behavior on x       { enabled: item.animate; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on width   { enabled: item.animate; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on opacity { enabled: item.animate; NumberAnimation { duration: 200 } }

                // hairline frame; the photo is clipped to the rounded INNER shape
                // (ClippingRectangle = AA shader mask) so its corners round to match
                // the frame instead of poking out square. radius 5 = concentric (8 - 3px).
                Rectangle {
                    id: frame
                    anchors.fill: parent
                    radius: 8
                    color: panel.frameBg
                    border.width: 1
                    border.color: item.focused ? root.seal : root.sep
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 5
                        color: "transparent"

                        // image — clipped to the rounded shape above
                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            // cached 512px thumb (theme + wallpaper); current-visibility
                            // bound so off-screen refs drop → bounded memory
                            readonly property string wantedSource: (panel.ready && item.near && item.thumbPath) ? item.thumbPath : ""
                            source: wantedSource
                            onWantedSourceChanged: source = wantedSource
                            Connections {
                                target: panel
                                function onThumbEpochChanged() {
                                    if (thumbImage.wantedSource === panel.readyThumbUrl
                                            && thumbImage.status !== Image.Ready) {
                                        var s = thumbImage.wantedSource
                                        thumbImage.source = ""
                                        thumbImage.source = s
                                    }
                                }
                            }
                            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; smooth: true
                            sourceSize.width:  panel.focusedW
                            sourceSize.height: panel.focusedH
                        }
                        // dim the unfocused strips (paper wash); the preview peek lighter
                        Rectangle {
                            anchors.fill: parent
                            color: root.paper
                            opacity: item.focused ? 0 : (Math.abs(item.relIdx) === 1 ? 0.28 : 0.5)
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }
                }

                // "current" marker — seal dot on the active theme/wallpaper
                Rectangle {
                    visible: item.entry && item.entry.current === true
                    width: 8; height: 8; radius: 4
                    x: 9; y: 9; z: 5
                    color: root.seal
                    border.color: Qt.rgba(0, 0, 0, 0.35); border.width: 1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: item.focused ? panel.applySelected() : (panel.selFilt = item.absIdx)
                }
            }
        }
    }

    // ── seal brush-stroke + label + hint (under the focused image, centred) ──
    Column {
        visible: panel.ready && panel.filtered.length > 0
        opacity: panel.reveal
        anchors.top: stage.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: stage.horizontalCenter
        spacing: 12

        // the single confident accent line — tapered like a brush stroke
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: panel.focusedW * 0.42
            height: 3; radius: 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.5;  color: root.seal }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: panel.focusedW + 120
            text: panel.currentLabel
            color: root.ink
            font.family: root.mono; font.pixelSize: 22; font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        }

        // palette swatch — the focused theme's vivid colours (lazy, theme mode)
        Row {
            visible: panel.isThemeMode && panel.selMeta && panel.selMeta.palette.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: (panel.selMeta && panel.selMeta.palette.length > 0)
                       ? panel.selMeta.palette.split(",") : []
                delegate: Rectangle {
                    required property var modelData
                    width: 13; height: 13; radius: 6.5
                    color: modelData
                    border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
                }
            }
        }

        // meta — current badge · author (click → open repo)
        Row {
            visible: (panel.sel && panel.sel.current)
                     || (panel.isThemeMode && panel.selMeta && panel.selMeta.author.length > 0)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Text {
                visible: panel.sel && panel.sel.current
                anchors.verticalCenter: parent.verticalCenter
                text: "● current"
                color: root.seal
                font.family: root.mono; font.pixelSize: 11
            }
            Text {
                visible: panel.isThemeMode && panel.selMeta && panel.selMeta.author.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "by " + (panel.selMeta ? panel.selMeta.author : "") + "  ↗"
                color: authorMa.containsMouse ? root.seal : panel.uiDim
                font.family: root.mono; font.pixelSize: 11
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea {
                    id: authorMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.openRepo()
                }
            }
        }

        Text {
            visible: panel.filterText.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: panel.filterText
            color: root.seal; opacity: 0.95
            font.family: root.mono; font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "← →  scroll navigate     Enter apply     Esc cancel     type to filter"
            color: panel.uiDim
            font.family: root.mono; font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
