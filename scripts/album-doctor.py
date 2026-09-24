#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import unicodedata
import urllib.parse
from collections import defaultdict
from pathlib import Path

import musicbrainzngs
import mutagen

UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)
AUDIO = {".flac", ".mp3", ".m4a", ".ogg", ".opus", ".wav", ".wv", ".aiff",
         ".aif", ".aac", ".ape", ".alac", ".mp4", ".m4b", ".wma"}
LOSSLESS = {".flac", ".wav", ".wv", ".aiff", ".aif", ".ape", ".alac"}
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "album-doctor"
VARIOUS = {"various artists", "various", "va", "soundtrack"}
SEARCH_GAP = float(os.environ.get("ALBUM_DOCTOR_SEARCH_GAP", "4"))
STOP = {"the", "and", "vol", "disc", "edition", "deluxe", "remaster", "remastered",
        "version", "flac", "mp3", "web"}

musicbrainzngs.set_useragent("album-doctor", "1.0", "https://github.com/Ziad0dev/dots")


def norm(s):
    s = unicodedata.normalize("NFKD", s or "").casefold()
    s = re.sub(r"\(.*?\)|\[.*?\]", " ", s)
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def mentions(name, text):
    ws = [w for w in norm(name).split() if len(w) > 2 and w not in STOP]
    if not ws:
        return True
    have = set(norm(text).split())
    return sum(w in have for w in ws) >= max(1, round(len(ws) * 0.6))


def credited(artist):
    return "" if norm(artist) in VARIOUS else artist


def generic(album):
    return len([w for w in norm(album).split() if len(w) > 2 and w not in STOP]) <= 1


def mentions_artist(artist, text):
    if mentions(artist, text):
        return True
    ws = [w for w in norm(artist).split() if len(w) > 3 and w not in STOP]
    return len(ws) >= 2 and ws[-1] in set(norm(text).split())


def plausible(path, artist, album):
    by_artist = bool(artist) and mentions_artist(artist, path)
    by_album = mentions(album, path)
    if artist and generic(album):
        return by_artist, by_artist, by_album
    return by_artist or by_album, by_artist, by_album


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
    try:
        length = round(float(f.info.length), 1)
    except Exception:
        length = 0.0
    return {
        "path": path,
        "length": length,
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


def scan(root, db=None, verbose=False, skip=()):
    db = db or open_index()
    skip = {str(Path(s)) for s in skip}
    known = {r[0]: r for r in db.execute("SELECT path, mtime, size, tags FROM files")}
    out, fresh, seen = [], 0, set()
    for dirpath, dirnames, files in os.walk(root):
        dirnames[:] = [d for d in dirnames if str(Path(dirpath) / d) not in skip]
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
            cached_tr = json.loads(row[3]) if row else None
            if (
                row
                and row[1] == st.st_mtime
                and row[2] == st.st_size
                and "length" in cached_tr
            ):
                tr = cached_tr
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
            if count < max(2, seen // 2):
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


def diagnose(info, use_mb, max_expected=40):
    if not info["album"]:
        return None

    mbid = info["mbid"] or (
        find_release(info["artist"], info["album"], info["count"]) if use_mb else None
    )
    expected = release_tracklist(mbid) if mbid else None

    if expected:
        if info["count"] >= len(expected) or len(expected) > max_expected:
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


_last_search = [0.0]


def slsk(args, check=False):
    if args and args[0] == "search":
        wait = _last_search[0] + SEARCH_GAP - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        _last_search[0] = time.monotonic()
    return subprocess.run(
        ["soulseek-rs", *args], capture_output=True, text=True, check=check
    )


def require_daemon():
    if slsk(["daemon", "status", "--json"]).returncode != 0:
        sys.exit(
            "no soulseek-rs daemon: systemctl --user start soulseek-rs\n"
            "(batch work needs one; the server allows a single session per account)"
        )


def parse_hits(stdout):
    hits = []
    for line in stdout.splitlines():
        try:
            hits.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return hits


def search(query, ext, lossless):
    args = ["search", query, "--json", "--free-slots"]
    if lossless:
        args += ["--extension", ext]
    else:
        args += ["--min-bitrate", "320"]
    r = slsk(args)
    if r.returncode not in (0, 4):
        return []
    return parse_hits(r.stdout)


def pick(hits, title, artist, album):
    wanted = norm(title)
    scored = []
    for h in hits:
        path = h.get("path", "")
        stem = norm(Path(path.replace("\\", "/")).stem)
        if wanted and f" {wanted} " not in f" {stem} ":
            continue
        ok, by_artist, by_album = plausible(path, artist, album)
        if not ok:
            continue
        score = (by_artist, by_album, h.get("free_slot", False), h.get("size", 0), h.get("speed", 0))
        scored.append((score, h))
    if not scored:
        return None
    return max(scored, key=lambda s: s[0])[1]


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


def pick_folder(hits, expected, lossless, artist, album):
    best = None
    for (user, parent), items in folders(hits).items():
        n = len(items)
        ok, _, by_album = plausible(parent, artist, album)
        if n < max(2, expected - 2) or not (ok and by_album):
            continue
        flac = sum(1 for h in items if h.get("path", "").lower().endswith(".flac"))
        score = (
            bool(artist) and mentions(artist, parent),
            n >= expected,
            flac == n if lossless else True,
            -abs(n - expected),
            sum(1 for h in items if h.get("free_slot")),
            max((h.get("speed", 0) for h in items), default=0),
        )
        if best is None or score > best[0]:
            best = (score, user, parent, items)
    return best[1:] if best else None


PARALLEL = {
    "slsk": int(os.environ.get("ALBUM_DOCTOR_PARALLEL", "10")),
    "yt": int(os.environ.get("ALBUM_DOCTOR_YT_PARALLEL", "3")),
}
_running = {"slsk": [], "yt": []}


def _reap():
    for kind, jobs in _running.items():
        for job in list(jobs):
            proc, label, done = job
            if proc.poll() is None:
                continue
            jobs.remove(job)
            if proc.returncode == 0:
                if done:
                    done()
            else:
                print(f"    fail {label}: exit {proc.returncode}")


def launch(kind, cmd, label, payload=None, done=None):
    while True:
        _reap()
        if len(_running[kind]) < PARALLEL[kind]:
            break
        time.sleep(2)
    proc = subprocess.Popen(
        cmd, stdin=subprocess.PIPE if payload is not None else subprocess.DEVNULL,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True,
    )
    if payload is not None:
        proc.stdin.write(payload)
        proc.stdin.close()
    _running[kind].append((proc, label, done))


def wait_all():
    pending = sum(len(j) for j in _running.values())
    if pending:
        print(f"\nwaiting for {pending} download job(s) to finish")
    while any(_running.values()):
        _reap()
        time.sleep(2)


def queue_slsk(items, target, timeout, label, done=None):
    target.mkdir(parents=True, exist_ok=True)
    payload = "".join(json.dumps(h) + "\n" for h in items)
    launch("slsk", ["soulseek-rs", "download", "--stdin", "-t", str(timeout),
                    "--download-dir", str(target)], label, payload, done)


def fetch_album(info, report, dest, execute, timeout=600, ytdl="", ytdl_max=3):
    expected = report["expected"]
    artist = credited(info["artist"])
    query = " ".join(f"{artist} {info['album']}".split())
    if query:
        r = slsk(["search", query, "--json", "--sort", "best"])
        choice = pick_folder(parse_hits(r.stdout), expected, info["lossless"], artist, info["album"])
        if choice:
            user, parent, items = choice
            print(f"    {'get ' if execute else 'find'} folder {len(items)}/{expected} <- {user}")
            if not execute:
                return len(items)
            dirs = list(info["dirs"])
            queue_slsk(items, dest / safe_name(info["artist"]) / safe_name(info["album"]),
                       timeout, f"folder {info['album']}",
                       lambda: [replaced_log(d) for d in dirs])
            return len(items)
    print(f"    miss folder ({expected} tracks), falling back to tracks")
    return fetch(info, report, dest, execute, timeout, ytdl, ytdl_max)


def tag_file(path, artist, album, title, track):
    try:
        f = mutagen.File(path, easy=True)
    except Exception:
        return False
    if f is None:
        return False
    if f.tags is None:
        try:
            f.add_tags()
        except Exception:
            pass
    fields = [("artist", artist), ("albumartist", artist), ("album", album),
              ("title", title), ("tracknumber", str(track) if track else "")]
    for key, val in fields:
        if not val:
            continue
        try:
            f[key] = [val]
        except Exception:
            try:
                f[key] = val
            except Exception:
                pass
    try:
        f.save()
    except Exception:
        return False
    return True


def have_ytdlp():
    return shutil.which("yt-dlp") is not None


def ytdlp_json(url, timeout=180):
    try:
        r = subprocess.run(
            ["yt-dlp", "--flat-playlist", "-J", "--no-warnings", url],
            capture_output=True, text=True, timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired:
        return None
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return None


def retag_album(target, since, artist, album):
    for f in target.iterdir():
        if f.suffix.lower() not in AUDIO:
            continue
        try:
            if f.stat().st_mtime < since:
                continue
            m = mutagen.File(f, easy=True)
            if m is None:
                continue
            if m.tags is None:
                m.add_tags()
            m["album"] = [album]
            if artist:
                m["albumartist"] = [artist]
            m.save()
        except Exception:
            pass


def ytmusic_album(info, report, dest, execute, fmt="opus"):
    artist = credited(info["artist"])
    query = " ".join(f"{artist} {info['album']}".split())
    search = "https://music.youtube.com/search?q=" + urllib.parse.quote(query) + "#albums"
    found = ytdlp_json(search)
    if not found:
        print("    ytm-miss search failed")
        return 0

    titles = [norm(t["title"]) for t in report["missing"] if t["title"]]
    expected = [t for t in titles + sorted(info["titles"]) if t]

    def same(a, b):
        return bool(a and b) and (a == b or f" {a} " in f" {b} " or f" {b} " in f" {a} ")

    def who(d):
        return " ".join(
            " ".join(map(str, v)) if isinstance(v, list) else str(v or "")
            for v in (d.get(k) for k in ("artist", "artists", "creator", "uploader", "channel"))
        )

    choice = url = None
    tracks = []
    for e in (found.get("entries") or [])[:5]:
        cand = e.get("url") or e.get("webpage_url")
        listing = ytdlp_json(cand) if cand else None
        entries = (listing or {}).get("entries") or []
        if not entries:
            continue
        names = [norm(t.get("title")) for t in entries]
        if expected:
            hits = sum(any(same(x, n) for n in names) for x in expected)
            ok = hits >= max(1, round(len(expected) * 0.5))
        else:
            ok = mentions(info["album"], listing.get("title") or "") and (
                not artist or mentions_artist(artist, who(listing) + " " + (listing.get("title") or ""))
            )
        if ok:
            choice, url, tracks = listing, cand, entries
            break
    if not choice:
        print("    ytm-miss no matching album")
        return 0
    numbers = {t["track"] for t in report["missing"]}
    picks = []
    for i, e in enumerate(tracks, start=1):
        n = norm(e.get("title"))
        if titles:
            if n and any(n == w or f" {w} " in f" {n} " or f" {n} " in f" {w} " for w in titles):
                picks.append(i)
        elif i in numbers:
            picks.append(i)
    if not picks:
        print(f"    ytm-miss none of the missing tracks on {choice.get('title')}")
        return 0

    print(f"    {'ytm ' if execute else 'ytm?'} {len(picks)}/{len(report['missing'])} <- {choice.get('title')}")
    if not execute:
        return len(picks)

    target = dest / safe_name(info["artist"]) / safe_name(info["album"])
    target.mkdir(parents=True, exist_ok=True)
    since = time.time() - 1
    cmd = [
        "yt-dlp", "--quiet", "--no-warnings", "--embed-metadata",
        "-x", "--audio-format", fmt, "--audio-quality", "0",
        "--playlist-items", ",".join(map(str, picks)),
        "-o", str(target / "%(playlist_index)02d - %(title)s.%(ext)s"),
        url,
    ]
    albumartist, album = info["artist"], info["album"]
    launch("yt", cmd, f"ytm {album}",
           done=lambda: retag_album(target, since, albumartist, album))
    return len(picks)


def ytdl_one(info, want, dest, execute, fmt):
    title = want["title"]
    if not title:
        return 0
    query = " ".join(f"{credited(info['artist'])} {info['album']} {title}".split())

    if not execute:
        print(f"    yt?  {title}")
        return 1

    target = dest / safe_name(info["artist"]) / safe_name(info["album"])
    try:
        target.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        print(f"    error {e}", file=sys.stderr)
        return 0

    cmd = [
        "yt-dlp", "--no-playlist", "--quiet", "--no-warnings",
        "--no-simulate", "--print", "after_move:filepath",
        "--match-filter", "duration < 1800",
        "-x", "--audio-format", fmt, "--audio-quality", "0",
        "-o", str(target / "%(id)s.%(ext)s"),
        f"ytsearch1:{query}",
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=600, check=False)
    except subprocess.TimeoutExpired:
        print(f"    yt-timeout {title}")
        return 0
    out = [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]
    if r.returncode != 0 or not out:
        print(f"    yt-miss {title}")
        return 0

    got = Path(out[-1])
    if not got.exists():
        print(f"    yt-miss {title}")
        return 0
    tagged = tag_file(got, info["artist"], info["album"], title, want.get("track"))
    track, disc = want.get("track"), want.get("disc") or 1
    stem = safe_name(title)
    if track:
        stem = f"{disc}-{track:02d} - {stem}" if disc > 1 else f"{track:02d} - {stem}"
    final = got.with_name(stem + got.suffix)
    if final != got and not final.exists():
        got.rename(final)
    print(f"    yt   {title}" + ("" if tagged else "  (untagged)"))
    return 1


def fetch(info, report, dest, execute, timeout=600, ytdl="", ytdl_max=3):
    got = 0
    if len(report["missing"]) > ytdl_max:
        ytdl = ""
    artist = credited(info["artist"])
    base = " ".join(f"{artist} {info['album']}".split())
    pool = search(base, info["ext"], info["lossless"]) if base else []
    chosen = []
    for want in report["missing"]:
        title = want["title"]
        label = title or f"track {want['track']}"
        if not title:
            print(f"    skip {label}: no title, nothing to search for")
            continue

        choice = pick(pool, title, artist, info["album"])
        if not choice:
            for q in (f"{artist} {info['album']} {title}", f"{artist} {title}" if artist else ""):
                q = " ".join(q.split())
                if q:
                    choice = pick(search(q, info["ext"], info["lossless"]), title, artist, info["album"])
                if choice:
                    break
        if not choice:
            if ytdl:
                got += ytdl_one(info, want, dest, execute, ytdl)
            else:
                print(f"    miss {label}")
            continue

        print(f"    {'get ' if execute else 'find'} {label}  <- {choice['user']}")
        chosen.append(choice)
        got += 1

    if execute and chosen:
        queue_slsk(chosen, dest / safe_name(info["artist"]) / safe_name(info["album"]),
                   timeout, f"tracks {info['album']}")
    return got


def merge(library, staging, execute, prune, use_mb=True, mixed=4, max_expected=40):
    if not staging.exists():
        sys.exit(f"nothing at {staging}")

    old_dir = staging / "superseded"
    db = open_index()
    lib = group(scan(library, db, verbose=True), mixed)
    home, titles, owner = {}, {}, {}
    by_album = defaultdict(list)
    infos = {}
    for key, tracks in lib.items():
        dirs = defaultdict(int)
        for t in tracks:
            dirs[t["path"].parent] += 1
        home[key] = max(dirs, key=dirs.get)
        titles[key] = {norm(t["title"]) for t in tracks if t["title"]}
        info = summarise(tracks)
        infos[key] = info
        owner[key] = norm(info["artist"])
        if not is_loose(key) and norm(info["album"]):
            by_album[(owner[key], norm(info["album"]))].append(key)
    by_slot = defaultdict(list)
    for key, info in infos.items():
        if not is_loose(key):
            by_slot[(safe_name(info["artist"]), safe_name(info["album"]))].append(key)

    wanted = {}
    for key, info in infos.items():
        if is_loose(key):
            continue
        report = diagnose(info, use_mb, max_expected)
        if not report:
            continue
        for t in report["missing"]:
            n = norm(t["title"])
            if n:
                wanted.setdefault(n, []).append(key)

    def locate(key, info, tracks):
        rel = tracks[0]["path"].parent.relative_to(staging).parts
        if len(rel) >= 2:
            slot = by_slot.get((rel[0], rel[1]), [])
            if len(slot) == 1:
                return slot[0]
        artist = norm(info["artist"])
        votes = defaultdict(int)
        for t in tracks:
            for k in wanted.get(norm(t["title"]), []):
                if artist and owner.get(k) == artist:
                    votes[k] += 1
        if votes:
            return max(votes, key=votes.get)
        if key in home:
            return key
        cands = by_album.get((artist, norm(info["album"])), [])
        return cands[0] if len(cands) == 1 else None

    replaced = replaced_log()
    moved = dupes = 0
    staged = group(scan(staging, db, skip=(old_dir, staging / "dupes")), mixed=99)
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


LEAD = re.compile(r"^[\s\-_.\[\(]*(?:[a-dA-D]?\d{1,3}|[a-dA-D])[\s\-_.\)\]]+")


def variant(s):
    s = unicodedata.normalize("NFKD", s or "").casefold()
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def stem_key(path):
    return variant(LEAD.sub(" ", path.stem))


def quality(t):
    return (t["path"].suffix.lower() in LOSSLESS, t["path"].stat().st_size)


def organize(library, execute, mixed, only):
    db = open_index()
    albums = group(scan(library, db, verbose=True), mixed)

    if only:
        loose = [t for t in scan(library, db) if only.lower() in str(t["path"].parent).lower()]
    else:
        loose = []
        for key, items in albums.items():
            if is_loose(key):
                loose.extend(items)
    if not loose:
        print("nothing matched; pass --filter <folder> to organize a specific folder")
        return 0

    discs = defaultdict(set)
    for t in loose:
        label = (norm(t["artist"]), norm(t["album"]))
        discs[label].add(t.get("disc") or 1)

    plan, skipped = defaultdict(list), 0
    for t in loose:
        artist, album = t["artist"], t["album"]
        if not artist or not album:
            skipped += 1
            continue
        dest = library / safe_name(artist) / safe_name(album)
        label = (norm(artist), norm(album))
        if len(discs[label]) > 1:
            dest = dest / f"Disc {(t.get('disc') or 1):02d}"
        plan[dest].append(t)

    moved = clash = 0
    for dest in sorted(plan, key=str):
        items = plan[dest]
        print(f"{dest}   ({len(items)} files)")
        if execute:
            try:
                dest.mkdir(parents=True, exist_ok=True)
            except OSError as e:
                print(f"    error {e}", file=sys.stderr)
                continue
        for t in sorted(items, key=lambda t: t["path"].name):
            target = dest / t["path"].name
            if target.exists():
                clash += 1
                continue
            moved += 1
            if not execute:
                continue
            try:
                t["path"].rename(target)
            except OSError:
                try:
                    shutil.move(str(t["path"]), str(target))
                except OSError as e:
                    print(f"    error {e}", file=sys.stderr)
                    moved -= 1

    if execute:
        for d in sorted({t["path"].parent for t in loose}, key=lambda p: -len(p.parts)):
            if d.exists() and d != library and not any(d.iterdir()):
                try:
                    d.rmdir()
                except OSError:
                    pass

    verb = "moved" if execute else "to move"
    print(f"\n{len(plan)} album folder(s), {moved} file(s) {verb}"
          f"{f', {clash} name clash(es) left alone' if clash else ''}"
          f"{f', {skipped} untagged file(s) left alone' if skipped else ''}")
    return 0


def dedupe(library, staging, execute, prune):
    db = open_index()
    tracks = scan(library, db, verbose=True)

    per_dir = defaultdict(list)
    for t in tracks:
        per_dir[t["path"].parent].append(t)

    quarantine = staging / "dupes"
    removed = groups = 0
    for d in sorted(per_dir, key=str):
        by_name = defaultdict(list)
        for t in per_dir[d]:
            key = variant(t["title"]) or stem_key(t["path"])
            if key:
                by_name[key].append(t)

        for key, items in sorted(by_name.items()):
            if len(items) < 2:
                continue
            items.sort(key=quality, reverse=True)
            keep = items[0]
            drop = []
            for t in items[1:]:
                a, b = keep.get("length", 0.0), t.get("length", 0.0)
                if a and b and abs(a - b) > 2.0:
                    continue
                drop.append(t)
            if not drop:
                continue

            groups += 1
            print(f"{d}")
            print(f"    keep {keep['path'].name}  ({keep.get('length', 0):.0f}s)")
            for t in drop:
                print(f"    {'drop' if execute else 'plan'} {t['path'].name}"
                      f"  ({t.get('length', 0):.0f}s)")
                removed += 1
                if not execute:
                    continue
                if prune:
                    try:
                        t["path"].unlink()
                    except OSError as e:
                        print(f"    error {e}", file=sys.stderr)
                    continue
                rel = t["path"].relative_to(library)
                dest = quarantine / rel
                try:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    t["path"].rename(dest)
                except OSError:
                    try:
                        shutil.move(str(t["path"]), str(dest))
                    except OSError as e:
                        print(f"    error {e}", file=sys.stderr)

    where = "deleted" if (execute and prune) else ("moved to " + str(quarantine)
                                                   if execute else "to remove")
    print(f"\n{groups} duplicated track(s) in {groups} group(s), {removed} file(s) {where}")
    return 0


def consolidate(library, execute, prune, mixed):
    db = open_index()
    albums = group(scan(library, db, verbose=True), mixed)

    by_name = defaultdict(dict)
    for key, tracks in albums.items():
        if is_loose(key):
            continue
        info = summarise(tracks)
        label = (norm(info["artist"]), norm(info["album"]))
        if not label[1]:
            continue
        for t in tracks:
            by_name[label].setdefault(t["path"].parent, []).append(t)

    merged = dupes = folders = 0
    for label, dirs in sorted(by_name.items()):
        if len(dirs) < 2:
            continue
        folders += 1
        primary = max(dirs, key=lambda d: (len(dirs[d]), str(d)))
        print(f"{label[0] or '?'} - {label[1]}  -> {primary}")
        have = {norm(t["title"]) for t in dirs[primary] if t["title"]}

        for d in sorted(dirs, key=str):
            if d == primary:
                continue
            for t in sorted(dirs[d], key=lambda t: -t["path"].stat().st_size):
                n = norm(t["title"])
                target = primary / t["path"].name
                if (n and n in have) or target.exists():
                    dupes += 1
                    print(f"    dup  {d.name}/{t['path'].name}")
                    if execute and prune:
                        try:
                            t["path"].unlink()
                        except OSError as e:
                            print(f"    error {e}", file=sys.stderr)
                    continue
                print(f"    {'mv  ' if execute else 'plan'} {d.name}/{t['path'].name}")
                if execute:
                    try:
                        t["path"].rename(target)
                    except OSError:
                        try:
                            shutil.move(str(t["path"]), str(target))
                        except OSError as e:
                            print(f"    error {e}", file=sys.stderr)
                            continue
                if n:
                    have.add(n)
                merged += 1

            if execute and d.exists() and not any(d.iterdir()):
                try:
                    d.rmdir()
                    print(f"    rmdir {d.name}")
                except OSError:
                    pass

    verb = "moved" if execute else "to move"
    print(f"\n{folders} split album(s), {merged} {verb}, {dupes} duplicate(s)"
          + (" removed" if execute and prune else ""))
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
    ap.add_argument("--merge", action="store_true", help="merge staging in after fetching")
    ap.add_argument("--organize", action="store_true",
                    help="file tracks from unorganized folders into artist/album folders")
    ap.add_argument("--dedupe", action="store_true",
                    help="remove duplicate recordings within each album folder")
    ap.add_argument("--consolidate", action="store_true",
                    help="merge duplicate folders of the same album into one")
    ap.add_argument("--merge-only", action="store_true",
                    help="only move staging into the library; download nothing")
    ap.add_argument("--ytdl", nargs="?", const="opus", default="",
                    metavar="FORMAT",
                    help="fall back to yt-dlp for tracks soulseek cannot supply")
    ap.add_argument("--ytmusic", action="store_true",
                    help="fetch missing tracks from the official YouTube Music album instead of soulseek")
    ap.add_argument("--ytdl-max", type=int, default=3, metavar="N",
                    help="only use yt-dlp for albums missing N or fewer tracks")
    ap.add_argument("--max-expected", type=int, default=40, metavar="N",
                    help="skip releases longer than N tracks (box sets)")
    ap.add_argument("--transfer-timeout", type=int, default=600,
                    help="seconds to wait for each file transfer")
    ap.add_argument("--max-gap", type=int, default=0, metavar="N",
                    help="only albums missing N or fewer tracks (0 = no limit)")
    ap.add_argument("--whole-below", type=float, default=0.5,
                    help="below this fraction of an album, grab a whole folder instead")
    ap.add_argument("--prune", action="store_true", help="delete duplicate staging files")
    args = ap.parse_args()

    use_mb = not args.no_musicbrainz
    if args.organize:
        return organize(args.library, args.go, args.mixed_threshold, args.filter)
    if args.dedupe:
        return dedupe(args.library, args.staging, args.go, args.prune)
    if args.consolidate:
        return consolidate(args.library, args.go, args.prune, args.mixed_threshold)
    if args.merge_only:
        return merge(args.library, args.staging, True, args.prune,
                     use_mb, args.mixed_threshold, args.max_expected)
    if args.merge and not (args.go or args.fetch):
        return merge(args.library, args.staging, False, args.prune,
                     use_mb, args.mixed_threshold, args.max_expected)
    if args.go:
        args.fetch = True
    ytdl = args.ytdl
    if ytdl and not have_ytdlp():
        print("yt-dlp not on PATH; continuing without the fallback", file=sys.stderr)
        ytdl = ""
    if args.ytmusic and not have_ytdlp():
        sys.exit("yt-dlp not on PATH")
    if args.fetch and not args.ytmusic:
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
        report = diagnose(info, use_mb, args.max_expected)
        if not report:
            continue
        if args.max_gap and len(report["missing"]) > args.max_gap:
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
                if args.ytmusic:
                    queued += ytmusic_album(info, report, args.staging, args.go)
                elif ratio < args.whole_below:
                    queued += fetch_album(info, report, args.staging, args.go,
                                          args.transfer_timeout, ytdl, args.ytdl_max)
                else:
                    queued += fetch(info, report, args.staging, args.go,
                                    args.transfer_timeout, ytdl, args.ytdl_max)
            except Exception as e:
                print(f"    error {type(e).__name__}: {e}", file=sys.stderr)
        else:
            for want in report["missing"]:
                print(f"    {want['disc']}-{want['track']:02d}  {want['title'] or '?'}")

    if args.go:
        wait_all()
    verb = "downloaded" if args.go else "findable"
    print(f"\n{incomplete} incomplete album(s)" + (f", {queued} {verb}" if args.fetch else ""))

    if args.merge:
        print("\n--- merging ---")
        merge(args.library, args.staging, args.go, args.prune,
              use_mb, args.mixed_threshold, args.max_expected)
    return 0


if __name__ == "__main__":
    sys.exit(main())
