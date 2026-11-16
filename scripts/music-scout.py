#!/usr/bin/env python3
"""Discovery helpers on top of the beets library.

  music-scout new [--days N]     releases by artists in the library that it lacks
  music-scout similar ARTIST     artists like ARTIST (ListenBrainz), owned ones marked
  music-scout foryou             artists the library lacks, ranked by how many
                                 library artists they resemble
  music-scout spotify ZIP...     read Spotify exports: the "extended streaming
                                 history" (plays; foryou then weighs artists by them)
                                 and/or the account data (playlists, liked songs,
                                 saved albums)
  music-scout playlists          the Spotify playlists, liked songs and mixes made
                                 from the plays, as .m3u8 files of the tracks the
                                 library has; rerun after an import and they grow
  music-scout missing            the Spotify albums the library lacks, the most
                                 played / liked / saved first
  music-scout buylist            the same as a page of Bandcamp / Qobuz store links
  music-scout weekly             this week's ListenBrainz playlist made for you
                                 (needs the user token, one line, in
                                 ~/.config/music-scout/listenbrainz-token)
"""
import argparse
import datetime
import fcntl
import hashlib
import html
import json
import math
import os
import re
import sqlite3
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

import musicbrainzngs

HOME = Path.home()
LIBRARY = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "beets/library.db"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "music-scout"
TOKEN = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "music-scout/listenbrainz-token"
LB = "https://api.listenbrainz.org/1/"
# listening history is personal and not re-derivable: kept out of the cache
PLAYS = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "music-scout/plays.json"
# playlists, liked songs and saved albums from the account data export
SAVED = PLAYS.with_name("spotify-library.json")
PLAYLISTS = Path(os.environ.get("MUSIC_SCOUT_PLAYLISTS", HOME / "Music/Playlists"))
# the same playlists on Jellyfin, for the phone: an API key (Dashboard > API
# Keys), one line; without it `playlists` only writes the files
JF_TOKEN = TOKEN.with_name("jellyfin-token")
JELLYFIN = os.environ.get("MUSIC_SCOUT_JELLYFIN", "http://127.0.0.1:8096").rstrip("/")
# which Jellyfin playlist is which of ours, so ours are updated, never anyone else's
JF_STATE = PLAYS.with_name("jellyfin-playlists.json")
UA ="music-scout/1.0 (https://github.com/Ziad0dev/dots)"
VARIOUS = "89ad4ac3-39f7-470e-963a-56509c546377"
# the session-based model ListenBrainz's own artist pages use
ALGO = ("session_based_days_7500_session_300_contribution_5_"
        "threshold_10_limit_100_filter_True_skip_30")

musicbrainzngs.set_useragent("music-scout", "1.0", "https://github.com/Ziad0dev/dots")


def norm(s):
    s = unicodedata.normalize("NFKD", s or "").casefold()
    return "".join(c for c in s if c.isalnum())


def edition(album):
    """'OK Computer (Deluxe) [Remastered]' and 'OK Computer' are one album."""
    return norm(re.sub(r"\s*[\(\[].*?[\)\]]", "", album or "")) or norm(album)


# Spotify credits the first artist only; beets has "A feat. B". A guest credit
# never belongs to the name; "&", "," and " x " are often part of it ("Simon &
# Garfunkel", "Earth, Wind & Fire"), so those only count when the album agrees
GUEST = re.compile(r"\s+(?:feat\.?|ft\.|featuring|with|vs\.?)\s+", re.I)
JOINT = re.compile(r"\s+(?:x|&)\s+|\s*[,;/]\s+", re.I)
# a bracket or " - " tail naming a release of the same recording...
SAME = re.compile(r"remaster|\bfeat\b|ft\.|featuring|\bwith\b|single version|album version"
                  r"|original version|\bmono\b|\bstereo\b|bonus track|explicit|radio edit", re.I)
# ...unless it is another performance or another mix ("Live with the LSO")
OTHER = re.compile(r"\blive\b|remix|\bmix\b|rework|\bdemo\b|acoustic|instrumental|unplugged"
                   r"|session|\bcover\b|extended|\bdub\b|reprise|orchestral|a ?cappella", re.I)
TAIL = re.compile(r"\s*(?:\(([^()]*)\)|\[([^\[\]]*)\]|\s-\s+([^-]+))\s*$")


def primary(artist):
    """'A feat. B': A."""
    return norm(GUEST.split(artist or "", maxsplit=1)[0]) or norm(artist)


def lead(artist):
    """'A & B', 'A, B', 'A x B': A. Wrong for some band names; see JOINT."""
    return norm(JOINT.split(GUEST.split(artist or "", maxsplit=1)[0], maxsplit=1)[0]) or norm(artist)


def song(title):
    """'Song - 2011 Remaster', 'Song (feat. X)' and 'Song' are one recording;
    'Song - Live' and 'Song (Remix) [feat. X]' are not."""
    t = title or ""
    while m := TAIL.search(t):
        part = next(g for g in m.groups() if g is not None)
        if not SAME.search(part) or OTHER.search(part):
            break
        t = t[:m.start()]
    return norm(t) or norm(title)


def plays():
    """What `spotify` stored: {"artists": {norm name: [name, score, plays]},
    "albums": [[artist, album, score, plays], ...],
    "tracks": [[artist, title, album, plays, last ts, plays in its last 90
    days, {year: plays}], ...]}; empty before an import."""
    if not PLAYS.exists():
        return {"artists": {}, "albums": [], "tracks": []}
    return json.loads(PLAYS.read_text())


def saved():
    """What `spotify` stored from the account data: {"tracks": [[artist, title,
    album], ...], "liked": [track index, ...], "albums": [[artist, album], ...],
    "playlists": [{"name", "modified", "tracks": [track index, ...]}, ...]}."""
    if not SAVED.exists():
        return {"tracks": [], "liked": [], "albums": [], "playlists": []}
    return json.loads(SAVED.read_text())


def save(f, text):
    """Whole or not at all: the panel runs several of these at once, and one
    may be reading the file another is replacing."""
    f.parent.mkdir(parents=True, exist_ok=True)
    tmp = f.with_name(f"{f.name}.{os.getpid()}.tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, f)


def cached(key, ttl, fn):
    """fn()'s JSON-able result, reused for ttl seconds. Failures aren't stored."""
    f = CACHE / (hashlib.md5(key.encode()).hexdigest() + ".json")
    if f.exists() and time.time() - f.stat().st_mtime < ttl:
        try:
            return json.loads(f.read_text())
        except ValueError:          # cut short by a crash: fetch it again
            pass
    out = fn()
    save(f, json.dumps(out))
    return out


def library():
    if not LIBRARY.exists():
        sys.exit(f"no beets library at {LIBRARY}")
    db = sqlite3.connect(f"file:{LIBRARY}?mode=ro", uri=True)
    artists, groups = {}, set()          # mbid -> name; owned release-group ids
    for name, mbid, rg in db.execute(
            "select albumartist, mb_albumartistid, mb_releasegroupid from albums"):
        if rg:
            groups.add(rg)
        if mbid and mbid != VARIOUS:
            artists.setdefault(mbid, name)
    track_artists = {norm(n): m for n, m in db.execute(
        "select artist, mb_artistid from items where mb_artistid != '' group by artist")}
    return artists, groups, track_artists


def release_groups(mbid):
    out, offset = [], 0
    while True:
        page = musicbrainzngs.browse_release_groups(
            artist=mbid, release_type=["album", "ep"], limit=100, offset=offset)
        got = page["release-group-list"]
        out += [{"id": g["id"], "title": g["title"],
                 "date": g.get("first-release-date", ""),
                 "type": g.get("primary-type", ""),
                 "secondary": g.get("secondary-type-list", [])} for g in got]
        offset += len(got)
        if not got or offset >= page.get("release-group-count", 0):
            return out


def departed(mbids):
    """The mbids of people who have died. Their "new releases" are other
    performers' recordings (every new Bach album is credited to Bach), so
    `new` leaves them out. Disbanded groups stay: reunions happen."""
    f = CACHE / "artist-meta.json"
    try:
        meta = json.loads(f.read_text())
    except (OSError, ValueError):
        meta = {}
    now = time.time()
    todo = [m for m in mbids if now - meta.get(m, {}).get("at", 0) > 90 * 86400]
    for i in range(0, len(todo), 40):
        batch = todo[i:i + 40]
        try:
            hits = musicbrainzngs.search_artists(
                query="arid:(" + " OR ".join(batch) + ")", limit=100)["artist-list"]
        except musicbrainzngs.MusicBrainzError as e:
            print(f"artist lookup: {e}", file=sys.stderr)
            continue
        for m in batch:             # an id MusicBrainz no longer knows: don't re-ask daily
            meta[m] = {"at": now, "dead": False}
        for a in hits:
            meta[a["id"]] = {"at": now, "dead": a.get("type") == "Person"
                             and a.get("life-span", {}).get("ended") == "true"}
        save(f, json.dumps(meta))
    return {m for m in mbids if meta.get(m, {}).get("dead")}


def print_last(f):
    # a panel's instant first paint: whatever the previous run found
    print(f.read_text() if f.exists() else "[]")


def cmd_new(args):
    last = CACHE / "new.json"
    if args.last:
        return print_last(last)
    artists, owned, _ = library()
    if not args.include_dead:
        for mbid in departed(list(artists)):
            del artists[mbid]
    today = datetime.date.today()
    since = (today - datetime.timedelta(days=args.days)).isoformat()
    upto = (today + datetime.timedelta(days=args.ahead)).isoformat()
    found = []
    for i, (mbid, name) in enumerate(sorted(artists.items(), key=lambda kv: norm(kv[1])), 1):
        if sys.stderr.isatty():
            print(f"\r\033[K{i}/{len(artists)} {name[:50]}", end="", file=sys.stderr)
        try:
            groups = cached("rg:" + mbid, args.max_age * 3600, lambda: release_groups(mbid))
        except musicbrainzngs.MusicBrainzError as e:
            print(f"\n{name}: {e}", file=sys.stderr)
            continue
        for g in groups:
            # a bare year ("2026") can't be placed inside the window
            if len(g["date"]) < 7 or not since[:len(g["date"])] <= g["date"] <= upto:
                continue
            if g["id"] in owned or (g["secondary"] and not args.all_types):
                continue
            found.append({"artist": name, **g})
    if sys.stderr.isatty():
        print("\r\033[K", end="", file=sys.stderr)
    found.sort(key=lambda g: g["date"], reverse=True)
    save(last, json.dumps(found, ensure_ascii=False))
    if args.json:
        print(json.dumps(found, ensure_ascii=False))
        return
    for g in found:
        kind = "/".join([g["type"]] + g["secondary"]) or "?"
        mark = "  (upcoming)" if g["date"] > today.isoformat() else ""
        print(f"{g['date']:<10}  {kind:<6}  {g['artist']} - {g['title']}{mark}")
    print(f"{len(found)} release(s) since {since} across {len(artists)} artists",
          file=sys.stderr)


def get_json(url, token=""):
    headers = {"User-Agent": UA}
    if token:
        headers["Authorization"] = "Token " + token
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def lb_account(user=""):
    """(user name, token) for ListenBrainz; the name is "" without a token
    that works, unless one was given."""
    token = TOKEN.read_text().strip() if TOKEN.exists() else ""
    if not user and token:
        def whoami():
            name = get_json(LB + "validate-token", token).get("user_name")
            if not name:            # raise, so a rejected token isn't remembered for a month
                raise ValueError(f"ListenBrainz rejected the token in {TOKEN}")
            return name
        try:
            user = cached("lbuser:" + token, 30 * 86400, whoami)
        except (OSError, ValueError) as e:
            print(e, file=sys.stderr)
    return user, token


def recent_listens(days):
    """[[artist, title, album, listens], ...] from ListenBrainz over the last
    `days` days: Tauon's scrobbles, and the Spotify years imported there.
    None without an account or a connection."""
    user, token = lb_account()
    if not user:
        return None

    def fetch():
        since = int(time.time()) - days * 86400
        upto, counts = int(time.time()) + 1, {}
        while True:                 # newest first, a page at a time
            got = get_json(LB + f"user/{urllib.parse.quote(user)}/listens?"
                           + urllib.parse.urlencode({"max_ts": upto, "count": 1000}),
                           token)["payload"]["listens"]
            for listen in got:
                if listen["listened_at"] < since:
                    return list(counts.values())
                m = listen.get("track_metadata", {})
                a, t = m.get("artist_name") or "", m.get("track_name") or ""
                c = counts.setdefault((primary(a), song(t)),
                                      [a, t, m.get("release_name") or "", 0])
                c[3] += 1
            if not got:
                return list(counts.values())
            upto = got[-1]["listened_at"]
            time.sleep(0.2)
    try:
        return cached(f"recent:{user}:{days}", 6 * 3600, fetch)
    except (OSError, ValueError, KeyError) as e:
        print(f"ListenBrainz listens: {e}", file=sys.stderr)
        return None


def cmd_weekly(args):
    """ListenBrainz builds these every Monday from the account's listens:
    weekly-exploration is music it thinks you'd like and haven't played,
    weekly-jams is your own favourites."""
    user, token = lb_account(args.user)
    out = {"title": "", "tracks": []}
    if user:
        try:
            made = cached(f"createdfor:{user}", 6 * 3600, lambda: get_json(
                LB + f"user/{urllib.parse.quote(user)}/playlists/createdfor", token))
        except OSError as e:        # offline: an empty section, not a traceback
            print(e, file=sys.stderr)
            made = {}

        def kind(p):
            ext = p.get("extension", {}).get("https://musicbrainz.org/doc/jspf#playlist", {})
            return (ext.get("additional_metadata", {}).get("algorithm_metadata", {})
                    .get("source_patch", ""))
        mine = sorted((p["playlist"] for p in made.get("playlists", [])
                       if kind(p["playlist"]) == args.kind),
                      key=lambda p: p.get("date", ""), reverse=True)
        if mine:
            mbid = mine[0]["identifier"].rstrip("/").rsplit("/", 1)[-1]
            try:
                full = cached("playlist:" + mbid, 7 * 86400,
                              lambda: get_json(LB + "playlist/" + mbid, token))["playlist"]
            except OSError as e:
                print(e, file=sys.stderr)
                full = {}
            db = sqlite3.connect(f"file:{LIBRARY}?mode=ro", uri=True)
            have = {(norm(a), norm(t)) for a, t in db.execute("select artist, title from items")}
            out["title"] = full.get("title", "")
            for t in full.get("track", []):
                ident = t.get("identifier", "")
                ident = ident[0] if isinstance(ident, list) and ident else ident
                out["tracks"].append({
                    "artist": t.get("creator", ""), "title": t.get("title", ""),
                    "album": t.get("album", ""),
                    "mbid": str(ident).rstrip("/").rsplit("/", 1)[-1],
                    "owned": (norm(t.get("creator")), norm(t.get("title"))) in have})
    if args.json:
        print(json.dumps(out, ensure_ascii=False))
        return
    if not user:
        sys.exit(f"no ListenBrainz user: put the user token in {TOKEN}, or pass --user")
    if not out["tracks"]:
        sys.exit(f"ListenBrainz has no {args.kind} playlist for {user} yet "
                 "(they are made on Mondays, once it has enough listens)")
    print(out["title"])
    for t in out["tracks"]:
        print(f"{'*' if t['owned'] else ' '} {t['artist']} - {t['title']}")


def resolve(name, track_artists):
    mbid = track_artists.get(norm(name))
    if mbid:
        return mbid

    def search():
        hits = musicbrainzngs.search_artists(artist=name, limit=1)["artist-list"]
        return hits[0]["id"] if hits and int(hits[0].get("ext:score", 0)) >= 90 else ""
    return cached("artist:" + norm(name), 30 * 86400, search)


def similar_to(mbid):
    url = ("https://labs.api.listenbrainz.org/similar-artists/json?"
           + urllib.parse.urlencode({"artist_mbids": mbid, "algorithm": ALGO}))

    def fetch():
        time.sleep(0.4)             # only uncached lookups pay this
        return get_json(url)
    return cached("similar:" + mbid, 7 * 86400, fetch)


def listeners(mbids):
    """mbid -> how many ListenBrainz users have played the artist."""
    def fetch():
        req = urllib.request.Request(
            "https://api.listenbrainz.org/1/popularity/artist",
            data=json.dumps({"artist_mbids": mbids}).encode(),
            headers={"User-Agent": UA, "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return {p["artist_mbid"]: p.get("total_user_count") or 0 for p in json.load(r)}
    try:
        return cached("pop:" + ",".join(sorted(mbids)), 30 * 86400, fetch)
    except Exception as e:
        print(f"popularity: {e}", file=sys.stderr)
        return {}


def export_json(src, pattern):
    """The files of a Spotify export (the zip, or the folder unpacked from
    it) whose path matches pattern, parsed."""
    src = Path(src)
    if src.is_dir():
        return [json.loads(f.read_bytes()) for f in sorted(src.rglob("*.json"))
                if re.search(pattern, f.as_posix())]
    with zipfile.ZipFile(src) as z:
        return [json.loads(z.read(n)) for n in sorted(z.namelist()) if re.search(pattern, n)]


def read_history(rows, src):
    # under 30 seconds is a skip, not a listen
    rows = [r for r in rows if r.get("master_metadata_track_name")
            and r.get("master_metadata_album_artist_name")
            and (r.get("ms_played") or 0) >= 30000]
    if not rows:
        print(f"no plays of 30 seconds or more in the streaming history in {src}",
              file=sys.stderr)
        return
    newest = max(r["ts"] for r in rows)
    year_ago = str(int(newest[:4]) - 1) + newest[4:]
    recent = (datetime.datetime.fromisoformat(newest) - datetime.timedelta(days=90)
              ).strftime("%Y-%m-%dT%H:%M:%SZ")
    artists, albums, tracks = {}, {}, {}
    for r in rows:
        # the last year counts four times over: taste now, not in 2019
        gain = 4 if r["ts"] >= year_ago else 1
        name = r["master_metadata_album_artist_name"]
        a = artists.setdefault(norm(name), [name, 0, 0])
        a[1] += gain
        a[2] += 1
        album = r.get("master_metadata_album_album_name") or ""
        if album:
            b = albums.setdefault((norm(name), edition(album)), [name, album, 0, 0])
            b[2] += gain
            b[3] += 1
            if len(album) < len(b[1]):      # show the plainest edition's title
                b[1] = album
        title = r["master_metadata_track_name"]
        t = tracks.setdefault((primary(name), song(title)), [name, title, album, 0, "", 0, {}])
        t[3] += 1
        t[4] = max(t[4], r["ts"])
        t[5] += r["ts"] >= recent
        t[6][r["ts"][:4]] = t[6].get(r["ts"][:4], 0) + 1
    save(PLAYS, json.dumps({
        "through": newest,
        "artists": {k: v for k, v in artists.items() if v[2] >= 3},
        "albums": sorted((b for b in albums.values() if b[3] >= 5),
                         key=lambda b: b[2], reverse=True),
        "tracks": sorted((t for t in tracks.values() if t[3] >= 2),
                         key=lambda t: t[3], reverse=True)}, ensure_ascii=False))
    print(f"{len(rows)} plays of {len(artists)} artists through {newest[:10]} -> {PLAYS}",
          file=sys.stderr)


# saved copies of Spotify's own mixes: its taste, not yours
NOT_MINE = re.compile(r"(?:\sRadio|^Daily Mix \d+|^Discover Weekly|^Release Radar)$", re.I)


def read_account(lists, library):
    table, index = [], {}

    def ref(artist, title, album):
        key = (primary(artist), song(title), edition(album))
        if key not in index:
            index[key] = len(table)
            table.append([artist, title, album])
        return index[key]

    def item(i):
        if t := i.get("track"):
            return ref(t.get("artistName", ""), t.get("trackName", ""), t.get("albumName", ""))
        # a file played from the computer: spotify:local:artist:album:title:seconds
        parts = (i.get("localTrack") or {}).get("uri", "").split(":")
        if len(parts) >= 5 and parts[4]:
            a, b, t = (urllib.parse.unquote_plus(p) for p in parts[2:5])
            return ref(a, t, b)
        return None

    # "Name (2)" is a second copy of Name, and the export lists some playlists
    # more than once: one playlist per name, newest version's order first
    groups = {}
    for p in lists:
        name = re.sub(r"\s*\(\d+\)$", "", (p.get("name") or "").strip()) or "Untitled"
        if not NOT_MINE.search(name):
            groups.setdefault(name, []).append(p)
    out = []
    for name, versions in groups.items():
        versions.sort(key=lambda p: p.get("lastModifiedDate") or "", reverse=True)
        seen, refs = set(), []
        for p in versions:
            for i in p.get("items", []):
                r = item(i)
                if r is not None and r not in seen:
                    seen.add(r)
                    refs.append(r)
        if refs:
            out.append({"name": name, "modified": versions[0].get("lastModifiedDate") or "",
                        "tracks": refs})
    out.sort(key=lambda p: p["modified"], reverse=True)
    liked = [ref(t.get("artist", ""), t.get("track", ""), t.get("album", ""))
             for t in library.get("tracks", [])]
    albums = [[a.get("artist", ""), a.get("album", "")] for a in library.get("albums", [])]
    save(SAVED, json.dumps({"tracks": table, "liked": liked, "albums": albums,
                            "playlists": out}, ensure_ascii=False))
    print(f"{len(out)} playlists, {len(liked)} liked songs, {len(albums)} saved albums "
          f"-> {SAVED}", file=sys.stderr)


def cmd_spotify(args):
    # several exports are read as one: history from two requests adds up (a
    # play in both counts once), and each kind of file is written once
    history, lists, library = {}, [], {}
    for src in args.export:
        for part in export_json(src, r"Streaming_History_Audio_[^/]*\.json$"):
            for r in part:
                history[(r.get("ts"), r.get("spotify_track_uri")
                       or r.get("master_metadata_track_name"), r.get("ms_played"))] = r
        lists += [p for part in export_json(src, r"/Playlist\d+\.json$")
                  for p in part.get("playlists", [])]
        for lib in export_json(src, r"/YourLibrary\.json$"):
            library = lib
    if not (history or lists or library):
        sys.exit("no Streaming_History_Audio_*.json, Playlist*.json or YourLibrary.json in "
                 + ", ".join(args.export))
    if history:
        read_history(list(history.values()), ", ".join(args.export))
    if lists or library:
        read_account(lists, library)


def stores(artist, album):
    """Where the album can be bought as a lossless download: store search pages."""
    q = urllib.parse.quote_plus(f"{artist} {album}")
    return {"bandcamp": f"https://bandcamp.com/search?q={q}&item_type=a",
            "qobuz": f"https://www.qobuz.com/se-en/search?q={q}"}


def missing(limit, min_plays=0):
    """The albums the library lacks that were played at least min_plays
    times, saved, or have three liked songs; the ones that mattered most first."""
    db = sqlite3.connect(f"file:{LIBRARY}?mode=ro", uri=True)
    owned = {(norm(a), edition(b)) for a, b in db.execute(
        "select albumartist, album from albums union select artist, album from items")}
    want = {}

    def entry(artist, album, score=0, n=0):
        return want.setdefault((norm(artist), edition(album)), {
            "artist": artist, "album": album, "plays": n, "liked": 0, "saved": False,
            "listed": 0, "score": score})
    for a, b, score, n in plays()["albums"]:
        entry(a, b, score, n)
    lib = saved()
    for i in lib["liked"]:
        a, _, b = lib["tracks"][i]
        if b:
            entry(a, b)["liked"] += 1
    for a, b in lib["albums"]:
        if b:
            entry(a, b)["saved"] = True
    for i in {i for p in lib["playlists"] for i in p["tracks"]}:
        a, _, b = lib["tracks"][i]
        if b:
            entry(a, b)["listed"] += 1
    out = []
    for key, w in want.items():
        # only in a playlist or two isn't enough on its own
        played = w["plays"] > 0 and w["plays"] >= min_plays
        if key in owned or not (played or w["saved"] or w["liked"] >= 3):
            continue
        # the plays score already counts the last year four times over; a box
        # set's two hundred liked tracks shouldn't outweigh years of plays
        w["score"] += 25 * min(w["liked"], 12) + 80 * w["saved"] + 3 * min(w["listed"], 20)
        out.append({**w, "why": why(w), **stores(w["artist"], w["album"])})
    out.sort(key=lambda w: w["score"], reverse=True)
    return out[:limit]


def why(w):
    """'420 plays · 6 liked · saved'"""
    return " · ".join(s for s in (
        f"{w['plays']} plays" if w["plays"] else "",
        f"{w['liked']} liked" if w["liked"] else "",
        "saved" if w["saved"] else "") if s)


PAGE = """<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Albums to buy</title>
<style>
:root { color-scheme: light dark; --bg: #f6f5f2; --ink: #1c1b19; --dim: #77736b; --line: #dedbd3; --link: #a3322a; }
@media (prefers-color-scheme: dark) { :root { --bg: #131211; --ink: #e9e6df; --dim: #8d8980; --line: #2b2926; --link: #e0705f; } }
body { background: var(--bg); color: var(--ink); font: 14px/1.45 ui-monospace, "JetBrains Mono", monospace; margin: 0; padding: 32px 16px; }
main { max-width: 860px; margin: 0 auto; }
h1 { font-size: 15px; letter-spacing: .15em; text-transform: uppercase; margin: 0 0 4px; }
p { color: var(--dim); margin: 0 0 24px; }
table { width: 100%; border-collapse: collapse; }
td { padding: 7px 8px; border-top: 1px solid var(--line); vertical-align: baseline; }
td.n { color: var(--dim); text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
td.l { white-space: nowrap; text-align: right; }
small { color: var(--dim); display: block; }
a { color: var(--link); text-decoration: none; margin-left: 12px; } a:hover { text-decoration: underline; }
tr.done td { opacity: .35; } tr.done b { text-decoration: line-through; }
input { accent-color: var(--link); }
</style><main>
<h1>Albums to buy</h1>
<p>__COUNT__ albums from Spotify that aren't in the library: played at least __MIN__ times, saved, or with three or more liked songs. The ones you played, liked and saved most come first. Tick one off once it's bought; ticks are remembered in this browser.</p>
<table>__ROWS__</table></main>
<script>
for (const box of document.querySelectorAll("input")) {
  const key = "bought:" + box.dataset.k, row = box.closest("tr");
  try { box.checked = localStorage.getItem(key) === "1"; } catch (e) {}
  row.classList.toggle("done", box.checked);
  box.addEventListener("change", () => {
    row.classList.toggle("done", box.checked);
    try { box.checked ? localStorage.setItem(key, "1") : localStorage.removeItem(key); } catch (e) {}
  });
}
</script></html>
"""


def cmd_buylist(args):
    if not (PLAYS.exists() or SAVED.exists()):
        sys.exit("no Spotify data yet: music-scout spotify my_spotify_data.zip")
    e = html.escape
    rows = "".join(
        f'<tr><td><input type="checkbox" data-k="{e(norm(g["artist"]) + "/" + edition(g["album"]))}"></td>'
        f'<td class="n">{e(g["why"])}</td>'
        f'<td><b>{e(g["album"])}</b><small>{e(g["artist"])}</small></td>'
        f'<td class="l"><a href="{e(g["bandcamp"])}">Bandcamp</a><a href="{e(g["qobuz"])}">Qobuz</a></td></tr>'
        for g in missing(100000, args.min_plays))
    out = Path(args.out) if args.out else CACHE / "buylist.html"
    save(out, PAGE.replace("__COUNT__", str(rows.count("<tr>")))
                   .replace("__MIN__", str(args.min_plays)).replace("__ROWS__", rows))
    print(out)
    if not args.no_open:
        subprocess.Popen(["xdg-open", str(out)], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)


def music_dir():
    """beets' `directory`: its paths are relative to it."""
    try:
        conf = (Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
                / "beets/config.yaml").read_text()
        if m := re.search(r"^directory:\s*['\"]?(.+?)['\"]?\s*$", conf, re.M):
            return Path(m.group(1)).expanduser()
    except OSError:
        pass
    return HOME / "Music"


# lossless first, when the library has a recording more than once
FORMATS = {"FLAC": 0, "ALAC": 0, "AIFF": 1, "WAVE": 1, "Opus": 2, "OGG": 2, "AAC": 3, "MP3": 3}


class Shelf:
    """The library's files by (artist, recording)."""

    def __init__(self):
        if not LIBRARY.exists():
            sys.exit(f"no beets library at {LIBRARY}")
        root = music_dir()
        db = sqlite3.connect(f"file:{LIBRARY}?mode=ro", uri=True)
        self.by, self.joint = {}, {}
        for path, artist, albumartist, title, album, length, fmt in db.execute(
                "select path, artist, albumartist, title, album, length, format from items"):
            p = Path(os.fsdecode(path))
            row = (edition(album), FORMATS.get(fmt, 4), str(p if p.is_absolute() else root / p),
                   artist, title, round(length or 0))
            names = {norm(artist), primary(artist), norm(albumartist), primary(albumartist)}
            for a in names - {""}:
                self.by.setdefault((a, song(title)), []).append(row)
            for a in {lead(artist), lead(albumartist)} - names - {""}:
                self.joint.setdefault((a, song(title)), []).append(row)

    def find(self, artist, title, album=""):
        """The file for a track, the same album's if there's a choice; None if missing."""
        ed = edition(album)
        rows = (self.by.get((norm(artist), song(title)))
                or self.by.get((primary(artist), song(title)))
                or [r for r in self.joint.get((lead(artist), song(title)), []) if r[0] == ed])
        if not rows:
            return None
        return min(rows, key=lambda r: (r[0] != ed, r[1]))

    def pick(self, tracks, limit=None):
        """The files for (artist, title, album, ...) in order, once each."""
        out, seen = [], set()
        for t in tracks:
            r = self.find(*t[:3])
            if r and r[2] not in seen:
                seen.add(r[2])
                out.append(r)
                if limit and len(out) >= limit:
                    break
        return out


def m3u_name(name, taken):
    """A file name, on exFAT too, that no other playlist this run has."""
    base = re.sub(r'[\x00-\x1f"*/:<>?\\|]', "_", name).strip(" .")[:120] or "Untitled"
    name, n = base, 1
    while name.casefold() in taken:
        n += 1
        name = f"{base} {n}"
    taken.add(name.casefold())
    return name + ".m3u8"


def write_m3u(f, title, rows):
    """True if it changed. Tauon reloads a playlist whose file changed size;
    an unchanged one is left alone, mtime and all."""
    text = "\n".join(["#EXTM3U", f"#PLAYLIST:{title}"] + [
        f"#EXTINF:{r[5] or -1},{r[3]} - {r[4]}\n{r[2]}" for r in rows]) + "\n"
    try:
        if f.read_text(encoding="utf-8") == text:
            return False
    except OSError:
        pass
    save(f, text)
    return True


def mixes(shelf, history, lib):
    """{title: files} made from the plays and the liked songs."""
    out = {}
    if lib["liked"]:
        out["Liked Songs"] = shelf.pick(lib["tracks"][i] for i in lib["liked"])
    tracks = history.get("tracks", [])
    if tracks:
        out["Top 100"] = shelf.pick(tracks, 100)       # already most played first
        for year in sorted({y for t in tracks for y in t[6]}, reverse=True):
            ranked = sorted((t for t in tracks if t[6].get(year, 0) >= 2),
                            key=lambda t: t[6][year], reverse=True)
            out[f"Top 50 · {year}"] = shelf.pick(ranked, 50)
    # ListenBrainz has the Spotify years and every Tauon play since; the export
    # only stands in for it offline
    recent = recent_listens(90)
    if recent is None:
        recent = [t[:3] + [t[5]] for t in tracks if t[5]]
    out["On Repeat"] = shelf.pick(sorted((t for t in recent if t[3] >= 2),
                                         key=lambda t: t[3], reverse=True), 50)
    if tracks:
        # played even once lately: not forgotten
        lately = {(primary(t[0]), song(t[1])) for t in recent}
        year_ago = (datetime.datetime.now(datetime.timezone.utc)
                    - datetime.timedelta(days=365)).strftime("%Y-%m-%dT%H:%M:%SZ")
        out["Forgotten Favourites"] = shelf.pick(
            (t for t in tracks if t[3] >= 10 and t[4] < year_ago
             and (primary(t[0]), song(t[1])) not in lately), 100)
    return out


def tail(path):
    """artist/album/file: the same file whatever folder Jellyfin mounts the library at."""
    return "/".join(Path(path).parts[-3:]).casefold()


class Jellyfin:
    def __init__(self, token):
        self.auth = (f'MediaBrowser Client="music-scout", Device="{os.uname().nodename}", '
                     f'DeviceId="music-scout", Version="1.0", Token="{token}"')

    def __call__(self, method, path, body=None, **query):
        url = JELLYFIN + path + ("?" + urllib.parse.urlencode(query) if query else "")
        req = urllib.request.Request(
            url, method=method, data=None if body is None else json.dumps(body).encode(),
            headers={"Authorization": self.auth, "Content-Type": "application/json",
                     "User-Agent": UA})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                text = r.read()
        except urllib.error.HTTPError as e:     # say which call, and Jellyfin's reason
            raise ValueError(f"{method} {path}: HTTP {e.code} "
                             f"{e.read()[:300].decode(errors='replace')}") from None
        return json.loads(text) if text else None

    def user(self, name):
        users = [u for u in self("GET", "/Users") if not u.get("Policy", {}).get("IsDisabled")]
        if name:
            match = [u for u in users if u["Name"].casefold() == name.casefold()]
            if not match:
                raise ValueError(f"no Jellyfin user {name!r} (there are: "
                                 + ", ".join(u["Name"] for u in users) + ")")
            return match[0]["Id"]
        admins = [u for u in users if u.get("Policy", {}).get("IsAdministrator")]
        if len(users) == 1 or len(admins) == 1:
            return (users if len(users) == 1 else admins)[0]["Id"]
        raise ValueError("several Jellyfin users: say whose playlists these are with "
                         "--jellyfin-user (" + ", ".join(u["Name"] for u in users) + ")")

    def entries(self, pid, user):
        """[(item id, entry id), ...] in the playlist's order."""
        out, start = [], 0
        while True:
            page = self("GET", f"/Playlists/{pid}/Items", userId=user, startIndex=start,
                        limit=2000)
            out += [(i["Id"], i["PlaylistItemId"]) for i in page["Items"]]
            start += len(page["Items"])
            if not page["Items"] or start >= page.get("TotalRecordCount", 0):
                return out

    def set_items(self, pid, user, ids):
        """Make the playlist hold ids, in order, keeping its id (and with it a
        phone's downloads of it). An API key may add and remove entries, but
        replacing or moving them asks for a signed-in user: so the gone ones
        go, the new ones are inserted where they belong, and only an order
        that no longer fits is cleared and refilled."""
        for attempt in range(3):
            now = self.entries(pid, user)
            if [i for i, _ in now] == ids:
                return
            if attempt == 2:
                raise ValueError(f"playlist {pid} won't take its new order")
            want, seen, keep, drop = set(ids), set(), [], []
            for i, entry in now:
                if i in want and i not in seen:
                    seen.add(i)
                    keep.append(i)
                else:
                    drop.append(entry)
            # an order that no longer fits, or a first try that didn't take
            # (Jellyfin drops every copy of a duplicate at once): start over
            if attempt or keep != [i for i in ids if i in seen]:
                drop, seen = [e for _, e in now], set()
            # a hundred ids a call keeps the URL inside the server's limit
            for n in range(0, len(drop), 100):
                self("DELETE", f"/Playlists/{pid}/Items", entryIds=",".join(drop[n:n + 100]))
            pos, n = 0, 0
            while n < len(ids):
                if ids[n] in seen:
                    pos, n = pos + 1, n + 1
                    continue
                run = []
                while n < len(ids) and ids[n] not in seen and len(run) < 100:
                    run.append(ids[n])
                    n += 1
                self("POST", f"/Playlists/{pid}/Items", ids=",".join(run), userId=user,
                     position=pos)
                pos += len(run)

    def items(self, user, kind, fields=""):
        out, start = [], 0
        while True:
            page = self("GET", "/Items", userId=user, Recursive="true", IncludeItemTypes=kind,
                        Fields=fields, StartIndex=start, Limit=2000)
            out += page["Items"]
            start += len(page["Items"])
            if not page["Items"] or start >= page.get("TotalRecordCount", 0):
                return out


def jellyfin_sync(lists, user_name, quiet):
    """lists: [(key, title, files)]. Creates the missing playlists, rewrites the
    changed ones and deletes the ones that went away; only those it made."""
    jf = Jellyfin(JF_TOKEN.read_text().strip())
    user = jf.user(user_name)
    have = {tail(i["Path"]): i["Id"] for i in jf.items(user, "Audio", "Path") if i.get("Path")}
    if not have:        # rescanning, remounted, or the user can't see the library
        raise ValueError("Jellyfin lists no music for this user; left the playlists alone")
    alive = {i["Id"] for i in jf.items(user, "Playlist")}
    try:
        state = json.loads(JF_STATE.read_text())
    except (OSError, ValueError):
        state = {}
    made, changed, gone, new = 0, 0, 0, {}
    for key, title, rows in lists:
        # a file Jellyfin hasn't scanned yet joins on a later run
        ids = [have[t] for t in (tail(r[2]) for r in rows) if t in have]
        if not ids:
            if key in state:    # kept as it is, not deleted
                new[key] = state[key]
            continue
        digest = hashlib.md5(",".join(ids).encode()).hexdigest()
        known = state.get(key)
        if known and known["id"] in alive:
            if known["hash"] != digest:
                jf.set_items(known["id"], user, ids)
                changed += 1
            new[key] = {"id": known["id"], "hash": digest}
        else:
            r = jf("POST", "/Playlists", {"Name": title, "Ids": ids, "UserId": user,
                                          "MediaType": "Audio"})
            new[key] = {"id": r["Id"], "hash": digest}
            made += 1
        # written as it goes: a crash halfway mustn't make it create them all again
        save(JF_STATE, json.dumps({**state, **new}))
    # only a playlist whose file is gone goes; nothing that merely matched nothing
    wanted = {key for key, _, _ in lists}
    for key, known in state.items():
        if key not in wanted and known["id"] in alive:
            jf("DELETE", f"/Items/{known['id']}")
            gone += 1
    save(JF_STATE, json.dumps(new))
    if not quiet or made or changed or gone:
        print(f"Jellyfin: {len(new)} playlists ({made} new, {changed} changed, "
              f"{gone} removed)", file=sys.stderr)


def cmd_playlists(args):
    history, lib = plays(), saved()
    if not (history.get("tracks") or lib["playlists"] or lib["liked"]):
        if args.quiet:      # the import hook and the timer, before any import
            return 0
        sys.exit("no Spotify data yet: music-scout spotify my_spotify_data.zip "
                 "(the streaming history and/or the account data)")
    # the import hook and the daily timer can meet; two runs would make every
    # Jellyfin playlist twice
    lock = open(Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "music-scout-playlists.lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    shelf = Shelf()
    out = Path(args.out) if args.out else PLAYLISTS
    written, changed, waiting, tracks, synced = {}, 0, 0, 0, []
    for folder, lists in (("Mixes", mixes(shelf, history, lib).items()),
                          ("Spotify", ((p["name"], shelf.pick(lib["tracks"][i] for i in p["tracks"]))
                                       for p in lib["playlists"]))):
        taken = written.setdefault(out / folder, set())
        for title, rows in lists:
            if len(rows) < args.min:
                waiting += folder == "Spotify"
                continue
            f = out / folder / m3u_name(title, taken)
            changed += write_m3u(f, title, rows)
            tracks += len(rows)
            synced.append((f"{folder}/{f.stem}", title, rows))
    # a playlist that no longer qualifies (the library shrank, it was renamed)
    for d, names in written.items():
        for f in (d.glob("*.m3u8") if d.is_dir() else ()):
            if f.stem.casefold() not in names:
                f.unlink()
    count = sum(len(n) for n in written.values())
    if not args.quiet or changed:
        print(f"{count} playlists ({changed} changed, {tracks} tracks) in {out}; "
              f"{waiting} Spotify playlists have fewer than {args.min} tracks in the "
              f"library yet", file=sys.stderr)
    if JF_TOKEN.exists() and not args.no_jellyfin:
        try:
            jellyfin_sync(synced, args.jellyfin_user, args.quiet)
        except (OSError, ValueError, KeyError) as e:   # down, or the key revoked
            print(f"Jellyfin: {e}", file=sys.stderr)
            return 1


def cmd_missing(args):
    out = missing(args.limit, args.min_plays)
    if args.json:
        print(json.dumps(out, ensure_ascii=False))
        return
    if not (PLAYS.exists() or SAVED.exists()):
        sys.exit("no Spotify data yet: music-scout spotify my_spotify_data.zip")
    for g in out:
        print(f"{g['artist']} - {g['album']}  ({g['why']})")


def cmd_foryou(args):
    last = CACHE / "foryou.json"
    if args.last:
        return print_last(last)
    artists, _, track_artists = library()
    names = {norm(n) for n in artists.values()} | set(track_artists)
    db = sqlite3.connect(f"file:{LIBRARY}?mode=ro", uri=True)
    albums = dict(db.execute(
        "select mb_albumartistid, count(*) from albums group by mb_albumartistid"))
    played = plays()["artists"]

    def taste(name):                # 0 unplayed, ~2 at 100 plays, ~4 at 10 000
        return math.log10(1 + played.get(norm(name), ["", 0, 0])[1])
    # more albums owned and more plays, more say; an unplayed shelf still counts
    seeds = {m: (n, albums.get(m, 1) ** 0.5 * (0.5 + taste(n))) for m, n in artists.items()}
    # the most-played artists the library lacks are taste too
    for key, (name, pts, _) in sorted(played.items(), key=lambda kv: -kv[1][1])[:args.seeds]:
        if key in names:
            continue
        try:
            mbid = resolve(name, track_artists)
        except musicbrainzngs.MusicBrainzError:
            continue
        if mbid and mbid not in seeds:
            seeds[mbid] = (name, taste(name))
    # heard a fair bit already: not a discovery (`missing` covers those)
    names |= {k for k, v in played.items() if v[2] >= 10}
    score, why, label = {}, {}, {}
    for i, (mbid, (name, weight)) in enumerate(seeds.items(), 1):
        if sys.stderr.isatty():
            print(f"\r\033[K{i}/{len(seeds)} {name[:50]}", end="", file=sys.stderr)
        try:
            sim = similar_to(mbid)
        except Exception as e:      # offline, rate-limited: use what there is
            print(f"\n{name}: {e}", file=sys.stderr)
            continue
        sim = sim[:15]              # the tail is where the famous names pile up
        top = max((a["score"] for a in sim), default=0) or 1
        for a in sim:
            m = a["artist_mbid"]
            if m in seeds or norm(a["name"]) in names:
                continue
            part = weight * a["score"] / top
            score[m] = score.get(m, 0) + part
            why.setdefault(m, []).append((part, name))
            label[m] = a["name"]
    if sys.stderr.isatty():
        print("\r\033[K", end="", file=sys.stderr)
    # one strong resemblance shouldn't outrank several: need two or more
    ranked = sorted((m for m in score if len(why[m]) >= 2),
                    key=score.get, reverse=True)[:400]
    # Everyone's neighbours include the Beatles. Dividing by the square root of
    # the audience lets the small names a few library artists share come first.
    heard = listeners(ranked)
    if heard:
        for m in ranked:
            score[m] /= max(heard.get(m, 0), 50) ** 0.5
        ranked.sort(key=score.get, reverse=True)
    ranked = ranked[:args.limit]
    out = [{"name": label[m], "mbid": m, "score": round(score[m], 4),
            "because": [n for _, n in sorted(why[m], reverse=True)[:3]]} for m in ranked]
    save(last, json.dumps(out, ensure_ascii=False))
    if args.json:
        print(json.dumps(out, ensure_ascii=False))
        return
    for a in out:
        print(f"{a['name']:<32}  like {', '.join(a['because'])}")


def cmd_similar(args):
    artists, _, track_artists = library()
    mbid = resolve(args.artist, track_artists)
    out = []
    if mbid:
        names = {norm(n) for n in artists.values()} | set(track_artists)
        for a in similar_to(mbid):
            out.append({"name": a["name"], "mbid": a["artist_mbid"], "score": a["score"],
                        "owned": a["artist_mbid"] in artists or norm(a["name"]) in names})
        if args.new_only:
            out = [a for a in out if not a["owned"]]
        out = out[:args.limit]
    if args.json:
        print(json.dumps({"artist": args.artist, "mbid": mbid, "similar": out},
                         ensure_ascii=False))
        return
    if not mbid:
        sys.exit(f"couldn't identify {args.artist!r} on MusicBrainz")
    for a in out:
        print(f"{'*' if a['owned'] else ' '} {a['name']}")
    print("* = in your library", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    n = sub.add_parser("new", help="new releases from library artists")
    n.add_argument("--days", type=int, default=90, help="look this far back (default 90)")
    n.add_argument("--ahead", type=int, default=60, help="and this far ahead (default 60)")
    n.add_argument("--all-types", action="store_true",
                   help="include live albums, compilations, remixes, ...")
    n.add_argument("--max-age", type=int, default=24, metavar="HOURS",
                   help="reuse a cached discography younger than this (default 24)")
    n.add_argument("--include-dead", action="store_true",
                   help="keep artists who have died (composers, mostly)")
    n.add_argument("--json", action="store_true")
    n.add_argument("--last", action="store_true",
                   help="print the previous run's JSON result and exit")
    n.set_defaults(fn=cmd_new)
    f = sub.add_parser("foryou", help="artists to try, from the whole library")
    f.add_argument("--limit", type=int, default=30)
    f.add_argument("--seeds", type=int, default=200, metavar="N",
                   help="also start from the N most-played Spotify artists (default 200)")
    f.add_argument("--json", action="store_true")
    f.add_argument("--last", action="store_true",
                   help="print the previous run's JSON result and exit")
    f.set_defaults(fn=cmd_foryou)
    sp = sub.add_parser("spotify", help="read Spotify data exports (history, account data)")
    sp.add_argument("export", nargs="+",
                    help="my_spotify_data.zip, or the folder unpacked from it; both kinds "
                         "of export can be given at once")
    sp.set_defaults(fn=cmd_spotify)
    pl = sub.add_parser("playlists", help="write the Spotify playlists and mixes as .m3u8")
    pl.add_argument("--out", default="",
                    help=f"write under here (default $MUSIC_SCOUT_PLAYLISTS, {PLAYLISTS})")
    pl.add_argument("--min", type=int, default=5, metavar="N",
                    help="leave out Spotify playlists with fewer tracks in the library (default 5)")
    pl.add_argument("--quiet", action="store_true", help="say nothing unless something changed")
    pl.add_argument("--no-jellyfin", action="store_true",
                    help=f"only the files, even with a key in {JF_TOKEN}")
    pl.add_argument("--jellyfin-user", default="", metavar="NAME",
                    help="whose playlists they are, when Jellyfin has several users")
    pl.set_defaults(fn=cmd_playlists)
    m = sub.add_parser("missing", help="most-played Spotify albums the library lacks")
    m.add_argument("--limit", type=int, default=30)
    m.add_argument("--min-plays", type=int, default=0, metavar="N")
    m.add_argument("--json", action="store_true")
    m.set_defaults(fn=cmd_missing)
    b = sub.add_parser("buylist", help="the missing albums as a page of store links")
    b.add_argument("--min-plays", type=int, default=25, metavar="N",
                   help="leave out albums played fewer times (default 25)")
    b.add_argument("--out", default="", help="write here instead of the cache")
    b.add_argument("--no-open", action="store_true", help="don't open it in the browser")
    b.set_defaults(fn=cmd_buylist)
    w = sub.add_parser("weekly", help="the ListenBrainz playlist made for you this week")
    w.add_argument("--kind", default="weekly-exploration",
                   help="weekly-exploration (default) or weekly-jams")
    w.add_argument("--user", default="", help="someone else's (no token needed)")
    w.add_argument("--json", action="store_true")
    w.set_defaults(fn=cmd_weekly)
    s = sub.add_parser("similar", help="artists like this one")
    s.add_argument("artist")
    s.add_argument("--limit", type=int, default=15)
    s.add_argument("--new-only", action="store_true", help="hide artists already owned")
    s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_similar)
    args = ap.parse_args()
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
