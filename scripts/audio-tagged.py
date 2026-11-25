"""Exit 0 when every file given is audio with artist and album tags, 1 otherwise.

slsk-import (home/soulseek.nix) asks this before filing a download by its own
tags: beets files an untagged one as "_/[id]/00.flac". A file mutagen can't
read (not audio, damaged) counts as untagged, so the folder is kept.

With --one-album, exit 0 when every file carries the same album instead (album
artist and title when all files have an album artist, the title alone if not):
slsk-import then imports the folder whole, since beets' -g would split a
compilation into one album per track artist.
"""

import sys

import mutagen

# Formats without an "easy" tag interface (WAV, AIFF, DSF/DFF and raw AAC carry
# ID3 frames; WMA its own keys) come back with their native tag names.
ALBUM = ("album", "TALB", "WM/AlbumTitle", "\xa9alb")
ARTIST = ("artist", "albumartist", "TPE1", "TPE2", "Author", "WM/AlbumArtist", "\xa9ART", "aART")


def values(tags, key):
    try:
        v = tags[key]
    except (KeyError, ValueError, TypeError):
        return []
    text = getattr(v, "text", v)  # ID3 frames keep their values in .text
    return text if isinstance(text, list) else [text]


def first(tags, keys):
    for k in keys:
        for v in values(tags, k):
            if str(v).strip():
                return str(v).strip()
    return ""


def read(path):
    try:
        f = mutagen.File(path, easy=True)
    except Exception:  # unreadable or damaged: not safe to file as-is
        return None
    return f.tags if f is not None and f.tags else None


def tagged(path):
    tags = read(path)
    return tags is not None and bool(first(tags, ALBUM)) and bool(first(tags, ARTIST))


ALBUMARTIST = ("albumartist", "TPE2", "WM/AlbumArtist", "aART")


def album(path):
    """(album artist, album), case-folded; the artist is "" when untagged."""
    tags = read(path)
    if tags is None:
        return ("", "")
    return (first(tags, ALBUMARTIST).casefold(), first(tags, ALBUM).casefold())


args = sys.argv[1:]
if args[:1] == ["--one-album"]:
    keys = {album(p) for p in args[1:]}
    if any(not name for _, name in keys):
        sys.exit(1)
    # with album artists on every file, two "Greatest Hits" by different
    # artists are two albums; a compilation without them goes by title alone
    if all(artist for artist, _ in keys):
        sys.exit(0 if len(keys) == 1 else 1)
    sys.exit(0 if len({name for _, name in keys}) == 1 else 1)

bad = [p for p in args if not tagged(p)]
for p in bad:
    print(f"no artist/album tags: {p}", file=sys.stderr)
sys.exit(1 if bad else 0)
