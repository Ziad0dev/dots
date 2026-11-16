#!/usr/bin/env python3
"""Analyze Linux Kernel Mailing List traffic from lore.kernel.org.

Fetches messages through lore's public-inbox Atom search API and reports
which subsystems are busiest, which patch series are in flight (and at which
revision), who is posting and who is reviewing (Reviewed-by / Acked-by /
Tested-by trailers), and which threads are the most active.

    python lkml.py report                       # last day of LKML
    python lkml.py report --since 3.days.ago --pages 5
    python lkml.py report --query 's:"mm:"'     # any lore search query
    python lkml.py report --list netdev --json  # another list on lore
    python lkml.py report --file saved.atom     # offline, from a saved feed

Standard library only.
"""
import argparse
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass, field
from pathlib import Path

LORE = "https://lore.kernel.org"
USER_AGENT = "lkml-analyzer/0.1 (+https://github.com/Ziad0dev/LKML)"
NS = {"a": "http://www.w3.org/2005/Atom", "thr": "http://purl.org/syndication/thread/1.0"}
PAGE_SIZE = 200  # lore returns up to 200 entries per Atom page

# [PATCH net-next v4 3/8] net: bcmgenet: allow ...
SUBJECT_RE = re.compile(
    r"^(?P<reply>(?:re|fwd?|aw):\s*)*"
    r"(?:\[(?P<tags>[^\]]*)\]\s*)?"
    r"(?P<rest>.*)$",
    re.IGNORECASE,
)
VERSION_RE = re.compile(r"\bv(\d+)\b", re.IGNORECASE)
INDEX_RE = re.compile(r"\b(\d+)/(\d+)\b")
TRAILER_RE = re.compile(r"^\s*(Reviewed-by|Acked-by|Tested-by|Reported-by|Suggested-by|NAKed-by):\s*(.+?)\s*<", re.MULTILINE | re.IGNORECASE)
QUOTE_RE = re.compile(r"^\s*>.*$", re.MULTILINE)


@dataclass
class Subject:
    is_reply: bool
    kind: str            # PATCH, RFC, GIT PULL, REGRESSION, ... or "" for plain mail
    version: int
    index: int           # position in the series, 0 for the cover letter
    total: int
    tree: str            # net, net-next, bpf-next, ... when given in the tag
    subsystem: str       # leading "foo:" or "foo/bar:" prefix of the summary
    summary: str
    series_key: str      # identifies a series across revisions


def parse_subject(title):
    m = SUBJECT_RE.match(title.strip())
    tags = (m.group("tags") or "").strip()
    rest = m.group("rest").strip()
    words = tags.split()
    upper = tags.upper()
    if "GIT PULL" in upper:
        kind = "GIT PULL"
    elif "REGRESSION" in upper:
        kind = "REGRESSION"
    elif "PATCH" in upper:
        kind = "RFC PATCH" if "RFC" in upper else "PATCH"
    elif upper.startswith("RFC"):
        kind = "RFC"
    else:
        kind = tags.split()[0].upper() if tags else ""
    version = int(VERSION_RE.search(tags).group(1)) if VERSION_RE.search(tags) else 1
    idx = INDEX_RE.search(tags)
    index, total = (int(idx.group(1)), int(idx.group(2))) if idx else (1, 1)
    noise = {"PATCH", "RFC", "RESEND", "GIT", "PULL"}
    tree = next((w for w in words if w.upper() not in noise and not VERSION_RE.fullmatch(w) and not INDEX_RE.fullmatch(w)), "")
    # "net: bcmgenet: allow X" -> subsystem "net", detail "bcmgenet"
    parts = [p.strip() for p in rest.split(":")]
    subsystem = parts[0].lower() if len(parts) > 1 and len(parts[0]) <= 40 and " " not in parts[0] else ""
    # series identity: author-independent prefix of the summary, without revision/index
    normalized = re.sub(r"\W+", " ", rest.lower()).strip()[:60]
    series_key = f"{tree}|{subsystem}|{total}|{normalized}" if index == 0 else ""
    return Subject(
        is_reply=bool(m.group("reply")), kind=kind, version=version, index=index, total=total,
        tree=tree, subsystem=subsystem, summary=rest, series_key=series_key,
    )


@dataclass
class Message:
    author: str
    email: str
    title: str
    updated: str
    url: str
    msgid: str
    in_reply_to: str
    body: str
    subject: Subject = field(init=False)

    def __post_init__(self):
        self.subject = parse_subject(self.title)

    @property
    def own_text(self):
        """The message body without quoted lines from earlier mails."""
        return QUOTE_RE.sub("", self.body)

    @property
    def trailers(self):
        # canonical kernel spelling: "Reviewed-by", "Acked-by", ...
        return [(tag.capitalize(), name.strip()) for tag, name in TRAILER_RE.findall(self.own_text)]

    @property
    def has_diff(self):
        return "diff --git" in self.body or "\n+++ b/" in self.body


def parse_feed(xml_text):
    root = ET.fromstring(xml_text)
    messages = []
    for e in root.findall("a:entry", NS):
        content = e.find("a:content", NS)
        # lore wraps the plain-text mail in xhtml <pre>; flatten it back to text
        body = html.unescape("".join(content.itertext())) if content is not None else ""
        reply = e.find("thr:in-reply-to", NS)
        messages.append(Message(
            author=(e.findtext("a:author/a:name", "", NS) or "").strip(),
            email=(e.findtext("a:author/a:email", "", NS) or "").strip(),
            title=(e.findtext("a:title", "", NS) or "").strip(),
            updated=e.findtext("a:updated", "", NS),
            url=e.find("a:link", NS).get("href") if e.find("a:link", NS) is not None else "",
            msgid=e.findtext("a:id", "", NS),
            in_reply_to=reply.get("ref", "") if reply is not None else "",
            body=body,
        ))
    return messages


def fetch(list_name, query, pages, delay=1.0):
    messages = []
    for page in range(pages):
        params = urllib.parse.urlencode({"q": query, "x": "A", "o": page * PAGE_SIZE})
        url = f"{LORE}/{list_name}/?{params}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as resp:
            batch = parse_feed(resp.read())
        print(f"fetched {url} -> {len(batch)} messages", file=sys.stderr)
        messages += batch
        if len(batch) < PAGE_SIZE:
            break
        time.sleep(delay)  # be gentle with kernel.org
    return messages


def analyze(messages, top=10):
    patches = [m for m in messages if m.subject.kind in ("PATCH", "RFC PATCH") and not m.subject.is_reply]
    replies = [m for m in messages if m.subject.is_reply]

    subsystems = Counter(m.subject.subsystem for m in messages if m.subject.subsystem)
    trees = Counter(m.subject.tree for m in patches if m.subject.tree)
    posters = Counter(m.author for m in messages)
    patch_authors = Counter(m.author for m in patches)

    reviewers = defaultdict(Counter)
    for m in replies:
        for tag, _name in m.trailers:
            reviewers[tag][m.author] += 1

    # Series = cover letters (0/N) and single patches; track the highest revision seen
    series = {}
    for m in patches:
        s = m.subject
        if s.total > 1 and s.index != 0:
            continue
        key = s.series_key or f"{s.tree}|{s.subsystem}|{s.summary.lower()}"
        cur = series.get(key)
        if cur is None or s.version > cur["version"]:
            series[key] = {"title": m.title, "author": m.author, "version": s.version, "patches": s.total, "url": m.url}

    # Group messages into threads by subject with the "Re:" stripped (the thread
    # root is often older than the fetched window, so reply chains are incomplete)
    threads = defaultdict(list)
    for m in messages:
        threads[re.sub(r"^((re|fwd?|aw):\s*)+", "", m.title, flags=re.IGNORECASE).strip()].append(m)
    hot = []
    for title, msgs in sorted(threads.items(), key=lambda t: -len(t[1]))[:top]:
        people = Counter(m.author for m in msgs)
        hot.append({"messages": len(msgs), "participants": len(people), "title": title, "url": msgs[-1].url})

    kinds = Counter(m.subject.kind or "discussion" for m in messages if not m.subject.is_reply)
    regressions = [{"title": m.title, "author": m.author, "url": m.url} for m in messages if m.subject.kind == "REGRESSION" and not m.subject.is_reply]

    return {
        "messages": len(messages),
        "replies": len(replies),
        "new_threads": len(messages) - len(replies),
        "with_diff": sum(m.has_diff for m in messages),
        "kinds": dict(kinds.most_common()),
        "subsystems": subsystems.most_common(top),
        "trees": trees.most_common(top),
        "top_posters": posters.most_common(top),
        "top_patch_authors": patch_authors.most_common(top),
        "reviews": {tag: c.most_common(top) for tag, c in sorted(reviewers.items())},
        "series": sorted(series.values(), key=lambda s: (-s["version"], -s["patches"]))[:top],
        "hot_threads": hot,
        "regressions": regressions[:top],
        "window": [min((m.updated for m in messages), default=""), max((m.updated for m in messages), default="")],
    }


def print_report(r):
    def table(title, rows, fmt):
        if not rows:
            return
        print(f"\n{title}")
        for row in rows:
            print("  " + fmt(row))

    print(f"{r['messages']} messages ({r['new_threads']} new threads, {r['replies']} replies, {r['with_diff']} carrying a diff)")
    print(f"window: {r['window'][0]} .. {r['window'][1]}")
    print("new threads by kind: " + ", ".join(f"{k} {v}" for k, v in r["kinds"].items()))
    table("Busiest subsystems", r["subsystems"], lambda t: f"{t[1]:5d}  {t[0]}")
    table("Target trees", r["trees"], lambda t: f"{t[1]:5d}  {t[0]}")
    table("Most active posters", r["top_posters"], lambda t: f"{t[1]:5d}  {t[0]}")
    table("Most patches sent", r["top_patch_authors"], lambda t: f"{t[1]:5d}  {t[0]}")
    for tag, rows in r["reviews"].items():
        table(f"{tag} given", rows, lambda t: f"{t[1]:5d}  {t[0]}")
    table("Series on the highest revision", r["series"], lambda s: f"v{s['version']:<3d}{s['patches']:>3d} patch(es)  {s['title'][:90]}  — {s['author']}")
    table("Hottest threads (messages / people)", r["hot_threads"], lambda t: f"{t['messages']:5d} / {t['participants']:<3d} {t['title'][:95]}")
    table("Regression reports", r["regressions"], lambda t: f"{t['title'][:100]}  — {t['author']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("report")
    p.add_argument("--list", default="lkml", help="lore list name (lkml, netdev, linux-mm, ...)")
    p.add_argument("--since", default="1.day.ago", help="lore date expression, e.g. 3.days.ago or 20261001")
    p.add_argument("--query", default="", help="extra lore search terms, e.g. 's:\"mm:\"' or 'f:torvalds'")
    p.add_argument("--pages", type=int, default=3, help=f"max pages of {PAGE_SIZE} messages")
    p.add_argument("--top", type=int, default=10)
    p.add_argument("--file", help="analyze a saved Atom feed instead of fetching")
    p.add_argument("--save", help="also save the fetched messages as JSON")
    p.add_argument("--json", action="store_true", help="print the report as JSON")
    args = parser.parse_args()

    if args.file:
        messages = parse_feed(Path(args.file).read_bytes())
    else:
        query = f"d:{args.since}.. {args.query}".strip()
        messages = fetch(args.list, query, args.pages)
    if args.save:
        Path(args.save).write_text(json.dumps([{**asdict(m), "subject": asdict(m.subject)} for m in messages], indent=1))

    report = analyze(messages, args.top)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)


if __name__ == "__main__":
    main()
