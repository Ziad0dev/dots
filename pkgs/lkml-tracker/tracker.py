#!/usr/bin/env python3
"""Local dashboard tracking Linux kernel and Nix development.

Serves a single page plus a small JSON API that pulls from public sources:

    /api/system     this machine: running kernel, NixOS revision, Nix version
    /api/kernel     kernel.org releases vs. nixpkgs master, and where mainline is in its cycle
    /api/channels   NixOS channel revisions and when each last advanced
    /api/lkml       LKML report and threads over a rolling 24h window
    /api/kernel-prs nixpkgs pull requests labelled "6.topic: kernel"
    /api/discourse  latest topics on discourse.nixos.org
    /api/nix        latest Nix releases
    /api/zig        Zig releases, master builds, breaking changes and proposals (Codeberg)
    /api/ziggit     latest topics on ziggit.dev, the Zig community forum
    /api/tinygrad   tinygrad releases, merged and open PRs, bounties (GitHub)

    python3 tracker.py                      # http://127.0.0.1:8080
    python3 tracker.py --port 9000 --lkml-pages 5
    GITHUB_TOKEN=... python3 tracker.py     # higher GitHub API rate limit

Responses are cached in memory (see TTL) so reloading the page doesn't hammer
the upstreams; append ?refresh=1 to an API URL to force a fetch.
Standard library only.
"""
import argparse
import html
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import lkml

USER_AGENT = "lkml-tracker/0.2 (+https://github.com/Ziad0dev/LKML)"
STATIC = Path(__file__).parent / "static"
KERNEL_RELEASES = "https://www.kernel.org/releases.json"
NIXPKGS_KERNELS = "https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/os-specific/linux/kernel/kernels-org.json"
PROMETHEUS = "https://prometheus.nixos.org/api/v1/query"
GITHUB = "https://api.github.com"
DISCOURSE = "https://discourse.nixos.org"
ZIGGIT = "https://ziggit.dev"
ZIG_INDEX = "https://ziglang.org/download/index.json"
CODEBERG = "https://codeberg.org/api/v1"
REPOLOGY = "https://repology.org/api/v1/project"
TINYGRAD = "/repos/tinygrad/tinygrad"
BOUNTY_SHEET = "https://docs.google.com/spreadsheets/d/1WKHbT-7KOgjEawq5h5Ic1qUWzpfAzuD_J06N1JwOCGs/edit?usp=sharing"
LKML_WINDOW = timedelta(hours=24)

# seconds each source stays cached
TTL = {"system": 60, "kernel": 900, "channels": 600, "lkml": 1200, "kernel-prs": 600, "discourse": 600, "nix": 3600,
       "zig": 1800, "ziggit": 900, "tinygrad": 1800}


def get(url, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, **(headers or {})})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def get_json(url, headers=None):
    return json.loads(get(url, headers))


def github(path):
    headers = {"Accept": "application/vnd.github+json"}
    if os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['GITHUB_TOKEN']}"
    return get_json(GITHUB + path, headers)


def codeberg(path):
    return get_json(CODEBERG + path)


def version_key(v):
    return tuple(int(n) for n in re.findall(r"\d+", v))


def repology_nixpkgs(project):
    """Newest version of a project in nixpkgs unstable, per repology; "" if unknown."""
    try:
        versions = [r["version"] for r in get_json(f"{REPOLOGY}/{project}") if r["repo"] == "nix_unstable"]
    except Exception as e:  # repology is rate limited and sometimes slow; this is a nice-to-have
        print(f"repology {project}: {e}", file=sys.stderr)
        return ""
    return max(versions, key=version_key, default="")


def parse_time(iso):
    return datetime.fromisoformat(iso.replace("Z", "+00:00"))


def branch_of(version):
    """'6.12.112' -> '6.12', '7.3-rc7' -> '7.3'."""
    m = re.match(r"(\d+\.\d+)", version)
    return m.group(1) if m else version


def kernel_cycle(version, released, today=None):
    """Where mainline is in its ~9 week cycle: 2 week merge window, then weekly rcs.

    Linus tags each rc on a Sunday and usually releases after rc7, sometimes rc8.
    """
    released = date.fromisoformat(released)
    since = ((today or date.today()) - released).days
    m = re.match(r"(\d+)\.(\d+)(?:-rc(\d+))?$", version)
    major, minor, rc = int(m.group(1)), int(m.group(2)), m.group(3)
    if rc is None:
        # a fresh release opens the merge window for the next version
        return {
            "phase": "merge-window", "version": version, "next": f"{major}.{minor + 1}", "rc": 0,
            "next_event": f"{major}.{minor + 1}-rc1", "next_date": (released + timedelta(days=14)).isoformat(),
            "progress": min(max(since, 0), 14) / 63,
        }
    rc = int(rc)
    final = released + timedelta(days=7 * (max(7 - rc, 0) + 1))
    return {
        "phase": "rc", "version": version, "next": f"{major}.{minor}", "rc": rc,
        "next_event": f"{major}.{minor}" if rc >= 7 else f"{major}.{minor}-rc{rc + 1}",
        "next_date": (released + timedelta(days=7)).isoformat(), "final_date": final.isoformat(),
        "progress": min((14 + 7 * (rc - 1) + min(since, 7)) / 63, 1),
    }


def compare_kernels(releases, nixpkgs):
    """Line up kernel.org releases with nixpkgs' kernels-org.json.

    nixpkgs keys stable branches by "major.minor" and the mainline rc as "testing".
    """
    rows, cycle = [], None
    for r in releases["releases"]:
        if r["moniker"] == "linux-next":
            continue
        if r["moniker"] == "mainline":
            cycle = kernel_cycle(r["version"], r["released"]["isodate"])
        key = "testing" if r["moniker"] == "mainline" else branch_of(r["version"])
        nix = nixpkgs.get(key, {}).get("version", "")
        status = "missing" if not nix else "current" if nix == r["version"] else "behind"
        rows.append({
            "moniker": r["moniker"], "branch": key, "version": r["version"],
            "released": r["released"]["isodate"], "eol": r["iseol"],
            "nixpkgs": nix, "status": status, "gitweb": r.get("gitweb") or "",
        })
    return {"latest_stable": releases.get("latest_stable", {}).get("version", ""), "cycle": cycle, "branches": rows}


def parse_channels(revisions, update_times):
    """Merge Prometheus channel_revision and channel_update_time vectors."""
    updated = {r["metric"]["channel"]: int(float(r["value"][1])) for r in update_times["data"]["result"]}
    rows = []
    for r in revisions["data"]["result"]:
        m = r["metric"]
        if m.get("current") != "1":
            continue
        ts = updated.get(m["channel"])
        rows.append({
            "channel": m["channel"], "status": m.get("status", ""), "variant": m.get("variant", ""),
            "revision": m["revision"],
            "updated": datetime.fromtimestamp(ts, timezone.utc).isoformat() if ts else "",
            "age_hours": round((time.time() - ts) / 3600, 1) if ts else None,
        })
    order = {"rolling": 0, "stable": 1, "beta": 2}
    return sorted(rows, key=lambda r: (order.get(r["status"], 9), r["channel"]))


def parse_prs(search):
    return [{
        "number": i["number"], "title": i["title"], "url": i["html_url"], "author": i["user"]["login"],
        "state": "merged" if i.get("pull_request", {}).get("merged_at") else i["state"],
        "updated": i["updated_at"], "comments": i["comments"],
        "labels": [l["name"] for l in i["labels"] if not l["name"].startswith("10.rebuild")],
    } for i in search["items"]]


def parse_discourse(latest, base=DISCOURSE, categories=None):
    return [{
        "title": t["title"], "url": f"{base}/t/{t['slug']}/{t['id']}", "posts": t["posts_count"],
        "views": t["views"], "likes": t.get("like_count", 0), "last_posted": t.get("last_posted_at") or "",
        "created": t.get("created_at") or "", "pinned": t.get("pinned", False),
        "category": (categories or {}).get(t.get("category_id"), ""),
    } for t in latest["topic_list"]["topics"]]


def parse_zig_index(index):
    """ziglang.org/download/index.json: the master build plus tagged releases, newest first."""
    master = index["master"]
    releases = [{"version": v, "date": r.get("date", ""), "notes": r.get("notes", ""), "docs": r.get("docs", "")}
                for v, r in index.items() if v != "master"]
    return {
        "master": {"version": master["version"], "date": master.get("date", ""),
                   "docs": master.get("docs", ""), "std_docs": master.get("stdDocs", "")},
        "releases": sorted(releases, key=lambda r: version_key(r["version"]), reverse=True),
    }


def parse_forgejo_issue(i):
    """A Codeberg (Forgejo) issue or pull request."""
    pr = i.get("pull_request") or {}
    return {
        "number": i["number"], "title": i["title"], "url": i["html_url"], "author": i["user"]["login"],
        "labels": [l["name"] for l in i["labels"]], "comments": i.get("comments", 0),
        "updated": i["updated_at"], "merged_at": i.get("merged_at") or pr.get("merged_at") or "",
    }


def parse_gh_pull(p):
    return {
        "number": p["number"], "title": p["title"], "url": p["html_url"], "author": p["user"]["login"],
        "labels": [l["name"] for l in p["labels"]], "draft": p.get("draft", False),
        "updated": p["updated_at"], "merged_at": p.get("merged_at") or "",
    }


ADVISORY_RE = re.compile(r"security|advisory|\bcve\b", re.IGNORECASE)


def parse_fixed(text):
    """Fixed versions per product from an advisory post, e.g. {"nix": ["2.35.3", "2.34.9"]}.

    The Nix/Lix advisories list each product as a heading line followed by
    "Affected versions: ..." and "Fixed versions: ..." lines.
    """
    fixed = {}
    for product in ("Nix", "Lix"):
        m = re.search(rf"(?:^|\n)\s*{product}\s*\n\s*Affected versions:[^\n]*\n\s*Fixed versions:\s*([^\n]+)", text)
        if m:
            fixed[product.lower()] = re.findall(r"\d+\.\d+\.\d+", m.group(1))
    return fixed


def threads_of(messages):
    """Every thread in the window, keyed like lkml.analyze's hot threads (subject without Re:)."""
    groups = defaultdict(list)
    for m in messages:
        groups[re.sub(r"^((re|fwd?|aw):\s*)+", "", m.title, flags=re.IGNORECASE).strip()].append(m)
    rows = []
    for title, msgs in groups.items():
        root = next((m for m in msgs if not m.subject.is_reply), msgs[0])
        s = lkml.parse_subject(title)
        rows.append({
            "title": title, "url": root.url, "subsystem": s.subsystem, "kind": s.kind or "discussion",
            "tree": s.tree, "version": s.version, "messages": len(msgs),
            "participants": len({m.author for m in msgs}), "author": root.author,
            "latest": max(m.updated for m in msgs),
            "reviewed": sorted({tag for m in msgs if m.subject.is_reply for tag, _ in m.trailers}),
        })
    return sorted(rows, key=lambda t: (t["messages"], t["latest"]), reverse=True)


def merge_window(known, new, now):
    """Add freshly fetched lore messages to the rolling window and drop expired ones."""
    for m in new:
        known[m.msgid] = m
    cutoff = now - LKML_WINDOW
    for msgid in [k for k, m in known.items() if not m.updated or parse_time(m.updated) < cutoff]:
        del known[msgid]
    return known


def system_info():
    """What this machine runs, for comparing against upstream."""
    info = {"kernel": os.uname().release, "nixos": "", "nixos_rev": "", "nix": ""}
    try:
        info["nixos"] = Path("/run/current-system/nixos-version").read_text().strip()
        # 26.11.20261014.55bfb4d -> 55bfb4d
        info["nixos_rev"] = info["nixos"].rsplit(".", 1)[-1]
    except OSError:
        pass
    try:
        nix = "/run/current-system/sw/bin/nix" if Path("/run/current-system/sw/bin/nix").exists() else "nix"
        out = subprocess.run([nix, "--version"], capture_output=True, text=True, timeout=10).stdout
        info["nix"] = out.split()[-1] if out else ""
    except (OSError, subprocess.SubprocessError):
        pass
    return info


class Sources:
    def __init__(self, lkml_list="lkml", lkml_pages=3):
        self.lkml_list = lkml_list
        self.lkml_pages = lkml_pages
        self.lkml_messages = {}  # msgid -> Message, the rolling 24h window
        self.cache = {}
        self.locks = {name: threading.Lock() for name in TTL}

    def system(self):
        return system_info()

    def kernel(self):
        return compare_kernels(get_json(KERNEL_RELEASES), get_json(NIXPKGS_KERNELS))

    def channels(self):
        q = lambda expr: get_json(f"{PROMETHEUS}?{urllib.parse.urlencode({'query': expr})}")
        return parse_channels(q("channel_revision"), q("channel_update_time"))

    def lkml(self):
        # the first fetch backfills a few pages; afterwards the newest page per
        # refresh is enough (LKML moves ~200 messages an hour, TTL is 20 minutes)
        pages = 1 if self.lkml_messages else self.lkml_pages
        merge_window(self.lkml_messages, lkml.fetch(self.lkml_list, "d:1.day.ago..", pages), datetime.now(timezone.utc))
        messages = sorted(self.lkml_messages.values(), key=lambda m: m.updated)
        report = lkml.analyze(messages, top=10)
        report["subsystems"] = Counter(m.subject.subsystem for m in messages if m.subject.subsystem).most_common(40)
        return {"list": self.lkml_list, **report, "threads": threads_of(messages)[:2000]}

    def kernel_prs(self):
        q = urllib.parse.quote('repo:NixOS/nixpkgs is:pr label:"6.topic: kernel"')
        return parse_prs(github(f"/search/issues?q={q}&sort=updated&order=desc&per_page=20"))

    def discourse(self):
        topics = parse_discourse(get_json(f"{DISCOURSE}/latest.json"))[:30]
        recent = datetime.now(timezone.utc) - timedelta(days=30)
        for t in topics:
            if ADVISORY_RE.search(t["title"]) and t["created"] and parse_time(t["created"]) > recent:
                # read the advisory itself so the page can say whether this machine is patched
                try:
                    post = get_json(f"{t['url']}.json")["post_stream"]["posts"][0]["cooked"]
                    t["fixed"] = parse_fixed(html.unescape(re.sub(r"<[^>]+>", "", post)))
                except Exception as e:
                    print(f"advisory {t['url']}: {e}", file=sys.stderr)
        return topics

    def nix(self):
        return [{"tag": t["name"], "url": f"https://github.com/NixOS/nix/releases/tag/{t['name']}"}
                for t in github("/repos/NixOS/nix/tags?per_page=8")]

    def zig(self):
        merged = [parse_forgejo_issue(p) for p in codeberg("/repos/ziglang/zig/pulls?state=closed&sort=recentupdate&limit=50") if p.get("merged")]
        breaking = [parse_forgejo_issue(p) for p in codeberg("/repos/ziglang/zig/issues?type=pulls&state=closed&labels=breaking&limit=15")
                    if (p.get("pull_request") or {}).get("merged")]
        proposals = [parse_forgejo_issue(i) for i in codeberg("/repos/ziglang/zig/issues?type=issues&state=open&labels=accepted&sort=recentupdate&limit=30")
                     if any(l["name"] == "proposal" for l in i["labels"])]
        repo = codeberg("/repos/ziglang/zig")
        return {
            **parse_zig_index(get_json(ZIG_INDEX)),
            "nixpkgs": repology_nixpkgs("zig"),
            "repo": {"url": repo["html_url"], "stars": repo["stars_count"], "open_issues": repo["open_issues_count"], "open_prs": repo["open_pr_counter"]},
            "merged": sorted(merged, key=lambda p: p["merged_at"], reverse=True)[:25],
            "breaking": sorted(breaking, key=lambda p: p["merged_at"], reverse=True)[:12],
            "proposals": proposals[:12],
        }

    def ziggit(self):
        categories = {c["id"]: c["name"] for c in get_json(f"{ZIGGIT}/categories.json")["category_list"]["categories"]}
        return parse_discourse(get_json(f"{ZIGGIT}/latest.json"), ZIGGIT, categories)[:30]

    def tinygrad(self):
        merged = [parse_gh_pull(p) for p in github(f"{TINYGRAD}/pulls?state=closed&sort=updated&direction=desc&per_page=60") if p["merged_at"]]
        issues = lambda label: [{
            "number": i["number"], "title": i["title"], "url": i["html_url"], "author": i["user"]["login"],
            "updated": i["updated_at"], "comments": i["comments"], "is_pr": "pull_request" in i,
        } for i in github(f"{TINYGRAD}/issues?state=open&sort=updated&per_page=15&labels={urllib.parse.quote(label)}")]
        releases = github(f"{TINYGRAD}/releases?per_page=3")
        return {
            "releases": [{"tag": r["tag_name"], "date": r["published_at"], "url": r["html_url"]} for r in releases],
            "nixpkgs": repology_nixpkgs("python:tinygrad"),
            "merged": sorted(merged, key=lambda p: p["merged_at"], reverse=True)[:30],
            "open": [parse_gh_pull(p) for p in github(f"{TINYGRAD}/pulls?state=open&sort=updated&direction=desc&per_page=20")],
            # the bounties themselves live in a spreadsheet (BOUNTY_SHEET); on GitHub
            # "bounty locked" marks the PRs currently claiming one
            "bounties_claimed": issues("bounty locked"),
            "bounty_sheet": BOUNTY_SHEET,
        }

    def load(self, name, refresh=False):
        """Return (payload, fetched_at), using the cache within the source's TTL.

        One lock per source, so concurrent page loads trigger a single upstream fetch.
        """
        with self.locks[name]:
            hit = self.cache.get(name)
            if hit and not refresh and time.time() - hit[1] < TTL[name]:
                return hit
            data = getattr(self, name.replace("-", "_"))()
            self.cache[name] = (data, time.time())
            return self.cache[name]


def make_handler(sources):
    class Handler(BaseHTTPRequestHandler):
        def send(self, code, body, ctype):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path in ("/", "/index.html"):
                return self.send(200, (STATIC / "index.html").read_bytes(), "text/html; charset=utf-8")
            name = url.path.removeprefix("/api/")
            if not url.path.startswith("/api/") or name not in TTL:
                return self.send(404, b"not found", "text/plain")
            refresh = "refresh" in urllib.parse.parse_qs(url.query)
            try:
                data, fetched = sources.load(name, refresh)
                body = {"data": data, "fetched": datetime.fromtimestamp(fetched, timezone.utc).isoformat()}
                code = 200
            except Exception as e:  # upstream down, rate limited, ... -> show it on the page
                body, code = {"error": f"{type(e).__name__}: {e}"}, 502
            self.send(code, json.dumps(body).encode(), "application/json")

        def log_message(self, fmt, *args):
            print(f"{self.address_string()} {fmt % args}", file=sys.stderr)

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--lkml-list", default="lkml", help="lore list for the LKML views")
    parser.add_argument("--lkml-pages", type=int, default=3, help=f"pages of {lkml.PAGE_SIZE} lore messages to backfill at start")
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), make_handler(Sources(args.lkml_list, args.lkml_pages)))
    print(f"serving on http://{args.host}:{args.port}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
