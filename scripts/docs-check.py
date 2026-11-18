#!/usr/bin/env python3
"""Docs must not point at files that are gone.

Every `path` in backticks in docs/*.md and README.md that looks like a file
of this repo (modules/, home/, lib/, …) must exist, from the repo root or,
for the bar's files, from config/quickshell/rise; a bare `name.nix` or
`name.qml` must be the name of some file in the repo. 1a5bb11 and 244b445
each fixed a doc that still named a deleted file.

A path followed closely by "removed" or "deleted" ("`lib/x.nix`, removed in
…") is history, not a pointer, and is left alone.
"""

import re
import sys
from pathlib import Path

REPO = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
BAR = REPO / "config/quickshell/rise"
PATH = re.compile(r"`((?:modules|home|hosts|lib|pkgs|scripts|flakes|tests|config|panels|core|ext)/[A-Za-z0-9_./-]+)`")
BARE = re.compile(r"`([A-Za-z0-9_.-]+\.(?:nix|qml))`")
GONE = re.compile(r"\b(removed|deleted)\b", re.I)
# not files of this repo
ALLOW = {"lib/modules.nix": "nixpkgs' own file, named in a stack-trace tip"}


def main() -> int:
    names = {p.name for p in REPO.rglob("*") if ".git" not in p.parts}
    docs = sorted((REPO / "docs").glob("*.md")) + [REPO / "README.md"]
    missing = []
    for doc in docs:
        for n, line in enumerate(doc.read_text().splitlines(), 1):
            for m in PATH.finditer(line):
                path = m.group(1).split(":")[0].rstrip(".")
                if path in ALLOW or any(c in path for c in "*<{") or GONE.search(line[m.end() : m.end() + 40]):
                    continue
                if not ((REPO / path).exists() or (BAR / path).exists()):
                    missing.append(f"{doc.relative_to(REPO)}:{n}: {path}")
            for m in BARE.finditer(line):
                if m.group(1) not in names and not GONE.search(line[m.end() : m.end() + 40]):
                    missing.append(f"{doc.relative_to(REPO)}:{n}: {m.group(1)}")
    for m in missing:
        print(f"docs-check: no such file: {m}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
