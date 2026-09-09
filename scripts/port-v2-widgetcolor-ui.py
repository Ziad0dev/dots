#!/usr/bin/env python3
"""ControlPanel UI for per-widget colours, plus the two missing widget toggles.

Prerequisite: port-v2-widgetcolor.py (supplies the colour model on Theme).

ControlPanel.qml  Storage + CPU temp toggles in the WIDGETS grid, and a new
                  WIDGET COLOR section: pick a widget, pick a palette slot,
                  toggle its border, cycle its text tone.

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

NEW_TILES = '''                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Storage";      active: root.modStorage;        onActivated: root.modStorage = !root.modStorage }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "CPU temp";     active: root.modCpuTemperature; onActivated: root.modCpuTemperature = !root.modCpuTemperature }'''

COLOR_SECTION = '''
            Rectangle { width: parent.width; height: 1; color: root.sep }

            UiText {
                text: "WIDGET COLOR"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }

            Grid {
                width: parent.width
                columns: 3
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: [
                        { gid: "G1",  name: "Launch" },  { gid: "G2",  name: "Wrkspc" },
                        { gid: "G4",  name: "Memory" },  { gid: "G5",  name: "CPU" },
                        { gid: "G6",  name: "Volume" },  { gid: "G7",  name: "AI" },
                        { gid: "G9",  name: "Media" },   { gid: "G11", name: "Netwrk" },
                        { gid: "G12", name: "GPU" },     { gid: "G13", name: "Mounts" },
                        { gid: "G14", name: "Power" },   { gid: "G15", name: "Bluetth" },
                        { gid: "G16", name: "Temp" },    { gid: "G17", name: "Disk" }
                    ]
                    Tile {
                        required property var modelData
                        width: root.evenW((wwCol.width - 12) / 3)
                        label: modelData.name
                        active: ctrlPanel.colorGid === modelData.gid
                        accent: root.widgetHasFill(modelData.gid)
                            ? root.widgetAssignedColor(modelData.gid) : root.seal
                        onActivated: ctrlPanel.colorGid =
                            (ctrlPanel.colorGid === modelData.gid ? "" : modelData.gid)
                    }
                }
            }

            Row {
                width: parent.width
                visible: ctrlPanel.colorGid !== ""
                spacing: 6

                Repeater {
                    model: ["inherit", "color01", "color02", "color03",
                            "color04", "color05", "color06", "color07"]
                    Rectangle {
                        required property var modelData
                        width: root.evenW((wwCol.width - 42) / 8)
                        height: 22
                        radius: root.tileRadius
                        color: modelData === "inherit"
                            ? root.fillIdle : root.paletteColor(modelData)
                        border.width: 1
                        border.color: root.widgetPaletteId(ctrlPanel.colorGid) === modelData
                            ? root.ink : root.sep
                        UiText {
                            anchors.centerIn: parent
                            visible: parent.modelData === "inherit"
                            text: "\\u2013"
                            color: root.sumi
                            font.family: root.mono; font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setWidgetPaletteColor(ctrlPanel.colorGid,
                                                                  parent.modelData)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                visible: ctrlPanel.colorGid !== ""
                spacing: 8

                Tile {
                    width: root.evenW((wwCol.width - 8) / 2)
                    label: "Border"
                    active: root.widgetHasBorder(ctrlPanel.colorGid)
                    onActivated: root.setWidgetBorderEnabled(ctrlPanel.colorGid,
                        !root.widgetHasBorder(ctrlPanel.colorGid))
                }
                Tile {
                    width: root.evenW((wwCol.width - 8) / 2)
                    label: "Text: " + root.widgetTone(ctrlPanel.colorGid)
                    active: root.widgetTone(ctrlPanel.colorGid) !== "auto"
                    enabled: root.widgetHasFill(ctrlPanel.colorGid)
                    onActivated: {
                        var order = ["auto", "background", "foreground"]
                        var i = order.indexOf(root.widgetTone(ctrlPanel.colorGid))
                        root.setWidgetTone(ctrlPanel.colorGid, order[(i + 1) % order.length])
                    }
                }
            }

            Tile {
                width: parent.width
                visible: ctrlPanel.colorGid !== ""
                label: "Reset this widget"
                onActivated: root.resetWidgetColor(ctrlPanel.colorGid)
            }
'''

FILE_EDITS = {
    "panels/ControlPanel.qml": [
        ('property string colorGid', "selection state",
         "    id: ctrlPanel\n    required property var root",
         "after-line", '    property string colorGid: ""'),
        ('label: "Storage"', "missing widget toggles",
         '''                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Battery";     visible: root.hasBattery; active: true; enabled: false }''',
         "after", "\n" + NEW_TILES),
        ("WIDGET COLOR", "widget colour section",
         '''                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "CPU temp";     active: root.modCpuTemperature; onActivated: root.modCpuTemperature = !root.modCpuTemperature }
            }''',
         "after", COLOR_SECTION.rstrip("\n")),
    ],
}


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
        sys.exit("not a directory: %s (run from the repo root, or pass the rise dir)" % RISE)

    for rel, edits in FILE_EDITS.items():
        path = RISE / rel
        if not path.is_file():
            sys.exit("not found: %s" % path)
        src = path.read_text()
        bad = chk.balance(src, "input " + rel)
        if bad:
            sys.exit("refusing to patch, input unbalanced:\n  " + "\n  ".join(bad))

        applied, skipped = [], []
        for guard, label, anchor, mode, payload in edits:
            if guard in src:
                skipped.append(label)
                continue
            count = src.count(anchor)
            if count != 1:
                sys.exit("%s: anchor for %r matched %d times, expected 1:\n%s"
                         % (rel, label, count, anchor[:160]))
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

        problems = chk.balance(src, "result " + rel)
        if problems:
            sys.exit("%s: patched output unbalanced, NOT writing:\n  %s"
                     % (rel, "\n  ".join(problems)))

        if applied:
            shutil.copy2(path, str(path) + ".bak")
            path.write_text(src)
        print(rel)
        for name in applied:
            print("  +", name)
        for name in skipped:
            print("  =", name, "(already present)")


if __name__ == "__main__":
    main()
