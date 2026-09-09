#!/usr/bin/env python3
"""Add the V2 connected-panel state layer to rise/Theme.qml.

Prerequisite: port-v2-telemetry.py (supplies panelInsetX / setPanelInsetX /
panelOuterBorder* / v2BarBorder).

Theme-only. Adds the properties BarSlot's edgeBorder block and the
Ai*/Connected* components read; changes nothing visible on its own.

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: port-v2-caret.py [path/to/Theme.qml]
"""
import sys
from pathlib import Path

import shutil

TARGET = Path(sys.argv[1] if len(sys.argv) > 1
              else "config/quickshell/rise/Theme.qml")

SHELL_STYLE = '''    property string barShellStyle: "full"
    property bool barBorderEnabled: true
    function barShellStyleValid(value) {
        return value === "full" || value === "fit"
            || value === "dock" || value === "notch"
    }
    readonly property int v2BarHeight: 33
    readonly property int v2NotchFrameThickness: 6
    readonly property int v2NotchFrameRadius: 14
'''

CARET_STATE = '''
    readonly property bool anchoredPanelVisible: calendarVisible || cpuVisible || gpuVisible
        || thermalVisible || aiUsageVisible || langVisible || keybindsVisible
        || memVisible || volVisible || controlVisible || networkVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible
        || workspaceVisible || notifVisible || powerProfileVisible || storageVisible
        || archVisible || trayVisible

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
        : archVisible ? archBarX
        : trayVisible ? trayBarX
        : 0

    property real panelInsetReveal: anchoredPanelVisible ? 1 : 0
    Behavior on panelInsetReveal {
        NumberAnimation {
            duration: theme.anchoredPanelVisible ? 160 : 120
            easing.type: theme.anchoredPanelVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
'''

NEW_ANCHORS = '''    property real calendarBarX:   0
    property real gpuBarX:        0
    property real thermalBarX:    0
    property real storageBarX:    0
'''

NEW_APPLY = '''        else if (name === "calendar") calendarBarX = x
        else if (name === "gpu") gpuBarX = x
        else if (name === "thermal") thermalBarX = x
        else if (name === "storage") storageBarX = x
'''

EDITS = [
    ("property string barShellStyle", "shell style + notch geometry",
     "    property bool panelTooltipBorderEnabled: true",
     "after-line", SHELL_STYLE.rstrip("\n")),
    ("anchoredPanelVisible", "caret state",
     '''    function setPanelInsetX(x) {
        if (isFinite(x) && x > 0) panelInsetX = x
    }''',
     "after", CARET_STATE.rstrip("\n")),
    ("property real calendarBarX", "new caret anchors",
     "    property real launcherBarX:   6   // ControlPanel follows the Launcher/Control group",
     "after-line", NEW_ANCHORS.rstrip("\n")),
    ('name === "calendar"', "applyAnchor branches",
     '        else if (name === "launcher") launcherBarX = x',
     "after-line", NEW_APPLY.rstrip("\n")),
]


def strip_literals(src):
    """Blank out string, template, comment and regex literal bodies, keeping
    newlines so line numbers survive. Regex detection uses the last significant
    character, so `.replace(/[`]/g, ...)` cannot swallow the rest of the file."""
    out = []
    i, n = 0, len(src)
    prev = ""
    while i < n:
        c = src[i]
        if c in "\"'`":
            quote = c
            out.append(" ")
            i += 1
            while i < n:
                if src[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                if src[i] == quote:
                    break
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append(" ")
            i += 1
            prev = quote
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append("  ")
            i += 2
            continue
        if c == "/" and prev in "(,=:[!&|?{};+-*%~^<>" :
            out.append(" ")
            i += 1
            while i < n and src[i] != "\n":
                if src[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                if src[i] == "/":
                    break
                out.append(" ")
                i += 1
            out.append(" ")
            i += 1
            prev = "/"
            continue
        out.append(c)
        if not c.isspace():
            prev = c
        i += 1
    return "".join(out)


def balance(src, label):
    code = strip_literals(src)
    bad = []
    for open_c, close_c, name in (("{", "}", "brace"), ("(", ")", "paren"),
                                  ("[", "]", "bracket")):
        depth = 0
        for line_no, line in enumerate(code.split("\n"), 1):
            for ch in line:
                if ch == open_c:
                    depth += 1
                elif ch == close_c:
                    depth -= 1
                    if depth < 0:
                        bad.append("%s: unmatched closing %s at line %d"
                                   % (label, name, line_no))
                        depth = 0
        if depth != 0:
            bad.append("%s: %s balance ends at %+d" % (label, name, depth))
    return bad


def main():
    if not TARGET.is_file():
        sys.exit("not found: %s (run from the repo root, or pass a path)" % TARGET)
    src = TARGET.read_text()
    before = balance(src, "input")
    if before:
        sys.exit("refusing to patch, input is already unbalanced:\n  "
                 + "\n  ".join(before))

    applied, skipped = [], []
    for guard, label, anchor, mode, payload in EDITS:
        if guard in src:
            skipped.append(label)
            continue
        count = src.count(anchor)
        if count != 1:
            sys.exit("anchor for %r matched %d times, expected 1:\n%s"
                     % (label, count, anchor[:120]))
        if mode == "replace":
            src = src.replace(anchor, payload)
        else:
            end = src.index(anchor) + len(anchor)
            if mode == "after-line":
                end = src.index("\n", end)
                if not payload.startswith("\n"):
                    payload = "\n" + payload
            src = src[:end] + payload + src[end:]
        applied.append(label)

    problems = balance(src, "result")
    if problems:
        sys.exit("patched output is unbalanced, NOT writing:\n  "
                 + "\n  ".join(problems))

    if applied:
        shutil.copy2(TARGET, str(TARGET) + ".bak")
        TARGET.write_text(src)
    for name in applied:
        print("  +", name)
    for name in skipped:
        print("  =", name, "(already present)")
    print("%s: %d lines%s" % (TARGET, src.count("\n") + 1,
                              "" if applied else " (no changes)"))


if __name__ == "__main__":
    main()
