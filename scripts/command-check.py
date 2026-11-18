#!/usr/bin/env python3
"""Every program the bar and the keybinds start must be installed.

A missing program fails silently: the button or the key just does nothing.
SUPER+ALT+T kept running dots-say after 1225bd0 turned text-to-speech off,
and the control panel's Lock kept running hyprlock after it was removed;
2729f46 fixed both. This collects the programs the Quickshell configs and the
Hyprland binds run and looks each one up in the configuration being
committed: the desktop's system profile, the user's profile and the setuid
wrappers, built from the working tree. So the commit that drops a program is
the one that fails, not some commit after the next switch.

It runs only where the bar runs (x86_64 Linux with quickshell installed),
never in CI. COMMAND_CHECK_PATH replaces the built profiles (for testing a
past tree). A program that is optional on purpose is guarded with
`command -v <name>` in the same command string, or listed in OPTIONAL.
"""

import getpass
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
HOST = "nixos"
OPTIONAL = {
    "bluetoothctl": "the Bluetooth widget's; Bluetooth is off on this host",
    "iwctl": "the iwd path, taken only when NetworkManager isn't running",
    "dots": "upstream's CLI, a fallback after the dots-* shims",
}
# shell keywords and builtins
SHELL = set(
    "if then else elif fi for while until do done case esac in function return exit "
    "break continue local export readonly declare set unset shift eval source . : "
    "true false test [ [[ ]] ] echo printf read cd pwd wait kill trap command type "
    "hash ulimit umask let alias { } ! time shopt".split()
)
# wrappers that run another program: their options that take a value, and
# how many arguments come before the program (timeout's duration, flock's file)
WRAPPERS = {
    "env": ({"-C", "--chdir", "-u", "--unset", "-S", "--split-string"}, 0),
    "systemd-run": ({"-p", "--property", "-u", "--unit", "--description", "-E", "--setenv",
                     "--slice", "-M", "--machine", "--working-directory", "--uid", "--gid", "--nice"}, 0),
    "nice": ({"-n", "--adjustment"}, 0),
    "timeout": ({"-s", "--signal", "-k", "--kill-after"}, 1),
    "flock": ({"-w", "--timeout", "-E", "--conflict-exit-code"}, 1),
    "sudo": ({"-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U"}, 0),
    "exec": (set(), 0),
    "setsid": (set(), 0),
    "nohup": (set(), 0),
    "uwsm-app": (set(), 0),
}
PARTIAL = "\0"  # marks an argv element that is a literal followed by an expression
STRING = r'"((?:[^"\\]|\\.)*)"'
ARRAY = re.compile(r"(?:\bcommand\s*:\s*|\.command\s*=\s*|execDetached\s*\(\s*)\[")
LUA_CALL = re.compile(r"\b(?:exec_cmd|util\.sh)\s*\(\s*(?:" + STRING + r"|\[\[(.*?)\]\])", re.S)


def built_path() -> tuple[str | None, str]:
    """The PATH the bar and Hyprland get from the configuration in the working tree."""
    user = os.environ.get("DOTS_USERNAME") or getpass.getuser()
    attrs = [
        f".#nixosConfigurations.{HOST}.config.system.path",
        f'.#nixosConfigurations.{HOST}.config.environment.etc."profiles/per-user/{user}".source',
    ]
    res = subprocess.run(
        ["nix", "build", "--no-link", "--print-out-paths", "--no-warn-dirty", *attrs],
        cwd=REPO, capture_output=True, text=True, check=False,
    )
    if res.returncode != 0:
        return None, "\n".join(res.stderr.strip().splitlines()[-3:])
    return ":".join(["/run/wrappers/bin"] + [p + "/bin" for p in res.stdout.split()]), ""


def unescape(js: str) -> str:
    """A string literal's text: \\" -> ", \\n -> newline, and so on."""
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), js)


def program_at(words: list) -> tuple[int, str | None]:
    """Index and name of the program a command runs: past VAR=value
    assignments and wrappers with their options. None if it isn't literal."""
    i = 0
    while i < len(words):
        w = words[i]
        if w is None:
            return i, None
        if re.match(r"^[A-Za-z_]\w*=", w):
            i += 1
            continue
        if w.endswith(PARTIAL):
            return i, None
        if w in WRAPPERS:
            takes_value, before = WRAPPERS[w]
            i += 1
            while i < len(words) and words[i] is not None and words[i].startswith("-"):
                opt = words[i]
                i += 1
                if opt == "--":
                    break
                if opt in takes_value:
                    i += 1
            while i < len(words) and words[i] is not None and re.match(r"^[A-Za-z_]\w*=", words[i]):
                i += 1
            i += before
            continue
        return i, w
    return i, None


def first_words(script: str) -> list[str]:
    """The program of each simple command in a shell string."""
    guarded = set(re.findall(r"command\s+-v\s+([\w.+-]+)", script))
    # functions the script defines itself
    guarded |= set(re.findall(r"(?:^|[;{\s])(?:function\s+)?([\w-]+)\s*\(\)\s*\{", script))
    # redirections (2>&1, &>file) aren't commands; newlines separate them
    script = re.sub(r"\d*>&\d*-?|&>>?", " ", script).replace("\n", ";")
    lexer = shlex.shlex(script, posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return []
    commands, words = [], []
    for tok in tokens:
        if tok and set(tok) <= set(";&|()"):
            commands.append(words)
            words = []
        else:
            words.append(tok)
    commands.append(words)
    found = []
    for words in commands:
        while words and words[0] in ("if", "then", "else", "elif", "while", "until", "do", "!", "{", "}"):
            words = words[1:]
        i, prog = program_at(words)
        if prog is None or prog in guarded:
            continue
        if prog in ("bash", "sh") and i + 2 < len(words) and words[i + 1] == "-c":
            found += first_words(words[i + 2])
        else:
            found.append(prog)
    return found


def array_at(src: str, start: int) -> list:
    """The elements of the array literal opening just before `start`: its text
    for a string literal, the leading literal + PARTIAL for an expression that
    starts with one, None for anything else."""
    elems, buf, depth, quote, i = [], "", 0, None, start
    while i < len(src):
        ch = src[i]
        if quote:
            buf += ch
            if ch == "\\":
                buf += src[i + 1 : i + 2]
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "\"'`":
            quote = ch
            buf += ch
        elif ch in "([{":
            depth += 1
            buf += ch
        elif ch in ")]}":
            if depth == 0:
                elems.append(buf)
                break
            depth -= 1
            buf += ch
        elif ch == "," and depth == 0:
            elems.append(buf)
            buf = ""
        else:
            buf += ch
        i += 1
    out = []
    for e in (e.strip() for e in elems):
        m = re.match(STRING, e)
        if not e:
            continue
        if m and m.end() == len(e):
            out.append(unescape(m.group(1)))
        elif m:
            out.append(unescape(m.group(1)) + PARTIAL)
        else:
            out.append(None)
    return out


def programs(text: str, lua: bool) -> list[tuple[int, str]]:
    out = []
    if lua:
        for m in LUA_CALL.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            script = unescape(m.group(1)) if m.group(1) is not None else m.group(2)
            out += [(line, w) for w in first_words(script)]
        return out
    for m in ARRAY.finditer(text):
        line = text.count("\n", 0, m.start()) + 1
        argv = array_at(text, m.end())
        i, prog = program_at(argv)
        if prog is None:
            continue
        if prog in ("bash", "sh") and i + 2 < len(argv) and argv[i + 1] == "-c" and argv[i + 2] is not None:
            out += [(line, w) for w in first_words(argv[i + 2].rstrip(PARTIAL))]
        else:
            out.append((line, prog))
    return out


def main() -> int:
    if os.environ.get("CI"):
        print("command-check: skipped in CI (no desktop to build)")
        return 0
    path = os.environ.get("COMMAND_CHECK_PATH")
    if path is None:
        if platform.system() != "Linux" or platform.machine() != "x86_64" or not shutil.which("quickshell"):
            print("command-check: skipped (the bar doesn't run on this machine)")
            return 0
        path, err = built_path()
        if path is None:
            print(f"command-check: couldn't build the desktop's profiles:\n{err}")
            return 1
    files = sorted((REPO / "config/quickshell").rglob("*.qml")) + sorted((REPO / "config/hypr").rglob("*.lua"))
    missing = []
    for f in files:
        for line, prog in programs(f.read_text(errors="replace"), f.suffix == ".lua"):
            # names only: not `$(date).png`'s ".png" or an option
            if prog in SHELL or prog in OPTIONAL or not re.match(r"^[\w/][\w./+-]*$", prog):
                continue
            ok = os.path.exists(prog) if prog.startswith("/") else shutil.which(prog, path=path)
            entry = f"{f.relative_to(REPO)}:{line}: {prog}"
            if not ok and entry not in missing:
                missing.append(entry)
    for m in missing:
        print(f"command-check: not installed: {m}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
