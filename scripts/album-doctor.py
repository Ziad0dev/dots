#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

import musicbrainzngs
import mutagen

AUDIO = {".flac", ".mp3", ".m4a", ".ogg", ".opus", ".wav", ".wv", ".aiff"}
LOSSLESS = {".flac", ".wav", ".wv", ".aiff"}
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "album-doctor"

musicbrainzngs.set_useragent("album-doctor", "1.0", "https://github.com/Ziad0dev/dots")


def norm(s):
    s = unicodedata.normalize("NFKD", s or "").casefold()
    s = re.sub(r"\(.*?\)|\[.*?\]", " ", s)
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def first(tags, *keys):
    for k in keys:
        v = tags.get(k)
        if v:
            return str(v[0]) if isinstance(v, list) else str(v)
    return ""


def parse_pos(raw):
    if not raw:
        return None
    m = re.match(r"\s*(\d+)", str(raw))
    return int(m.group(1)) if m else None


def parse_total(raw):
    m = re.search(r"/\s*(\d+)", str(raw or ""))
    return int(m.group(1)) if m else None


def read_track(path):
    try:
        f = mutagen.File(path, easy=True)
    except Exception:
        return None
    if f is None:
        return None
    t = f.tags or {}
    num = first(t, "tracknumber")
    return {
        "path": path,
        "album": first(t, "album"),
        "artist": first(t, "albumartist", "artist"),
        "title": first(t, "title"),
        "track": parse_pos(num) or parse_pos(path.stem),
        "total": parse_total(num) or parse_pos(first(t, "tracktotal", "totaltracks")),
        "disc": parse_pos(first(t, "discnumber")) or 1,
        "mbid": first(t, "musicbrainz_albumid"),
    }


def scan(root):
    out = []
    for dirpath, _, files in os.walk(root):
        for name in files:
            f = Path(dirpath) / name
            if f.suffix.lower() in AUDIO:
                tr = read_track(f)
                if tr:
                    out.append(tr)
    return out


def group(tracks):
    albums = defaultdict(list)
    for t in tracks:
        key = t["mbid"] or (norm(t["artist"]), norm(t["album"]) or t["path"].parent.name)
        albums[key].append(t)
    return albums


def mixed_dirs(albums, threshold):
    per_dir = defaultdict(set)
    for key, tracks in albums.items():
        for t in tracks:
            per_dir[t["path"].parent].add(key)
    return {d for d, keys in per_dir.items() if len(keys) >= threshold}


def summarise(tracks):
    def common(key, fallback=""):
        counts = defaultdict(int)
        for t in tracks:
            if t[key]:
                counts[t[key]] += 1
        return max(counts, key=counts.get) if counts else fallback

    exts = {t["path"].suffix.lower() for t in tracks}
    titled = [t for t in tracks if t["title"]]
    return {
        "album": common("album"),
        "artist": common("artist"),
        "mbid": common("mbid"),
        "dirs": sorted({t["path"].parent for t in tracks}),
        "count": len(tracks),
        "titles": {norm(t["title"]) for t in titled},
        "titled": len(titled),
        "pos": {(t["disc"], t["track"]) for t in tracks if t["track"]},
        "flat": {t["track"] for t in tracks if t["track"]},
        "total": common("total", None),
        "lossless": bool(exts & LOSSLESS),
        "ext": min(exts).lstrip(".") if exts else "flac",
    }


def cached(key, fn):
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / (re.sub(r"[^A-Za-z0-9]+", "_", key)[:180] + ".json")
    if f.exists():
        return json.loads(f.read_text())
    val = fn()
    if val is not None:
        f.write_text(json.dumps(val))
    return val


def release_tracklist(mbid):
    def fetch_it():
        try:
            r = musicbrainzngs.get_release_by_id(mbid, includes=["recordings", "media"])
        except Exception as e:
            print(f"    mb lookup failed for {mbid}: {e}", file=sys.stderr)
            return None
        out = []
        for d, medium in enumerate(r["release"].get("medium-list", []), start=1):
            for t in medium.get("track-list", []):
                try:
                    pos = int(t["position"])
                except (KeyError, TypeError, ValueError):
                    continue
                title = t.get("recording", {}).get("title") or t.get("title") or ""
                out.append({"disc": int(medium.get("position", d)), "track": pos, "title": title})
        return out or None

    return cached("rel-" + mbid, fetch_it)


def find_release(artist, album, seen):
    def fetch_it():
        try:
            res = musicbrainzngs.search_releases(
                artist=artist, release=album, limit=8, strict=False
            )
        except Exception:
            return None
        best = None
        for r in res.get("release-list", []):
            if norm(r.get("title")) != norm(album):
                continue
            count = sum(int(m.get("track-count", 0)) for m in r.get("medium-list", []))
            if count < seen:
                continue
            score = (count == seen, -abs(count - seen), int(r.get("ext:score", 0)))
            if best is None or score > best[0]:
                best = (score, r["id"])
        return best[1] if best else None

    return cached(f"search-{norm(artist)}-{norm(album)}-{seen}", fetch_it)


def by_title(info, expected):
    return [t for t in expected if norm(t["title"]) not in info["titles"]]


def by_position(info, expected):
    discs = {t["disc"] for t in expected}
    if len(discs) > 1 and len({d for d, _ in info["pos"]}) == 1:
        return [t for i, t in enumerate(expected, start=1) if i not in info["flat"]]
    return [t for t in expected if (t["disc"], t["track"]) not in info["pos"]]


def diagnose(info, use_mb):
    if not info["album"]:
        return None

    mbid = info["mbid"] or (
        find_release(info["artist"], info["album"], info["count"]) if use_mb else None
    )
    expected = release_tracklist(mbid) if mbid else None

    if expected:
        if info["count"] >= len(expected):
            return None
        titles = [norm(t["title"]) for t in expected]
        usable = all(titles) and len(set(titles)) == len(titles)
        reliable = usable and info["titled"] >= info["count"] * 0.8
        missing = by_title(info, expected) if reliable else by_position(info, expected)
        if not missing:
            return None
        return {
            "source": "musicbrainz" if reliable else "musicbrainz/pos",
            "expected": len(expected),
            "missing": missing,
        }

    total = info["total"]
    if not total or not 2 <= total <= 30 or info["count"] >= total:
        return None
    if info["count"] * 3 < total:
        return None
    missing = [
        {"disc": 1, "track": n, "title": ""}
        for n in range(1, total + 1)
        if n not in info["flat"]
    ]
    return {"source": "tags", "expected": total, "missing": missing} if missing else None


def slsk(args, check=False):
    return subprocess.run(
        ["soulseek-rs", *args], capture_output=True, text=True, check=check
    )


def require_daemon():
    if slsk(["daemon", "status", "--json"]).returncode != 0:
        sys.exit(
            "no soulseek-rs daemon: systemctl --user start soulseek-rs\n"
            "(batch work needs one; the server allows a single session per account)"
        )


def search(query, ext, lossless):
    args = ["search", query, "--json", "--free-slots"]
    if lossless:
        args += ["--extension", ext]
    else:
        args += ["--min-bitrate", "320"]
    r = slsk(args)
    if r.returncode not in (0, 4):
        return []
    hits = []
    for line in r.stdout.splitlines():
        try:
            hits.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return hits


def pick(hits, title):
    wanted = norm(title)
    scored = []
    for h in hits:
        stem = norm(Path(h.get("path", "")).stem)
        if wanted and wanted not in stem:
            continue
        scored.append((h.get("free_slot", False), h.get("size", 0), h.get("speed", 0), h))
    if not scored:
        return None
    scored.sort(key=lambda s: s[:3], reverse=True)
    return scored[0][3]


def fetch(info, report, dest, execute):
    got = 0
    for want in report["missing"]:
        title = want["title"]
        label = title or f"track {want['track']}"
        if not title:
            print(f"    skip {label}: no title, nothing to search for")
            continue

        artist = info["artist"]
        if norm(artist) in {"various artists", "various", "va", "soundtrack"}:
            artist = ""
        queries = [
            f"{artist} {info['album']} {title}",
            f"{info['album']} {title}",
            f"{artist} {title}",
        ]
        hits = []
        for q in queries:
            q = " ".join(q.split())
            if not q:
                continue
            hits = search(q, info["ext"], info["lossless"])
            if hits:
                break
        choice = pick(hits, title)
        if not choice:
            print(f"    miss {label}")
            continue

        print(f"    {'get ' if execute else 'find'} {label}  <- {choice['user']}")
        if not execute:
            got += 1
            continue

        target = dest / info["artist"] / info["album"]
        target.mkdir(parents=True, exist_ok=True)
        r = subprocess.run(
            ["soulseek-rs", "download", "--stdin", "--download-dir", str(target)],
            input=json.dumps(choice) + "\n",
            check=False,
            capture_output=True,
            text=True,
        )
        if r.returncode == 0:
            got += 1
        else:
            print(f"    fail {label}: exit {r.returncode}")
    return got


def main():
    ap = argparse.ArgumentParser(description="find and fill gaps in album directories")
    ap.add_argument("--library", type=Path, default=Path("/mnt/media/music"))
    ap.add_argument("--staging", type=Path, default=Path("/mnt/media/incoming"))
    ap.add_argument("--filter", default="", help="only albums whose path matches this")
    ap.add_argument("--exclude", action="append", default=[], help="skip albums whose path matches")
    ap.add_argument("--no-musicbrainz", action="store_true", help="trust tags only")
    ap.add_argument("--min-have", type=int, default=2, help="ignore folders with fewer tracks")
    ap.add_argument("--mixed-threshold", type=int, default=4,
                    help="a folder holding this many albums is a playlist, not an album")
    ap.add_argument("--include-mixed", action="store_true", help="scan playlist folders too")
    ap.add_argument("--fetch", action="store_true", help="search soulseek for what is missing")
    ap.add_argument("--go", action="store_true", help="actually download; implies --fetch")
    args = ap.parse_args()

    if args.go:
        args.fetch = True
    if args.fetch:
        require_daemon()

    albums = group(scan(args.library))
    if not albums:
        sys.exit(f"no audio found under {args.library}")

    playlists = set() if args.include_mixed else mixed_dirs(albums, args.mixed_threshold)

    incomplete = 0
    queued = 0
    for key in sorted(albums, key=str):
        info = summarise(albums[key])
        if playlists and all(d in playlists for d in info["dirs"]):
            continue
        if any(
            x.lower() in str(d).lower() for x in args.exclude for d in info["dirs"]
        ):
            continue
        if args.filter and not any(
            args.filter.lower() in str(d).lower() for d in info["dirs"]
        ):
            continue
        if info["count"] < args.min_have:
            continue
        report = diagnose(info, not args.no_musicbrainz)
        if not report:
            continue

        incomplete += 1
        print(
            f"{info['artist']} - {info['album']}  "
            f"[{info['count']}/{report['expected']}, {report['source']}]"
        )
        print(f"    {info['dirs'][0]}" + (f" (+{len(info['dirs']) - 1} more)" if len(info["dirs"]) > 1 else ""))
        if args.fetch:
            queued += fetch(info, report, args.staging, args.go)
        else:
            for want in report["missing"]:
                print(f"    {want['disc']}-{want['track']:02d}  {want['title'] or '?'}")

    verb = "downloaded" if args.go else "findable"
    print(f"\n{incomplete} incomplete album(s)" + (f", {queued} {verb}" if args.fetch else ""))
    return 0 if incomplete == 0 else 4


if __name__ == "__main__":
    sys.exit(main())
