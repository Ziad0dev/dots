#!/usr/bin/env python3
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "config/quickshell/rise"

GLOBALS = {
    "Qt", "Math", "JSON", "Object", "Number", "String", "Date", "Array", "Boolean",
    "RegExp", "console", "parent", "this", "undefined", "null", "true", "false",
    "arguments", "window", "screen", "globalThis", "Promise", "Map", "Set", "Error",
    "parseInt", "parseFloat", "isNaN", "encodeURIComponent", "decodeURIComponent",
    "modelData", "model", "index", "data", "text", "color", "font", "anchors",
    "width", "height", "x", "y", "z", "opacity", "visible", "enabled", "children",
    "implicitWidth", "implicitHeight", "contentItem", "background", "item", "source",
    "sourceItem", "target", "mouse", "wheel", "event", "drag", "containsMouse",
    "border", "easing", "layer", "sourceSize", "priority", "gradient", "shadow",
    "activeFocus", "padding", "insets", "margins", "textFormat", "cursorShape",
}

DECL_ID = re.compile(r"\bid\s*:\s*([A-Za-z_]\w*)")
DECL_PROP = re.compile(
    r"\b(?:required\s+|readonly\s+|default\s+)*property\s+(?:alias\s+)?[\w.<>]+\s+(\w+)"
)
DECL_SIGNAL = re.compile(r"\bsignal\s+(\w+)")
DECL_FUNC = re.compile(r"\bfunction\s+(\w+)\s*\(([^)]*)\)")
DECL_VAR = re.compile(r"\b(?:var|let|const)\s+([^;\n]+)")
DECL_FOR = re.compile(r"\bfor\s*\(\s*(?:var|let|const)?\s*(\w+)\s+in\s")
ARROW = re.compile(r"(?:\(([^)]*)\)|(\w+))\s*=>")
FUNC_EXPR = re.compile(r"\bfunction\s*\(([^)]*)\)")
CATCH = re.compile(r"\bcatch\s*\(\s*(\w+)")
REF = re.compile(r"(?<![\w.$])([a-z_]\w*)((?:\s*\.\s*[A-Za-z_]\w*)+)")


REGEX_PREV = set("([{,;:=!&|?+-*%~^<>") | {"return", "typeof", "case", "in", "of", "new", "delete", "void", "do", "else"}


def _regex_allowed(out):
    i = len(out) - 1
    while i >= 0 and out[i].isspace():
        i -= 1
    if i < 0:
        return True
    if out[i] in REGEX_PREV:
        return True
    j = i
    while j >= 0 and (out[j].isalnum() or out[j] == "_"):
        j -= 1
    return "".join(out[j + 1 : i + 1]) in REGEX_PREV


def strip_noise(src):
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                out.append(" ")
                i += 1
        elif c == "/" and i + 1 < n and src[i + 1] == "*":
            out.append("  ")
            i += 2
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append("  ")
            i += 2
        elif c == "/" and _regex_allowed(out):
            out.append(" ")
            i += 1
            klass = False
            while i < n and src[i] != "\n":
                if src[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                if src[i] == "[":
                    klass = True
                elif src[i] == "]":
                    klass = False
                elif src[i] == "/" and not klass:
                    i += 1
                    break
                out.append(" ")
                i += 1
            out.append(" ")
        elif c in "\"'`":
            quote = c
            out.append(" ")
            i += 1
            while i < n:
                if src[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                if src[i] == quote:
                    i += 1
                    break
                if src[i] == "\n" and quote != "`":
                    break
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append(" ")
        else:
            out.append(c)
            i += 1
    return "".join(out)


def params(text):
    out = set()
    for p in text.split(","):
        p = p.strip().split(":")[0].split("=")[0].strip()
        if re.fullmatch(r"\w+", p):
            out.add(p)
    return out


def declared(src):
    names = set(GLOBALS)
    names |= set(DECL_ID.findall(src))
    names |= set(DECL_PROP.findall(src))
    names |= set(DECL_SIGNAL.findall(src))
    for chunk in DECL_VAR.findall(src):
        depth = 0
        cur = ""
        parts = []
        for ch in chunk:
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            if ch == "," and depth == 0:
                parts.append(cur)
                cur = ""
            else:
                cur += ch
        parts.append(cur)
        for part in parts:
            m = re.match(r"\s*(\w+)", part)
            if m:
                names.add(m.group(1))
    names |= set(DECL_FOR.findall(src))
    names |= set(CATCH.findall(src))
    for _, plist in [(m.group(1), m.group(2)) for m in DECL_FUNC.finditer(src)]:
        names |= params(plist)
    for m in DECL_FUNC.finditer(src):
        names.add(m.group(1))
    for m in FUNC_EXPR.finditer(src):
        names |= params(m.group(1))
    for m in ARROW.finditer(src):
        names |= params(m.group(1) or m.group(2) or "")
    return names


ROOT_TYPE = re.compile(r"^\s*([A-Z]\w*)\s*\{", re.M)


def component_index():
    return {p.stem: p for p in list(ROOT.rglob("*.qml")) + list(ROOT.rglob("*.js"))}


def inherited(path, index, seen=None):
    seen = seen or set()
    if path in seen or path.suffix != ".qml":
        return set()
    seen.add(path)
    src = strip_noise(path.read_text(errors="replace"))
    names = set(DECL_PROP.findall(src)) | set(DECL_SIGNAL.findall(src))
    m = ROOT_TYPE.search(src)
    if m and m.group(1) in index:
        names |= inherited(index[m.group(1)], index, seen)
    return names


def check_file(path, index):
    src = strip_noise(path.read_text(errors="replace"))
    names = declared(src) | set(index)
    m = ROOT_TYPE.search(src)
    if m and m.group(1) in index and index[m.group(1)] != path:
        names |= inherited(index[m.group(1)], index)
    problems = []

    ids = DECL_ID.findall(src)
    for i in set(ids):
        if ids.count(i) > 1:
            problems.append(f"duplicate id '{i}' declared {ids.count(i)}x")

    seen = set()
    for m in REF.finditer(src):
        name = m.group(1)
        line_start = src.rfind("\n", 0, m.start()) + 1
        line_end = src.find("\n", m.start())
        if "qml-check: ignore" in src[line_start:line_end if line_end > 0 else len(src)]:
            continue
        tail = src[m.end():]
        if re.match(r"\s*:(?!=)", tail):
            continue
        if name in names or name in seen:
            continue
        seen.add(name)
        line = src[: m.start()].count("\n") + 1
        problems.append(f"line {line}: '{name}.' is not an id, property or local in this file")
    return problems


def main():
    if not ROOT.is_dir():
        print(f"qml-check: {ROOT} not found", file=sys.stderr)
        return 1
    index = component_index()
    fail = 0
    for path in sorted(ROOT.rglob("*.qml")):
        for p in check_file(path, index):
            print(f"qml-check: {path.relative_to(ROOT.parent.parent.parent)}: {p}")
            fail = 1
    if not fail:
        print("qml-check: ok")
    return fail


if __name__ == "__main__":
    sys.exit(main())
