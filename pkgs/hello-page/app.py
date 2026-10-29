#!/usr/bin/env python3
import base64
import errno
import hashlib
import hmac
import math
import json
import mimetypes
import os
import random
import re
import sqlite3
import sys
import threading
import time
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    from zoneinfo import ZoneInfo
except ImportError:
    ZoneInfo = None

ROOT = os.path.dirname(os.path.abspath(__file__))
STATIC = os.path.join(ROOT, "static")
DB_PATH = os.environ.get("DB_PATH", os.path.join(ROOT, "data.db"))
CONFIG_PATH = os.environ.get("CONFIG_PATH", os.path.join(ROOT, "config.json"))
CONTENT_DIR = os.environ.get("CONTENT_DIR", os.path.join(ROOT, "content"))

_lock = threading.Lock()


def load_config():
    with open(CONFIG_PATH, encoding="utf-8") as f:
        cfg = json.load(f)
    for key, current in list(cfg.items()):
        env = os.environ.get("SITE_" + key.upper())
        if env is None:
            continue
        if isinstance(current, bool):
            cfg[key] = env.strip().lower() in ("1", "true", "yes", "on")
        elif isinstance(current, float):
            cfg[key] = float(env)
        elif isinstance(current, int):
            cfg[key] = int(env)
        else:
            cfg[key] = env
    return cfg


CFG = load_config()
_cfg_stamp = os.path.getmtime(CONFIG_PATH)


def refresh_config():
    """Pick up config.json edits without a restart."""
    global CFG, _cfg_stamp
    try:
        stamp = os.path.getmtime(CONFIG_PATH)
    except OSError:
        return
    if stamp == _cfg_stamp:
        return
    _cfg_stamp = stamp
    try:
        CFG = load_config()
    except Exception:
        pass


_last_good = {}


def load_json(name, default):
    """A broken content file costs that one file, never the page."""
    path = os.path.join(CONTENT_DIR, name)
    if not os.path.exists(path):
        return default
    try:
        with open(path, encoding="utf-8") as f:
            value = json.load(f)
    except (ValueError, OSError) as err:
        sys.stderr.write(f"!! {name} is broken, using the last good copy: {err}\n")
        return _last_good.get(name, default)
    _last_good[name] = value
    return value


def tz(name):
    if ZoneInfo is None:
        return None
    try:
        return ZoneInfo(name)
    except Exception:
        return None


def her_now():
    return datetime.now(tz(CFG["her_timezone"]))


def her_today():
    return her_now().date()


def day_index():
    start = date.fromisoformat(CFG["start_date"])
    return (her_today() - start).days


SCHEMA = (
    "CREATE TABLE IF NOT EXISTS notes ("
    "day TEXT PRIMARY KEY, body TEXT NOT NULL, written_at TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS hearts (id INTEGER PRIMARY KEY, sent_at TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS visits (day TEXT PRIMARY KEY, seen_at TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS messages ("
    "id INTEGER PRIMARY KEY, who TEXT NOT NULL, body TEXT NOT NULL, "
    "at TEXT NOT NULL, read_at TEXT)",
    "CREATE TABLE IF NOT EXISTS seen (who TEXT PRIMARY KEY, at TEXT NOT NULL)",
)


def db():
    """Assert the schema on every connection: the file can be moved or replaced
    under a running process, and an empty database should not take the page down."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    for statement in SCHEMA:
        conn.execute(statement)
    return conn


def init_db():
    db().close()


def verse_state():
    lines = load_json("verse.json", [])
    idx = day_index()
    if idx < 0 or not lines:
        return {"revealed": [], "today": None, "day": 0, "total": len(lines), "done": False}
    idx = min(idx, len(lines) - 1)
    revealed = lines[: idx + 1]
    done = idx >= len(lines) - 1
    return {
        "revealed": revealed[:-1] if revealed else [],
        "today": revealed[-1] if revealed else None,
        "day": idx + 1,
        "total": len(lines),
        "done": done,
    }


MOONS = [
    ("new moon", "\u25cf"),
    ("waxing crescent", "\u263d"),
    ("first quarter", "\u25d1"),
    ("waxing gibbous", "\u25d5"),
    ("full moon", "\u25cb"),
    ("waning gibbous", "\u25d4"),
    ("last quarter", "\u25d0"),
    ("waning crescent", "\u263e"),
]


MANSIONS = [
    "Al-Sharatain", "Al-Butain", "Al-Thurayya", "Al-Dabaran", "Al-Haq'ah", "Al-Han'ah",
    "Al-Dhira", "Al-Nathrah", "Al-Tarf", "Al-Jabhah", "Al-Zubrah", "Al-Sarfah",
    "Al-Awwa", "Al-Simak", "Al-Ghafr", "Al-Zubana", "Al-Iklil", "Al-Qalb",
    "Al-Shaulah", "Al-Na'aim", "Al-Baldah", "Sa'd al-Dhabih", "Sa'd Bula",
    "Sa'd al-Su'ud", "Sa'd al-Akhbiyah", "Al-Fargh al-Muqaddam",
    "Al-Fargh al-Mu'akhkhar", "Batn al-Hut",
]


def moon_for(day):
    ref = datetime(2000, 1, 6, 18, 14, tzinfo=timezone.utc)
    noon = datetime(day.year, day.month, day.day, 12, tzinfo=timezone.utc)
    turns = ((noon - ref).total_seconds() / 86400.0) / 29.530588853
    phase = turns - math.floor(turns)
    name, glyph = MOONS[int(phase * 8 + 0.5) % 8]
    synodic = 29.530588853
    d = jd(noon.replace(tzinfo=None)) - 2451545.0
    lon = moon_longitude(d)
    m = int(lon // (360 / 28)) % 28

    def days_until(target):
        return round(((target - phase) % 1.0) * synodic)

    return {
        "name": name,
        "glyph": glyph,
        "illumination": round((1 - math.cos(2 * math.pi * phase)) * 50),
        "age": round(phase * synodic),
        "mansion": m + 1,
        "mansion_name": MANSIONS[m],
        "until_full": days_until(0.5),
        "until_new": days_until(0.0),
    }


def deck_order(cycle, size):
    order = list(range(size))
    random.Random(f"{CFG['deck_seed']}:{cycle}").shuffle(order)
    return order


def poem_of_day():
    poems = load_json("poems.json", [])
    if not poems:
        return None
    idx = max(day_index(), 0)
    cycle, offset = divmod(idx, len(poems))
    n = deck_order(f"pm{cycle}", len(poems))[offset]
    return {"text": poems[n], "number": n + 1, "total": len(poems)}


def record_of_day():
    records = load_json("records.json", [])
    if not records:
        return None
    idx = max(day_index(), 0)
    cycle, offset = divmod(idx, len(records))
    return records[deck_order(cycle, len(records))[offset]]


def fallback_note():
    lines = load_json("fallbacks.json", ["thinking about you."])
    idx = max(day_index(), 0)
    cycle, offset = divmod(idx, len(lines))
    return lines[deck_order(f"fb{cycle}", len(lines))[offset]]


def note_for(day):
    with db() as conn:
        row = conn.execute("SELECT body FROM notes WHERE day = ?", (day.isoformat(),)).fetchone()
    return row["body"] if row else None


def push(body, tags="heart", title=None):
    topic = CFG.get("ntfy_topic", "").strip()
    if not topic:
        return False
    url = CFG.get("ntfy_server", "https://ntfy.sh").rstrip("/") + "/" + topic
    req = urllib.request.Request(
        url,
        data=body.encode("utf-8"),
        headers={
            "Title": (title or CFG["her_name"]).encode("utf-8").decode("latin-1", "replace"),
            "Tags": tags,
            "Priority": "default",
        },
    )
    try:
        urllib.request.urlopen(req, timeout=6).read()
        return True
    except Exception:
        return False


def send_heart():
    return push(CFG.get("heart_message", "she's thinking about you"))


def touch_seen(who):
    with _lock, db() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO seen VALUES (?, ?)",
            (who, datetime.now(timezone.utc).isoformat(timespec="seconds")),
        )


def seen_map():
    with db() as conn:
        return {r["who"]: r["at"] for r in conn.execute("SELECT who, at FROM seen")}


def thread(limit=200):
    with db() as conn:
        rows = conn.execute(
            "SELECT id, who, body, at, read_at FROM messages ORDER BY id DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [dict(r) for r in reversed(rows)]



SIGNS = ["Aries","Taurus","Gemini","Cancer","Leo","Virgo",
         "Libra","Scorpio","Sagittarius","Capricorn","Aquarius","Pisces"]
GLYPHS = ["♈","♉","♊","♋","♌","♍","♎","♏","♐","♑","♒","♓"]

def jd(dt):
    return dt.replace(tzinfo=timezone.utc).timestamp() / 86400.0 + 2440587.5

def norm(x):
    return x % 360.0

def sign_of(lon):
    i = int(norm(lon) // 30)
    return {"sign": SIGNS[i], "glyph": GLYPHS[i], "degree": round(norm(lon) % 30, 1)}

def sun_longitude(d):
    L = norm(280.460 + 0.9856474 * d)
    g = math.radians(norm(357.528 + 0.9856003 * d))
    return norm(L + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g))

def moon_longitude(d):
    L = norm(218.316 + 13.176396 * d)
    M = math.radians(norm(134.963 + 13.064993 * d))
    D = math.radians(norm(297.850 + 12.190749 * d))
    S = math.radians(norm(357.529 + 0.98560028 * d))
    F = math.radians(norm(93.272 + 13.229350 * d))
    lon = (L + 6.289 * math.sin(M)
           - 1.274 * math.sin(2 * D - M)
           + 0.658 * math.sin(2 * D)
           + 0.214 * math.sin(2 * M)
           - 0.186 * math.sin(S)
           - 0.114 * math.sin(2 * F)
           + 0.059 * math.sin(2 * D - 2 * M)
           + 0.057 * math.sin(2 * D - S - M)
           + 0.053 * math.sin(2 * D + M)
           - 0.046 * math.sin(2 * D - S)
           - 0.041 * math.sin(M - S))
    return norm(lon)

# JPL approximate elements, valid 1800-2050
ELEMENTS = {
    "mercury": (0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593,
                0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081),
    "earth":   (1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0,
                0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0),
}

def heliocentric(body, d):
    a0,e0,I0,L0,w0,O0, da,de,dI,dL,dw,dO = ELEMENTS[body]
    T = d / 36525.0
    a = a0 + da*T; e = e0 + de*T
    I = math.radians(I0 + dI*T)
    L = norm(L0 + dL*T); w = w0 + dw*T; O = norm(O0 + dO*T)
    M = math.radians(norm(L - w))
    E = M
    for _ in range(60):
        dE = (E - e*math.sin(E) - M) / (1 - e*math.cos(E))
        E -= dE
        if abs(dE) < 1e-12:
            break
    xv = a*(math.cos(E) - e)
    yv = a*math.sqrt(1 - e*e)*math.sin(E)
    v = math.atan2(yv, xv); r = math.hypot(xv, yv)
    u = v + math.radians(norm(w - O)); Or = math.radians(O)
    x = r*(math.cos(Or)*math.cos(u) - math.sin(Or)*math.sin(u)*math.cos(I))
    y = r*(math.sin(Or)*math.cos(u) + math.cos(Or)*math.sin(u)*math.cos(I))
    z = r*(math.sin(u)*math.sin(I))
    return x, y, z

def mercury_geocentric_longitude(d):
    mx,my,mz = heliocentric("mercury", d)
    ex,ey,ez = heliocentric("earth", d)
    return norm(math.degrees(math.atan2(my-ey, mx-ex)))

def mercury_retrograde(d):
    a = mercury_geocentric_longitude(d - 0.5)
    b = mercury_geocentric_longitude(d + 0.5)
    diff = (b - a + 540) % 360 - 180
    return diff < 0

CHALDEAN = ["Saturn","Jupiter","Mars","Sun","Venus","Mercury","Moon"]
DAY_RULER = {0:"Moon", 1:"Mars", 2:"Mercury", 3:"Jupiter", 4:"Venus", 5:"Saturn", 6:"Sun"}
PLANET_GLYPH = {"Saturn":"♄","Jupiter":"♃","Mars":"♂","Sun":"☉","Venus":"♀","Mercury":"☿","Moon":"☾"}

def planetary_hour(now, sunrise, sunset, next_sunrise, prev_sunset):
    """Unequal hours: 12 between sunrise and sunset, 12 between sunset and next sunrise."""
    if now < sunrise:
        start, end, night, ruler_day = prev_sunset, sunrise, True, (now.weekday() - 1) % 7
    elif now < sunset:
        start, end, night, ruler_day = sunrise, sunset, False, now.weekday()
    else:
        start, end, night, ruler_day = sunset, next_sunrise, True, now.weekday()
    span = (end - start).total_seconds() / 12.0
    if span <= 0:
        return None
    idx = min(int((now - start).total_seconds() / span), 11)
    day_ruler = DAY_RULER[ruler_day]
    first = CHALDEAN.index(day_ruler)
    ruler = CHALDEAN[(first + idx + (12 if night else 0)) % 7]
    return {
        "ruler": ruler,
        "glyph": PLANET_GLYPH[ruler],
        "index": idx + 1,
        "night": night,
        "ends": (start + timedelta(seconds=span * (idx + 1))).strftime("%H:%M"),
        "day_ruler": day_ruler,
    }


_cache = {}
_cache_lock = threading.Lock()


def cached(key, ttl, producer):
    now = time.time()
    with _cache_lock:
        hit = _cache.get(key)
        if hit and hit[0] > now:
            return hit[1]
    try:
        value = producer()
    except Exception:
        value = None
    with _cache_lock:
        stale = _cache.get(key)
        if value is None:
            return stale[1] if stale else None
        _cache[key] = (now + ttl, value)
    return value


def get_json(url, timeout=6):
    req = urllib.request.Request(url, headers={"User-Agent": "quiet/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def lastfm(method, user, **extra):
    key = CFG.get("lastfm_api_key", "").strip()
    if not user or not key:
        return None
    params = {"method": method, "user": user, "api_key": key, "format": "json"}
    params.update(extra)
    return get_json("https://ws.audioscrobbler.com/2.0/?" + urllib.parse.urlencode(params))


def recent_for(user):
    data = lastfm("user.getrecenttracks", user, limit=1)
    if not data:
        return None
    tracks = (data.get("recenttracks") or {}).get("track") or []
    if isinstance(tracks, dict):
        tracks = [tracks]
    if not tracks:
        return None
    t = tracks[0]
    images = {i.get("size"): i.get("#text") for i in t.get("image", []) if i.get("#text")}
    return {
        "track": t.get("name"),
        "artist": (t.get("artist") or {}).get("#text"),
        "album": (t.get("album") or {}).get("#text"),
        "art": images.get("extralarge") or images.get("large") or images.get("medium"),
        "now": (t.get("@attr") or {}).get("nowplaying") == "true",
        "url": t.get("url"),
    }


def fetch_lastfm():
    return recent_for(CFG.get("lastfm_user", "").strip())


def fetch_lastfm_mine():
    return recent_for(CFG.get("my_lastfm_user", "").strip())


def top_artists(user, count=30):
    data = lastfm("user.gettopartists", user, period="7day", limit=count)
    if not data:
        return []
    artists = (data.get("topartists") or {}).get("artist") or []
    if isinstance(artists, dict):
        artists = [artists]
    return [a.get("name") for a in artists if a.get("name")]


def fetch_overlap():
    hers = top_artists(CFG.get("lastfm_user", "").strip())
    his = top_artists(CFG.get("my_lastfm_user", "").strip())
    if not hers or not his:
        return None
    lower = {n.lower(): n for n in hers}
    shared = [lower[n.lower()] for n in his if n.lower() in lower]
    seen, out = set(), []
    for name in shared:
        if name.lower() not in seen:
            seen.add(name.lower())
            out.append(name)
    return out[:4]


WEATHER_WORDS = {
    0: "clear", 1: "mostly clear", 2: "half a sky", 3: "overcast",
    45: "fog", 48: "freezing fog",
    51: "drizzle", 53: "drizzle", 55: "heavy drizzle",
    56: "freezing drizzle", 57: "freezing drizzle",
    61: "rain", 63: "rain", 65: "hard rain",
    66: "freezing rain", 67: "freezing rain",
    71: "snow", 73: "snow", 75: "deep snow", 77: "snow grains",
    80: "rain in bursts", 81: "rain in bursts", 82: "downpour",
    85: "snow squalls", 86: "snow squalls",
    95: "thunder", 96: "thunder and hail", 99: "thunder and hail",
}


def fetch_weather_at(lat, lon, place, tzname):
    if lat is None or lon is None:
        return None
    url = "https://api.open-meteo.com/v1/forecast?" + urllib.parse.urlencode({
        "latitude": lat, "longitude": lon,
        "current": "temperature_2m,weather_code,wind_speed_10m",
        "daily": "sunrise,sunset",
        "timezone": tzname,
        "past_days": 1,
        "forecast_days": 2,
    })
    data = get_json(url)
    cur = data.get("current") or {}
    daily = data.get("daily") or {}
    days = daily.get("time") or []
    rises, sets = daily.get("sunrise") or [], daily.get("sunset") or []
    here = datetime.now(tz(tzname)).date().isoformat()
    i = days.index(here) if here in days else min(1, len(days) - 1)

    def span(k):
        try:
            return (datetime.fromisoformat(sets[k]) - datetime.fromisoformat(rises[k])).total_seconds()
        except Exception:
            return None

    today = span(i)
    yesterday = span(i - 1) if i >= 1 else None
    out = {
        "temp": round(cur.get("temperature_2m"), 1) if cur.get("temperature_2m") is not None else None,
        "words": WEATHER_WORDS.get(cur.get("weather_code"), ""),
        "wind": round(cur.get("wind_speed_10m")) if cur.get("wind_speed_10m") is not None else None,
        "place": place,
        "sunrise": rises[i][-5:] if i < len(rises) else None,
        "sunset": sets[i][-5:] if i < len(sets) else None,
        "_suns": {
            "rise": rises[i] if i < len(rises) else None,
            "set": sets[i] if i < len(sets) else None,
            "next_rise": rises[i + 1] if i + 1 < len(rises) else None,
            "prev_set": sets[i - 1] if i >= 1 else None,
        },
    }
    if today:
        out["daylight"] = f"{int(today // 3600)}h {int(today % 3600 // 60)}m"
        if yesterday:
            d = round((today - yesterday) / 60)
            if d:
                out["daylight_change"] = (
                    f"{abs(d)} min {'more' if d > 0 else 'less'} than yesterday"
                )
    return out


AURORA_WORDS = [
    (8, "the sky is going to do something absurd"),
    (7, "a severe storm — this is a once-in-years sky"),
    (6, "a strong storm, bright and moving"),
    (5, "a real storm, overhead and green"),
    (4, "active — look up if it is dark"),
    (3, "likely overhead tonight"),
    (2, "quiet, but you are far enough north"),
]


def fetch_aurora():
    rows = get_json("https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json")
    if not rows or len(rows) < 2:
        return None
    now = datetime.now(timezone.utc)
    latest = None
    peak, peak_at = None, None
    for time_tag, kp, observed, _scale in rows[1:]:
        try:
            when = datetime.fromisoformat(time_tag).replace(tzinfo=timezone.utc)
            value = float(kp)
        except (TypeError, ValueError):
            continue
        if when <= now:
            latest = (when, value)
        elif when <= now + timedelta(hours=24):
            if peak is None or value > peak:
                peak, peak_at = value, when
    if latest is None and peak is None:
        return None
    kp = latest[1] if latest else peak
    best = max(kp, peak or 0)
    words = ""
    for floor, phrase in AURORA_WORDS:
        if best >= floor:
            words = phrase
            break
    return {
        "kp": round(kp, 1),
        "peak": round(peak, 1) if peak is not None else None,
        "peak_at": peak_at.astimezone(tz(CFG["her_timezone"])).strftime("%H:%M") if peak_at else None,
        "words": words,
        "worth_saying": best >= float(CFG.get("aurora_threshold", 3)),
    }


def fetch_weather():
    return fetch_weather_at(
        CFG.get("weather_lat"), CFG.get("weather_lon"),
        CFG.get("weather_place", ""), CFG["her_timezone"],
    )


def fetch_weather_mine():
    return fetch_weather_at(
        CFG.get("my_weather_lat"), CFG.get("my_weather_lon"),
        CFG.get("my_weather_place", ""), CFG["my_timezone"],
    )


def sky_now(suns):
    now = her_now()
    d = jd(now.astimezone(timezone.utc).replace(tzinfo=None)) - 2451545.0
    out = {
        "sun": sign_of(sun_longitude(d)),
        "moon": sign_of(moon_longitude(d)),
        "mercury_retrograde": mercury_retrograde(d),
    }
    if suns and suns.get("rise") and suns.get("set"):
        try:
            tz = now.tzinfo
            def at(key):
                return datetime.fromisoformat(suns[key]).replace(tzinfo=tz) if suns.get(key) else None
            out["hour"] = planetary_hour(now, at("rise"), at("set"), at("next_rise"), at("prev_set"))
        except Exception:
            pass
    return out


def cookie_value():
    secret = CFG.get("cookie_secret", "") or CFG.get("admin_password", "")
    mac = hmac.new(secret.encode(), b"guest", hashlib.sha256).digest()
    return base64.urlsafe_b64encode(mac).decode().rstrip("=")


def guest_gate_on():
    return bool(CFG.get("guest_token", "").strip())


def check_password(given):
    wanted = str(CFG.get("admin_password", "") or "")
    if not wanted:
        return False
    return hmac.compare_digest(str(given or ""), wanted)


class Handler(BaseHTTPRequestHandler):
    server_version = "quiet/1.0"

    def log_message(self, fmt, *args):
        if CFG.get("access_log"):
            sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))

    def send_json(self, obj, status=200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Robots-Tag", "noindex, nofollow")
        self.end_headers()
        self.wfile.write(body)

    def send_file(self, path, cache=True):
        if not os.path.isfile(path):
            return self.send_error(404)
        ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
        if ctype.startswith("text/") or ctype.endswith("json") or "javascript" in ctype:
            ctype += "; charset=utf-8"
        size = os.path.getsize(path)
        start, end = 0, size - 1
        partial = False

        rng = self.headers.get("Range", "")
        match = re.fullmatch(r"bytes=(\d*)-(\d*)", rng.strip()) if rng else None
        if match:
            first, last = match.group(1), match.group(2)
            if first:
                start = int(first)
                end = int(last) if last else size - 1
            elif last:
                start = max(0, size - int(last))
            if start >= size or start > end:
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{size}")
                self.end_headers()
                return
            end = min(end, size - 1)
            partial = True

        length = end - start + 1
        self.send_response(206 if partial else 200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        if partial:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Cache-Control", "public, max-age=60" if cache else "no-store")
        self.send_header("X-Robots-Tag", "noindex, nofollow")
        self.end_headers()
        if self.command == "HEAD":
            return
        with open(path, "rb") as f:
            f.seek(start)
            remaining = length
            while remaining > 0:
                chunk = f.read(min(65536, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def read_json(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            if length > 65536:
                return {}
            return json.loads(self.rfile.read(length) or b"{}")
        except Exception:
            return {}

    def invited(self):
        raw = self.headers.get("Cookie", "")
        for part in raw.split(";"):
            name, _, value = part.strip().partition("=")
            if name == "invited" and hmac.compare_digest(value, cookie_value()):
                return True
        return False

    def do_GET(self):
        refresh_config()
        path = self.path.split("?")[0].rstrip("/") or "/"

        if guest_gate_on():
            token = CFG["guest_token"].strip()
            if path == "/k/" + token:
                self.send_response(302)
                self.send_header("Location", "/")
                self.send_header(
                    "Set-Cookie",
                    f"invited={cookie_value()}; Path=/; Max-Age=63072000; "
                    "HttpOnly; SameSite=Lax" + ("; Secure" if CFG.get("https", True) else ""),
                )
                self.end_headers()
                return
            if not self.invited() and path != "/" + CFG["admin_path"].strip("/"):
                return self.send_error(404)

        if path == "/":
            with _lock, db() as conn:
                conn.execute(
                    "INSERT OR REPLACE INTO visits VALUES (?, ?)",
                    (her_today().isoformat(), datetime.now().isoformat(timespec="seconds")),
                )
            touch_seen("her")
            return self.send_file(os.path.join(STATIC, "index.html"), cache=False)

        if path == "/game":
            if not CFG.get("game_enabled", True):
                return self.send_error(404)
            return self.send_file(os.path.join(STATIC, "game.html"), cache=False)

        if path == "/" + CFG["admin_path"].strip("/"):
            return self.send_file(os.path.join(STATIC, "admin.html"), cache=False)

        if path == "/robots.txt":
            body = b"User-agent: *\nDisallow: /\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            return self.wfile.write(body)

        if path == "/api/today":
            return self.send_json(self.payload_today())

        if path == "/api/archive":
            return self.send_json(self.payload_archive())

        if path == "/api/thread":
            return self.send_json({"messages": thread(), "seen": seen_map()})

        if path == "/api/poems":
            return self.send_json({"poems": load_json("poems.json", [])})

        if path == "/api/live":
            weather = cached("weather", 900, fetch_weather) or {}
            suns = weather.get("_suns")
            return self.send_json({
                "playing": cached("lastfm", 40, fetch_lastfm),
                "playing_mine": cached("lastfm-mine", 40, fetch_lastfm_mine),
                "overlap": cached("overlap", 3600, fetch_overlap),
                "weather": {k: v for k, v in weather.items() if k != "_suns"} or None,
                "weather_mine": {
                    k: v for k, v in (cached("weather-mine", 900, fetch_weather_mine) or {}).items()
                    if k != "_suns"
                } or None,
                "sky": sky_now(suns),
                "aurora": cached("aurora", 1800, fetch_aurora),
            })

        if re.fullmatch(r"/audio/[A-Za-z0-9._-]+\.(mp3|m4a|ogg|opus|wav|flac)", path):
            return self.send_file(os.path.join(STATIC, "audio", os.path.basename(path)))

        if re.fullmatch(r"/[A-Za-z0-9._-]+\.(css|js|svg|png|ico|webmanifest|woff2)", path):
            return self.send_file(os.path.join(STATIC, path.lstrip("/")))

        return self.send_error(404)

    def do_HEAD(self):
        return self.do_GET()

    def do_POST(self):
        refresh_config()
        path = self.path.split("?")[0].rstrip("/")
        data = self.read_json()

        # admin routes carry their own password; everything else needs the invite
        if guest_gate_on() and not path.startswith("/api/admin/") and not self.invited():
            return self.send_error(404)

        if path == "/api/message":
            body = (data.get("body") or "").strip()
            if not body:
                return self.send_json({"ok": False, "error": "nothing to send"}, 400)
            now = datetime.now(timezone.utc)
            with _lock, db() as conn:
                recent = conn.execute(
                    "SELECT COUNT(*) c FROM messages WHERE who = 'her' AND at > ?",
                    ((now - timedelta(minutes=5)).isoformat(timespec="seconds"),),
                ).fetchone()["c"]
                if recent >= 20:
                    return self.send_json({"ok": False, "error": "slow down a moment"}, 429)
                conn.execute(
                    "INSERT INTO messages (who, body, at) VALUES ('her', ?, ?)",
                    (body[:4000], now.isoformat(timespec="seconds")),
                )
            touch_seen("her")
            push(body[:400], tags="love_letter", title=CFG["her_name"])
            return self.send_json({"ok": True, "messages": thread(), "seen": seen_map()})

        if path == "/api/heart":
            with _lock, db() as conn:
                recent = conn.execute(
                    "SELECT COUNT(*) c FROM hearts WHERE sent_at > ?",
                    ((datetime.now() - timedelta(minutes=2)).isoformat(),),
                ).fetchone()["c"]
                if recent >= 3:
                    return self.send_json({"ok": True, "throttled": True})
                conn.execute(
                    "INSERT INTO hearts (sent_at) VALUES (?)",
                    (datetime.now().isoformat(timespec="seconds"),),
                )
            return self.send_json({"ok": send_heart()})

        if path == "/api/admin/note":
            if not check_password(data.get("password")):
                time.sleep(0.5)
                return self.send_json({"ok": False, "error": "wrong password"}, 403)
            body = (data.get("body") or "").strip()
            day = (data.get("day") or her_today().isoformat()).strip()
            try:
                date.fromisoformat(day)
            except ValueError:
                return self.send_json({"ok": False, "error": "bad date"}, 400)
            with _lock, db() as conn:
                if body:
                    conn.execute(
                        "INSERT OR REPLACE INTO notes VALUES (?, ?, ?)",
                        (day, body[:4000], datetime.now().isoformat(timespec="seconds")),
                    )
                else:
                    conn.execute("DELETE FROM notes WHERE day = ?", (day,))
            return self.send_json({"ok": True})

        if path == "/api/admin/reply":
            if not check_password(data.get("password")):
                time.sleep(0.5)
                return self.send_json({"ok": False, "error": "wrong password"}, 403)
            body = (data.get("body") or "").strip()
            if not body:
                return self.send_json({"ok": False, "error": "nothing to send"}, 400)
            now = datetime.now(timezone.utc)
            with _lock, db() as conn:
                conn.execute(
                    "INSERT INTO messages (who, body, at) VALUES ('him', ?, ?)",
                    (body[:4000], now.isoformat(timespec="seconds")),
                )
                conn.execute(
                    "UPDATE messages SET read_at = ? WHERE who = 'her' AND read_at IS NULL",
                    (now.isoformat(timespec="seconds"),),
                )
            touch_seen("him")
            return self.send_json({"ok": True, "messages": thread()})

        if path == "/api/admin/read":
            if not check_password(data.get("password")):
                time.sleep(0.5)
                return self.send_json({"ok": False, "error": "wrong password"}, 403)
            with _lock, db() as conn:
                conn.execute(
                    "UPDATE messages SET read_at = ? WHERE who = 'her' AND read_at IS NULL",
                    (datetime.now(timezone.utc).isoformat(timespec="seconds"),),
                )
            return self.send_json({"ok": True})

        if path == "/api/admin/state":
            if not check_password(data.get("password")):
                time.sleep(0.5)
                return self.send_json({"ok": False, "error": "wrong password"}, 403)
            with db() as conn:
                notes = [
                    dict(r)
                    for r in conn.execute(
                        "SELECT day, body FROM notes ORDER BY day DESC LIMIT 30"
                    )
                ]
                hearts = conn.execute(
                    "SELECT sent_at FROM hearts ORDER BY id DESC LIMIT 8"
                ).fetchall()
                last_visit = conn.execute(
                    "SELECT day, seen_at FROM visits ORDER BY day DESC LIMIT 1"
                ).fetchone()
            touch_seen("him")
            return self.send_json(
                {
                    "ok": True,
                    "messages": thread(),
                    "seen": seen_map(),
                    "today": her_today().isoformat(),
                    "notes": notes,
                    "hearts": [r["sent_at"] for r in hearts],
                    "last_visit": dict(last_visit) if last_visit else None,
                    "verse": verse_state(),
                }
            )

        return self.send_error(404)

    def payload_today(self):
        today = her_today()
        note = note_for(today)
        birthday = CFG.get("birthday", "")
        is_birthday = bool(birthday) and today.strftime("%m-%d") == birthday[-5:]
        open_days = int(CFG.get("game_open_days", 30))
        window = False
        if birthday:
            month, day = [int(x) for x in birthday[-5:].split("-")]
            for year in (today.year, today.year - 1):
                try:
                    since = (today - date(year, month, day)).days
                except ValueError:
                    continue
                window = window or 0 <= since <= open_days
        return {
            "her_name": CFG["her_name"],
            "my_name": CFG["my_name"],
            "her_timezone": CFG["her_timezone"],
            "my_timezone": CFG["my_timezone"],
            "date": today.isoformat(),
            "verse": verse_state(),
            "note": {"body": note or fallback_note(), "is_fallback": note is None},
            "record": record_of_day(),
            "poem": poem_of_day(),
            "moon": moon_for(today),
            "day_ruler": DAY_RULER[today.weekday()],
            "day_glyph": PLANET_GLYPH[DAY_RULER[today.weekday()]],
            "birthday": is_birthday,
            "game_unlocked": bool(CFG.get("game_enabled", True))
            and (window or bool(CFG.get("game_always_open"))),
            "search_url": CFG.get("search_url", "https://duckduckgo.com/?q=%s"),
            "links": load_json("links.json", []),
            "my_place": CFG.get("my_weather_place", ""),
            "weather_unit": "f" if str(CFG.get("weather_unit", "c")).lower().startswith("f") else "c",
        }

    def payload_archive(self):
        today = her_today()
        with db() as conn:
            notes = [
                dict(r)
                for r in conn.execute(
                    "SELECT day, body FROM notes WHERE day < ? ORDER BY day DESC LIMIT 400",
                    (today.isoformat(),),
                )
            ]
        return {"notes": notes, "verse": verse_state()}


def main():
    init_db()
    port = int(os.environ.get("PORT", CFG.get("port", 8080)))
    host = os.environ.get("HOST", CFG.get("host", "127.0.0.1"))
    if CFG["admin_password"] == "change-me":
        sys.stderr.write("!! admin_password is still the default, change it in config.json\n")
    try:
        server = ThreadingHTTPServer((host, port), Handler)
    except OSError as err:
        if err.errno != errno.EADDRINUSE:
            raise
        sys.stderr.write(
            f"port {port} is taken.\n"
            f"  see what has it:  ss -lptn 'sport = :{port}'\n"
            f"  or use another:   env PORT={port + 1} python3 app.py\n"
        )
        raise SystemExit(1)

    sys.stderr.write(f"listening on http://{host}:{port}  admin at /{CFG['admin_path']}\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        sys.stderr.write("\nstopped\n")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
