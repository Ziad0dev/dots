#!/usr/bin/env python3
"""Discovery helpers on top of the beets library.

  music-scout new [--days N]     releases by artists in the library that it lacks
  music-scout similar ARTIST     artists like ARTIST (ListenBrainz), owned ones marked
  music-scout foryou             artists the library lacks, ranked by how many
                                 library artists they resemble
  music-scout spotify ZIP        read a Spotify "extended streaming history" export;
                                 foryou then weighs artists by how much they were
                                 played, and `missing` has something to list
  music-scout missing            most-played Spotify albums the library lacks
  music-scout buylist            the same as a page of Bandcamp / Qobuz store links
  music-scout weekly             this week's ListenBrainz playlist made for you
                                 (needs the user token, one line, in
                                 ~/.config/music-scout/listenbrainz-token)
"""
import argparse
import datetime
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
UA = "music-scout/1.0 (https://github.com/Ziad0dev/dots)"
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


def plays():
    """What `spotify` stored: {"artists": {norm name: [name, score, plays]},
    "albums": [[artist, album, score, plays], ...]}; empty before an import."""
    if not PLAYS.exists():
        return {"artists": {}, "albums": []}
    return json.loads(PLAYS.read_text())


def save(f, text):
    """Whole or not at all: the panel runs several of these at once, and one
    may be reading the file another is replacing."""
    f.parent.mkdir(parents=True, exist_ok=True)
    tmp = f.with_name(f"{f.name}.{os.getpid()}.tmp")
    tmp.write_text(text)
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


def cmd_weekly(args):
    """ListenBrainz builds these every Monday from the account's listens:
    weekly-exploration is music it thinks you'd like and haven't played,
    weekly-jams is your own favourites."""
    token = TOKEN.read_text().strip() if TOKEN.exists() else ""
    user = args.user
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


def cmd_spotify(args):
    src = Path(args.export)
    rows = []
    if src.is_dir():
        for f in sorted(src.rglob("Streaming_History_Audio_*.json")):
            rows += json.loads(f.read_text())
    else:
        with zipfile.ZipFile(src) as z:
            for n in sorted(z.namelist()):
                if re.search(r"Streaming_History_Audio_[^/]*\.json$", n):
                    rows += json.loads(z.read(n))
    # under 30 seconds is a skip, not a listen
    rows = [r for r in rows if r.get("master_metadata_track_name")
            and r.get("master_metadata_album_artist_name")
            and (r.get("ms_played") or 0) >= 30000]
    if not rows:
        sys.exit(f"no Streaming_History_Audio_*.json plays in {src}")
    newest = max(r["ts"] for r in rows)
    year_ago = str(int(newest[:4]) - 1) + newest[4:]
    artists, albums = {}, {}
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
    save(PLAYS, json.dumps({
        "through": newest,
        "artists": {k: v for k, v in artists.items() if v[2] >= 3},
        "albums": sorted((b for b in albums.values() if b[3] >= 5),
                         key=lambda b: b[2], reverse=True)}, ensure_ascii=False))
    print(f"{len(rows)} plays of {len(artists)} artists through {newest[:10]} -> {PLAYS}",
          file=sys.stderr)


def stores(artist, album):
    """Where the album can be bought as a lossless download: store search pages."""
    q = urllib.parse.quote_plus(f"{artist} {album}")
    return {"bandcamp": f"https://bandcamp.com/search?q={q}&item_type=a",
            "qobuz": f"https://www.qobuz.com/se-en/search?q={q}"}


def missing(limit, min_plays=0):
    db = sqlite3.connect(f"file:{LIBRARY}?mode=ro", uri=True)
    owned = {(norm(a), edition(b)) for a, b in db.execute(
        "select albumartist, album from albums union select artist, album from items")}
    return [{"artist": a, "album": b, "plays": n, **stores(a, b)}
            for a, b, _, n in plays()["albums"]
            if n >= min_plays and (norm(a), edition(b)) not in owned][:limit]


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
<p>__COUNT__ albums you played on Spotify at least __MIN__ times and don't have in the library, most played first. Tick one off once it's bought; ticks are remembered in this browser.</p>
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
    if not PLAYS.exists():
        sys.exit("no listening history yet: music-scout spotify my_spotify_data.zip")
    e = html.escape
    rows = "".join(
        f'<tr><td><input type="checkbox" data-k="{e(norm(g["artist"]) + "/" + edition(g["album"]))}"></td>'
        f'<td class="n">{g["plays"]}</td>'
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


def cmd_missing(args):
    out = missing(args.limit, args.min_plays)
    if args.json:
        print(json.dumps(out, ensure_ascii=False))
        return
    if not PLAYS.exists():
        sys.exit("no listening history yet: music-scout spotify my_spotify_data.zip")
    for g in out:
        print(f"{g['plays']:>5}  {g['artist']} - {g['album']}")


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
    sp = sub.add_parser("spotify", help="read a Spotify extended streaming history export")
    sp.add_argument("export", help="my_spotify_data.zip, or the folder unpacked from it")
    sp.set_defaults(fn=cmd_spotify)
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
    args.fn(args)


if __name__ == "__main__":
    main()
