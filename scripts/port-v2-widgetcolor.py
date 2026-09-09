#!/usr/bin/env python3
"""Per-widget palette colours, V2's model ported onto this fork's widget pills.

Prerequisites: the earlier port-v2-*.py passes.

Theme.qml     the colour model (per-GID color / mode / tone) + its own cache file
BarSlot.qml   registry passes each widget its GID
modules/*.qml every pill honours widgetFillColor / widgetBorderColor for its GID

State lives in ~/.cache/quickshell_widget_colors, deliberately separate from
quickshell_widgets so the existing widget-state serialization is untouched.

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import re
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

MODEL = r'''
    property var widgetColorStyles: ({})
    property bool _widgetColorsLoaded: false

    function widgetGidValid(gid) {
        var m = String(gid || "").match(/^G(\d{1,2})$/)
        if (!m) return false
        var n = Number(m[1])
        return n >= 1 && n <= 17
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
        for (var n = 1; n <= 17; n++) {
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

    function saveWidgetColors() {
        widgetColorSaveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + widgetColorsCachePath + "')\" && echo '"
            + serializeWidgetColorStyles() + "' > '" + widgetColorsCachePath + "'"]
        widgetColorSaveProc.running = false
        widgetColorSaveProc.running = true
    }

    Process { id: widgetColorSaveProc }

    Process {
        id: widgetColorLoadProc
        running: true
        command: ["cat", theme.widgetColorsCachePath]
        stdout: StdioCollector {
            onStreamFinished: {
                theme.widgetColorStyles =
                    theme.parseWidgetColorStyles(String(this.text || "").trim())
                theme._widgetColorsLoaded = true
            }
        }
        onExited: theme._widgetColorsLoaded = true
    }
'''

def registry_map(bsrc):
    """GID -> component id, read from BarSlot's own registry literal."""
    out = {}
    for gid, comp in re.findall(r'"(G\d{1,2})":\s*(\w+)', bsrc):
        out[comp] = gid
    return out


THEME_EDITS = [
    ("widgetColorStyles", "per-widget colour model",
     '''    readonly property string widgetsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_widgets"''',
     "after-line", MODEL.rstrip("\n")),
]


def widget_pill_edits(src, gid):
    """Rewrite a widget's own pill so it honours its GID's colour style.

    The qualifying id is read from the file — assuming `rootMod` silently
    breaks every widget that names its root object something else, and a
    failed colour binding renders as a white Rectangle rather than an error.
    """
    m = re.search(r'^\s{4}id:\s*(\w+)\s*$', src, re.M)
    if not m:
        return src
    rid = m.group(1)
    out = src
    if 'property string gid:' not in out:
        out = re.sub(r'(\n    required property var root\n)',
                     r'\1    property string gid: "%s"\n' % gid, out, count=1)
        if 'property string gid:' not in out:
            return src
    out = out.replace("color: root.pill\n",
                      "color: root.widgetFillColor(%s.gid)\n" % rid)
    out = out.replace("border.color: root.pillBorder\n",
                      "border.color: root.widgetBorderColor(%s.gid)\n" % rid)
    out = out.replace("border.width: root.pillBorderW\n",
                      "border.width: root.widgetBorderWidth(%s.gid)\n" % rid)
    return out


def _load_checker():
    import importlib.util
    here = Path(__file__).resolve().parent
    for cand in (here / "port-v2-telemetry.py", Path("scripts/port-v2-telemetry.py")):
        if cand.is_file():
            spec = importlib.util.spec_from_file_location("_chk", cand)
            mod = importlib.util.module_from_spec(spec)
            argv, sys.argv = sys.argv, ["_chk"]
            try:
                spec.loader.exec_module(mod)
            finally:
                sys.argv = argv
            return mod
    sys.exit("port-v2-telemetry.py must sit next to this script (it supplies the brace checker)")



def main():
    chk = _load_checker()
    if not RISE.is_dir():
        sys.exit("not a directory: %s" % RISE)

    # 1. Theme model
    tp = RISE / "Theme.qml"
    src = tp.read_text()
    if chk.balance(src, "input Theme"):
        sys.exit("Theme.qml is already unbalanced")
    applied = []
    for guard, label, anchor, mode, payload in THEME_EDITS:
        if guard in src:
            print("  = %s (already present)" % label); continue
        if src.count(anchor) != 1:
            sys.exit("Theme.qml: anchor for %r matched %d times" % (label, src.count(anchor)))
        end = src.index(anchor) + len(anchor)
        end = src.index("\n", end)
        src = src[:end] + "\n" + payload + src[end:]
        applied.append(label)
    if chk.balance(src, "result Theme"):
        sys.exit("Theme.qml patched output unbalanced, NOT writing")
    if applied:
        shutil.copy2(tp, str(tp) + ".bak"); tp.write_text(src)
        for a in applied: print("  +", a)

    # 2. registry passes gid
    bp = RISE / "BarSlot.qml"
    bsrc = bp.read_text()
    n = 0
    for comp, gid in registry_map(bsrc).items():
        pat = re.compile(r'(Component \{ id: %s;\s*\w+\s*\{ root: barSlot\.root)( \})' % comp)
        new, k = pat.subn(r'\1; gid: "%s"\2' % gid, bsrc)
        if k: bsrc = new; n += k
    if n:
        if chk.balance(bsrc, "result BarSlot"):
            sys.exit("BarSlot.qml patched output unbalanced, NOT writing")
        shutil.copy2(bp, str(bp) + ".bak"); bp.write_text(bsrc)
    print("  %s %d registry entries carry a gid" % ("+" if n else "=", n))

    # 3. widget pills
    touched = []
    for comp, gid in sorted(registry_map(bp.read_text()).items(), key=lambda kv: int(kv[1][1:])):
        m = re.search(r'Component \{ id: %s;\s*(\w+)\s*\{' % comp, bp.read_text())
        if not m: continue
        wp = RISE / "modules" / (m.group(1) + ".qml")
        if not wp.is_file(): continue
        wsrc = wp.read_text()
        new = widget_pill_edits(wsrc, gid)
        if new == wsrc: continue
        if chk.balance(new, "result " + wp.name):
            sys.exit("%s patched output unbalanced, NOT writing" % wp.name)
        shutil.copy2(wp, str(wp) + ".bak"); wp.write_text(new)
        touched.append(wp.name)
    print("  + %d widget pills recoloured" % len(touched) if touched
          else "  = widget pills already recoloured")
    for t in touched: print("      ", t)


if __name__ == "__main__":
    main()
