import datetime as dt
import glob
import os
import socket
import sqlite3
import sys
import time

STATE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "dots")
DB = os.path.join(STATE, "screentime.db")
FLUSH = 30


def db():
    os.makedirs(STATE, exist_ok=True)
    con = sqlite3.connect(DB)
    con.execute(
        "CREATE TABLE IF NOT EXISTS usage (day TEXT NOT NULL, app TEXT NOT NULL,"
        " seconds REAL NOT NULL, PRIMARY KEY (day, app))"
    )
    return con


def socket_path():
    run = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig:
        p = os.path.join(run, "hypr", sig, ".socket2.sock")
        if os.path.exists(p):
            return p
    found = sorted(glob.glob(os.path.join(run, "hypr", "*", ".socket2.sock")), key=os.path.getmtime)
    return found[-1] if found else None


def locked():
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = f.read().split(b"\0")
        except OSError:
            continue
        if args and args[0].endswith(b"quickshell"):
            for a, b in zip(args, args[1:]):
                if a == b"-c" and b == b"lock":
                    return True
    return False


class Tracker:
    def __init__(self, con):
        self.con = con
        self.app = None
        self.since = time.monotonic()

    def flush(self):
        now = time.monotonic()
        spent = now - self.since
        self.since = now
        if not self.app or spent <= 0 or locked():
            return
        day = dt.date.today().isoformat()
        self.con.execute(
            "INSERT INTO usage (day, app, seconds) VALUES (?, ?, ?)"
            " ON CONFLICT(day, app) DO UPDATE SET seconds = seconds + excluded.seconds",
            (day, self.app, spent),
        )
        self.con.commit()

    def focus(self, app):
        self.flush()
        self.app = app or None


def daemon():
    tracker = Tracker(db())
    while True:
        path = socket_path()
        if not path:
            time.sleep(5)
            continue
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.connect(path)
            s.settimeout(FLUSH)
            buf = b""
            tracker.since = time.monotonic()
            while True:
                try:
                    chunk = s.recv(4096)
                except socket.timeout:
                    tracker.flush()
                    continue
                if not chunk:
                    break
                if time.monotonic() - tracker.since >= FLUSH:
                    tracker.flush()
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    event, _, data = line.decode(errors="replace").partition(">>")
                    if event == "activewindow":
                        tracker.focus(data.split(",", 1)[0])
        except OSError:
            pass
        finally:
            tracker.focus(None)
            s.close()
        time.sleep(2)


def fmt(sec):
    sec = int(sec)
    h, m = divmod(sec // 60, 60)
    return f"{h}h{m:02d}m" if h else f"{m}m"


def report(arg):
    today = dt.date.today()
    if arg in ("", "today"):
        start = end = today
    elif arg == "yesterday":
        start = end = today - dt.timedelta(days=1)
    elif arg == "week":
        start, end = today - dt.timedelta(days=6), today
    elif arg == "month":
        start, end = today - dt.timedelta(days=29), today
    else:
        try:
            start = end = dt.date.fromisoformat(arg)
        except ValueError:
            sys.exit("usage: dots-screentime [today|yesterday|week|month|YYYY-MM-DD|daemon]")
    rows = db().execute(
        "SELECT app, SUM(seconds) FROM usage WHERE day BETWEEN ? AND ? GROUP BY app ORDER BY 2 DESC",
        (start.isoformat(), end.isoformat()),
    ).fetchall()
    total = sum(r[1] for r in rows)
    span = start.isoformat() if start == end else f"{start.isoformat()} → {end.isoformat()}"
    print(f"\033[1m{span}  total {fmt(total)}\033[0m")
    if not rows:
        return
    top = rows[0][1]
    for app, sec in rows[:20]:
        n = int(30 * sec / top) if top else 0
        print(f"{app[:28]:<28} {fmt(sec):>7}  {'█' * n}")


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    if arg == "daemon":
        daemon()
    else:
        report(arg)
