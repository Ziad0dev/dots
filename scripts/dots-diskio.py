import os
import shutil
import sys
import time

SECTOR = 512
INTERVAL = float(os.environ.get("DOTS_DISKIO_INTERVAL", "1"))


def disks():
    out = {}
    with open("/proc/diskstats") as f:
        for line in f:
            p = line.split()
            name = p[2]
            if name.startswith(("loop", "ram", "zram", "fd", "dm-", "sr")):
                continue
            if not os.path.exists(f"/sys/block/{name}"):
                continue
            out[name] = (int(p[5]) * SECTOR, int(p[9]) * SECTOR, int(p[12]))
    return out


def mounts():
    holders = {}
    with open("/proc/mounts") as f:
        for line in f:
            dev, mnt = line.split()[:2]
            if not dev.startswith("/dev/"):
                continue
            real = os.path.realpath(dev)
            base = os.path.basename(real)
            parent = parent_disk(base)
            holders.setdefault(parent, []).append(mnt.replace("\\040", " "))
    return holders


def parent_disk(name):
    link = f"/sys/class/block/{name}"
    if os.path.exists(f"{link}/partition"):
        return os.path.basename(os.path.dirname(os.path.realpath(link)))
    slaves = f"/sys/class/block/{name}/slaves"
    if os.path.isdir(slaves):
        s = os.listdir(slaves)
        if s:
            return parent_disk(s[0])
    return name


def model(name):
    for f in (f"/sys/block/{name}/device/model", f"/sys/block/{name}/device/name"):
        try:
            with open(f) as h:
                return h.read().strip()
        except OSError:
            pass
    return ""


def meminfo():
    vals = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, v = line.split(":", 1)
            if k in ("Dirty", "Writeback"):
                vals[k] = int(v.split()[0]) * 1024
    return vals


def human(n):
    for unit in ("B", "K", "M", "G", "T"):
        if abs(n) < 1024 or unit == "T":
            return f"{n:6.1f}{unit}" if unit != "B" else f"{n:6.0f}B"
        n /= 1024
    return str(n)


def bar(rate, peak, width):
    if peak <= 0 or width <= 0:
        return ""
    n = int(round(width * min(rate / peak, 1.0)))
    return "█" * n + "·" * (width - n)


def main():
    prev = disks()
    peak = {}
    sys.stdout.write("\033[?25l\033[?1049h")
    try:
        while True:
            time.sleep(INTERVAL)
            cur = disks()
            held = mounts()
            mem = meminfo()
            cols = shutil.get_terminal_size((100, 30)).columns
            width = max(cols - 62, 8)
            lines = [f"\033[1m{'device':<10}{'read/s':>9}{'write/s':>9}  {'busy':>5}  activity\033[0m"]
            for name in sorted(cur):
                if name not in prev:
                    continue
                r = (cur[name][0] - prev[name][0]) / INTERVAL
                w = (cur[name][1] - prev[name][1]) / INTERVAL
                busy = min((cur[name][2] - prev[name][2]) / (INTERVAL * 10), 100.0)
                peak[name] = max(peak.get(name, 0) * 0.98, r + w, 1)
                label = ", ".join(held.get(name, [])) or model(name)
                lines.append(
                    f"{name:<10}{human(r):>9}{human(w):>9}  {busy:4.0f}%  {bar(r + w, peak[name], width)}"
                )
                if label:
                    lines.append(f"\033[2m{'':<10}{label[: cols - 12]}\033[0m")
            dirty = mem.get("Dirty", 0)
            wb = mem.get("Writeback", 0)
            pending = dirty + wb
            state = "\033[32mall writes flushed\033[0m" if pending < 1024 * 1024 else "\033[33mwrites still pending\033[0m"
            lines.append("")
            lines.append(f"page cache: dirty {human(dirty).strip()}  writeback {human(wb).strip()}  — {state}")
            lines.append("\033[2mctrl-c to quit\033[0m")
            sys.stdout.write("\033[H\033[2J" + "\n".join(lines) + "\n")
            sys.stdout.flush()
            prev = cur
    except KeyboardInterrupt:
        pass
    finally:
        sys.stdout.write("\033[?1049l\033[?25h")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
