#!/usr/bin/env python3
"""Write each song's timed lyrics from the beets library next to it as .lrc.

beets keeps lyrics in its library and the files' tags, which Tauon and
Jellyfin read; rmpc reads .lrc files beside the songs instead. Plain
(untimed) lyrics stay in the tags only. Usage: music-lyrics.py LIBRARY.DB
"""

import os
import re
import sqlite3
import sys

TIMED = re.compile(r"^\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]", re.M)


def main(db: str) -> int:
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    written = kept = 0
    for path, lyrics in con.execute("SELECT path, lyrics FROM items WHERE lyrics != ''"):
        if not lyrics or not TIMED.search(lyrics):
            continue
        song = os.fsdecode(path)
        if not os.path.exists(song):
            continue
        lrc = os.path.splitext(song)[0] + ".lrc"
        if os.path.exists(lrc):
            with open(lrc, encoding="utf-8", errors="replace") as f:
                if f.read() == lyrics:
                    kept += 1
                    continue
        with open(lrc, "w", encoding="utf-8") as f:
            f.write(lyrics)
        written += 1
    print(f"music-lyrics: wrote {written} .lrc file(s), {kept} already current")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
