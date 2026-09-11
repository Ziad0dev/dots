#!/usr/bin/env python3
import argparse
import re
import shutil
from pathlib import Path

PAGES = {
    "README.md": "Home",
    "install.md": "Getting-Started",
    "workflow.md": "Workflow",
    "architecture.md": "Architecture",
    "modules.md": "System-Modules",
    "services.md": "Services",
    "desktop.md": "Desktop",
    "theming.md": "Theming",
    "development.md": "Development",
    "scripts.md": "Scripts-and-Commands",
    "troubleshooting.md": "Troubleshooting",
    "nix-cheatsheet.md": "Nix-Cheatsheet",
}

SIDEBAR = [
    ("Start", ["Home", "Getting-Started", "Workflow"]),
    ("Reference", ["Architecture", "System-Modules", "Services", "Desktop", "Theming", "Development", "Scripts-and-Commands"]),
    ("Help", ["Troubleshooting", "Nix-Cheatsheet"]),
]

LINK = re.compile(r"(!?)\[([^\]]*)\]\(([^)\s]+)\)")
FENCE = re.compile(r"^\s*(```|~~~)")


def page_name(md):
    if md.name in PAGES:
        return PAGES[md.name]
    for line in md.read_text().splitlines():
        if line.startswith("# "):
            words = re.sub(r"[^\w\s-]", "", line[2:]).split()
            return "-".join(w[:1].upper() + w[1:] for w in words)
    return md.stem.replace("_", "-").title()


def convert(text, src, docs, names, repo, ref):
    blob = f"https://github.com/{repo}/blob/{ref}"
    tree = f"https://github.com/{repo}/tree/{ref}"
    raw = f"https://raw.githubusercontent.com/{repo}/{ref}"
    root = docs.parent

    def fix(m):
        bang, label, target = m.groups()
        if re.match(r"^[a-z]+:", target) or target.startswith("#"):
            return m.group(0)
        path, _, anchor = target.partition("#")
        dest = (src.parent / path).resolve()
        frag = f"#{anchor}" if anchor else ""
        if dest.suffix == ".md" and dest.parent == docs.resolve() and dest.name in names:
            return f"{bang}[{label}]({names[dest.name]}{frag})"
        try:
            rel = dest.relative_to(root.resolve()).as_posix()
        except ValueError:
            return m.group(0)
        if bang:
            return f"{bang}[{label}]({raw}/{rel})"
        base = tree if dest.is_dir() else blob
        return f"[{label}]({base}/{rel}{frag})"

    out, fenced, dropped_h1 = [], False, False
    for line in text.splitlines():
        if FENCE.match(line):
            fenced = not fenced
            out.append(line)
            continue
        if fenced:
            out.append(line)
            continue
        if not dropped_h1 and line.startswith("# "):
            dropped_h1 = True
            continue
        out.append(LINK.sub(fix, line))
    while out and not out[0].strip():
        out.pop(0)
    return "\n".join(out).rstrip() + "\n"


def sidebar(present):
    lines, seen = [], set()
    for title, pages in SIDEBAR:
        items = [p for p in pages if p in present]
        if not items:
            continue
        lines.append(f"**{title}**\n")
        lines += [f"- [{p.replace('-', ' ')}]({p})" for p in items]
        lines.append("")
        seen.update(items)
    extra = sorted(present - seen)
    if extra:
        lines.append("**More**\n")
        lines += [f"- [{p.replace('-', ' ')}]({p})" for p in extra]
        lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="Render docs/ as a GitHub wiki.")
    ap.add_argument("docs", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--repo", required=True, help="owner/name")
    ap.add_argument("--ref", default="main", help="branch or commit for links back into the repo")
    ap.add_argument("--banner", default=".github/assets/banner.svg", help="repo path of the Home banner, empty to skip")
    a = ap.parse_args()

    docs = a.docs.resolve()
    sources = sorted(docs.glob("*.md"))
    if not sources:
        raise SystemExit(f"no markdown in {docs}")
    names = {md.name: page_name(md) for md in sources}

    if a.out.exists():
        shutil.rmtree(a.out)
    a.out.mkdir(parents=True)

    for md in sources:
        name = names[md.name]
        body = convert(md.read_text(), md, docs, names, a.repo, a.ref)
        if name == "Home" and a.banner and (docs.parent / a.banner).exists():
            body = f'<p align="center"><img src="https://raw.githubusercontent.com/{a.repo}/{a.ref}/{a.banner}" alt="dots" width="100%"></p>\n\n' + body
        src = md.relative_to(docs.parent).as_posix()
        body += f"\n---\n<sub>Source: [`{src}`](https://github.com/{a.repo}/blob/{a.ref}/{src})</sub>\n"
        (a.out / f"{name}.md").write_text(body)

    present = set(names.values())
    (a.out / "_Sidebar.md").write_text(sidebar(present))
    (a.out / "_Footer.md").write_text(
        f"<sub>Generated from [`docs/`](https://github.com/{a.repo}/tree/{a.ref}/docs). "
        "Edits made here are overwritten on the next push — change the repo instead.</sub>\n"
    )
    print(f"{len(sources)} pages -> {a.out}")


if __name__ == "__main__":
    main()
