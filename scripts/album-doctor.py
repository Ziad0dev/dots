#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

import musicbrainzngs
import mutagen

UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)
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
        "mbid": (lambda v: v if UUID.match(v) else "")(first(t, "musicbrainz_albumid")),
    }


def open_index():
    CACHE.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(CACHE / "index.sqlite")
    db.execute(
        "CREATE TABLE IF NOT EXISTS files "
        "(path TEXT PRIMARY KEY, mtime REAL, size INTEGER, tags TEXT)"
    )
    return db


def scan(root, db=None, verbose=False):
    db = db or open_index()
    known = {r[0]: r for r in db.execute("SELECT path, mtime, size, tags FROM files")}
    out, fresh, seen = [], 0, set()
    for dirpath, _, files in os.walk(root):
        for name in files:
            f = Path(dirpath) / name
            if f.suffix.lower() not in AUDIO:
                continue
            key = str(f)
            seen.add(key)
            try:
                st = f.stat()
            except OSError:
                continue
            row = known.get(key)
            if row and row[1] == st.st_mtime and row[2] == st.st_size:
                tr = json.loads(row[3])
            else:
                tr = read_track(f)
                if tr is None:
                    continue
                tr = {k: v for k, v in tr.items() if k != "path"}
                db.execute(
                    "INSERT OR REPLACE INTO files VALUES (?,?,?,?)",
                    (key, st.st_mtime, st.st_size, json.dumps(tr)),
                )
                fresh += 1
                if fresh % 200 == 0:
                    db.commit()
            tr = dict(tr, path=f)
            out.append(tr)

    gone = [k for k in known if k not in seen and k.startswith(str(root))]
    for k in gone:
        db.execute("DELETE FROM files WHERE path = ?", (k,))
    db.commit()
    if verbose:
        print(f"{len(out)} tracks ({fresh} re-read, {len(gone)} gone)", file=sys.stderr)
    return out


def group(tracks, mixed=4):
    per_dir = defaultdict(list)
    for t in tracks:
        per_dir[t["path"].parent].append(t)

    albums = defaultdict(list)
    for d, items in per_dir.items():
        ids = {t["mbid"] or (norm(t["artist"]), norm(t["album"])) for t in items}
        ids.discard(("", ""))
        if len(ids) >= mixed:
            for t in items:
                albums[("loose", str(d), norm(t["album"]) or t["path"].stem)].append(t)
            continue
        ident = next(iter(ids)) if len(ids) == 1 else None
        for t in items:
            albums[ident or ("dir", str(d))].append(t)
    return albums


def is_loose(key):
    return isinstance(key, tuple) and key and key[0] == "loose"


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


def safe_name(name):
    name = re.sub(r'[:*?"<>|\\/\x00-\x1f]', " ", name or "")
    name = re.sub(r"\s+", " ", name).strip(" .")
    return name[:180] or "Unknown"


def replaced_log(add=None):
    f = CACHE / "replaced.json"
    try:
        cur = set(json.loads(f.read_text()))
    except Exception:
        cur = set()
    if add is not None:
        cur.add(str(add))
        CACHE.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps(sorted(cur)))
    return cur


def remote_parent(path):
    sep = "\\" if "\\" in path else "/"
    return path.rsplit(sep, 1)[0] if sep in path else ""


def folders(hits):
    out = defaultdict(list)
    for h in hits:
        path = h.get("path", "")
        if Path(path.replace("\\", "/")).suffix.lower() not in AUDIO:
            continue
        out[(h.get("user"), remote_parent(path))].append(h)
    return out


def pick_folder(hits, expected, lossless):
    best = None
    for (user, parent), items in folders(hits).items():
        n = len(items)
        if n < max(2, expected - 2):
            continue
        flac = sum(1 for h in items if h.get("path", "").lower().endswith(".flac"))
        score = (
            n >= expected,
            flac == n if lossless else True,
            -abs(n - expected),
            sum(1 for h in items if h.get("free_slot")),
            max((h.get("speed", 0) for h in items), default=0),
        )
        if best is None or score > best[0]:
            best = (score, user, parent, items)
    return best[1:] if best else None


def fetch_album(info, report, dest, execute, timeout=600):
    expected = report["expected"]
    for query in (f"{info['artist']} {info['album']}", info["album"]):
        query = " ".join(query.split())
        if not query:
            continue
        r = slsk(["search", query, "--json", "--sort", "best"])
        hits = []
        for line in r.stdout.splitlines():
            try:
                hits.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        choice = pick_folder(hits, expected, info["lossless"])
        if choice:
            user, parent, items = choice
            print(f"    {'get ' if execute else 'find'} folder {len(items)}/{expected} <- {user}")
            if not execute:
                return len(items)
            target = dest / safe_name(info["artist"]) / safe_name(info["album"])
            target.mkdir(parents=True, exist_ok=True)
            payload = "".join(json.dumps(h) + "\n" for h in items)
            out = subprocess.run(
                ["soulseek-rs", "download", "--stdin", "-t", str(timeout),
                 "--download-dir", str(target)],
                input=payload, capture_output=True, text=True, check=False,
            )
            if out.returncode == 0:
                for d in info["dirs"]:
                    replaced_log(d)
                return len(items)
            print(f"    fail folder: exit {out.returncode}")
            return 0
    print(f"    miss folder ({expected} tracks), falling back to tracks")
    return fetch(info, report, dest, execute, timeout)


def fetch(info, report, dest, execute, timeout=600):
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
            ["soulseek-rs", "download", "--stdin", "-t", str(timeout),
             "--download-dir", str(target)],
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


def merge(library, staging, execute, prune, use_mb=True, mixed=4):
    if not staging.exists():
        sys.exit(f"nothing at {staging}")

    db = open_index()
    lib = group(scan(library, db, verbose=True), mixed)
    home = {}
    titles = {}
    for key, tracks in lib.items():
        dirs = defaultdict(int)
        for t in tracks:
            dirs[t["path"].parent] += 1
        home[key] = max(dirs, key=dirs.get)
        titles[key] = {norm(t["title"]) for t in tracks if t["title"]}

    by_album = defaultdict(list)
    for key in lib:
        if is_loose(key):
            continue
        label = norm(summarise(lib[key])["album"])
        if label:
            by_album[label].append(key)

    wanted = {}
    for key, tracks in lib.items():
        if is_loose(key):
            continue
        info = summarise(tracks)
        report = diagnose(info, use_mb)
        if not report:
            continue
        for t in report["missing"]:
            n = norm(t["title"])
            if n:
                wanted.setdefault(n, []).append(key)

    def locate(key, info, tracks):
        votes = defaultdict(int)
        for t in tracks:
            for k in wanted.get(norm(t["title"]), []):
                votes[k] += 1
        if votes:
            return max(votes, key=votes.get)
        if key in home:
            return key
        for cand in (norm(info["album"]),):
            if cand and len(by_album.get(cand, [])) == 1:
                return by_album[cand][0]
        return None

    replaced = replaced_log()
    old_dir = staging / "superseded"
    moved = dupes = 0
    staged = group(scan(staging, db), mixed=99)
    for key, tracks in sorted(staged.items(), key=lambda kv: str(kv[0])):
        info = summarise(tracks)
        match = locate(key, info, tracks)
        key = match if match else key
        dest = home.get(key)
        if dest is None:
            dest = library / safe_name(info["artist"]) / safe_name(info["album"])
            print(f"{info['artist']} - {info['album']}  (new) {dest}")
        else:
            print(f"{info['artist']} - {info['album']}  -> {dest}")

        supersede = dest is not None and str(dest) in replaced
        if supersede:
            titles[key] = set()
        for t in sorted(tracks, key=lambda t: (-t["path"].stat().st_size, t["path"].name)):
            have = titles.setdefault(key, set())
            if t["title"] and norm(t["title"]) in have:
                dupes += 1
                print(f"    dup  {t['path'].name}")
                if execute and prune:
                    t["path"].unlink()
                continue

            if supersede:
                for cur in lib.get(key, []):
                    if cur["title"] and norm(cur["title"]) == norm(t["title"]):
                        print(f"    old  {cur['path'].name}")
                        if execute:
                            old_dir.mkdir(parents=True, exist_ok=True)
                            try:
                                cur["path"].rename(old_dir / cur["path"].name)
                            except OSError:
                                pass
            target = dest / t["path"].name
            if target.exists():
                dupes += 1
                print(f"    dup  {t['path'].name} (same name)")
                if execute and prune:
                    t["path"].unlink()
                continue

            print(f"    {'mv  ' if execute else 'plan'} {t['path'].name}")
            if execute:
                try:
                    dest.mkdir(parents=True, exist_ok=True)
                    try:
                        t["path"].rename(target)
                    except OSError:
                        shutil.move(str(t["path"]), str(target))
                except OSError as e:
                    print(f"    error {e}", file=sys.stderr)
                    continue
            if t["title"]:
                have.add(norm(t["title"]))
            moved += 1

    if execute:
        for d in sorted(staging.rglob("*"), key=lambda p: -len(p.parts)):
            if d.is_dir() and not any(d.iterdir()):
                d.rmdir()

    verb = "moved" if execute else "to move"
    print(f"\n{moved} {verb}, {dupes} duplicate(s)" + (" removed" if execute and prune else ""))
    return 0


def main():
    ap = argparse.ArgumentParser(description="find and fill gaps in album directories")
    ap.add_argument("--library", type=Path, default=Path("/mnt/media/music"))
    ap.add_argument("--staging", type=Path, default=Path("/mnt/media/slsk"))
    ap.add_argument("--filter", default="", help="only albums whose path matches this")
    ap.add_argument("--exclude", action="append", default=[], help="skip albums whose path matches")
    ap.add_argument("--no-musicbrainz", action="store_true", help="trust tags only")
    ap.add_argument("--min-have", type=int, default=1, help="ignore folders with fewer tracks")
    ap.add_argument("--mixed-threshold", type=int, default=4,
                    help="a folder holding this many albums is a playlist, not an album")
    ap.add_argument("--include-mixed", action="store_true", help="scan playlist folders too")
    ap.add_argument("--fetch", action="store_true", help="search soulseek for what is missing")
    ap.add_argument("--go", action="store_true", help="actually do it; implies --fetch")
    ap.add_argument("--merge", action="store_true", help="move staging into the library")
    ap.add_argument("--transfer-timeout", type=int, default=600,
                    help="seconds to wait for each file transfer")
    ap.add_argument("--whole-below", type=float, default=0.5,
                    help="below this fraction of an album, grab a whole folder instead")
    ap.add_argument("--prune", action="store_true", help="delete duplicate staging files")
    args = ap.parse_args()

    if args.merge and not (args.go or args.fetch):
        return merge(args.library, args.staging, args.go, args.prune,
                     not args.no_musicbrainz, args.mixed_threshold)
    if args.go:
        args.fetch = True
    if args.fetch:
        require_daemon()

    albums = group(scan(args.library, verbose=True), args.mixed_threshold)
    if not albums:
        sys.exit(f"no audio found under {args.library}")

    incomplete = 0
    queued = 0
    for key in sorted(albums, key=str):
        if is_loose(key) and not args.include_mixed:
            continue
        info = summarise(albums[key])
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
            ratio = info["count"] / max(report["expected"], 1)
            try:
                if ratio < args.whole_below:
                    queued += fetch_album(info, report, args.staging, args.go,
                                          args.transfer_timeout)
                else:
                    queued += fetch(info, report, args.staging, args.go,
                                    args.transfer_timeout)
            except Exception as e:
                print(f"    error {type(e).__name__}: {e}", file=sys.stderr)
        else:
            for want in report["missing"]:
                print(f"    {want['disc']}-{want['track']:02d}  {want['title'] or '?'}")

    verb = "downloaded" if args.go else "findable"
    print(f"\n{incomplete} incomplete album(s)" + (f", {queued} {verb}" if args.fetch else ""))

    if args.merge:
        print("\n--- merging ---")
        merge(args.library, args.staging, args.go, args.prune,
              not args.no_musicbrainz, args.mixed_threshold)
    return 0


if __name__ == "__main__":
    sys.exit(main())
