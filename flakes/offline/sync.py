"""offline-sync: keep the offline library, the planet map and the archive current.

    offline-sync library   newest release of every configured Kiwix book
    offline-sync maps      the Protomaps planet basemap
    offline-sync docs      the documents (brochures, books as PDFs)
    offline-sync apps      Android apps for phones (F-Droid and direct APKs)
    offline-sync navigation  OpenStreetMap extracts, then the routing tiles
                           and the place index built from them
    offline-sync all       docs, apps, navigation, library, then maps
    offline-sync archive   this system and its flake inputs into the offline
                           Nix cache, and a git bundle of the flake
    offline-sync status    what is on disk
    offline-sync prepare   an empty library.xml, if there is none yet

Configuration comes from the JSON file in $OFFLINE_CONFIG (written by the
NixOS module). Every download resumes where it stopped and is verified
(SHA-256 from Kiwix's metalinks, BLAKE3 for the map), so a run can be
interrupted at any point and simply started again.
"""

from __future__ import annotations

import email.utils
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

CATALOG = os.environ.get("OFFLINE_KIWIX_CATALOG", "https://opds.library.kiwix.org/catalog/v2/entries")
BUILDS = os.environ.get("OFFLINE_PROTOMAPS_BUILDS", "https://build-metadata.protomaps.dev/builds.json")
PLANET = os.environ.get("OFFLINE_PROTOMAPS_PLANET", "https://build.protomaps.com/{key}")
FDROID = os.environ.get("OFFLINE_FDROID_REPO", "https://f-droid.org/repo")
GEOFABRIK = os.environ.get("OFFLINE_GEOFABRIK", "https://download.geofabrik.de")
PHOTON_DUMPS = os.environ.get("OFFLINE_PHOTON_DUMPS", "https://download1.graphhopper.com/public")
PHOTON_DUMP_VERSION = "1.0"  # the dump format photon 1.x imports
ATOM = {"a": "http://www.w3.org/2005/Atom"}
FLAVOURS = ("maxi", "nopic", "mini")
USER_AGENT = "offline-sync (NixOS)"
GIB = 1 << 30
# releases are dated YYYY-MM, with a letter for a re-release (2026-11a)
DATED = re.compile(r"^(?P<book>.+)_(?P<date>\d{4}-\d{2}[a-z]?)\.zim$")


def log(message: str) -> None:
    print(message, flush=True)


def fetch(url: str, attempts: int = 4) -> bytes:
    for attempt in range(attempts):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read()
        except Exception as error:  # network trouble: retry with backoff
            if attempt == attempts - 1:
                raise
            log(f"  retrying {url} ({error})")
            time.sleep(5 * 2**attempt)
    raise AssertionError("unreachable")


def aria2(url: str, directory: Path, limit: str, *extra: str, resume: bool = True) -> bool:
    command = [
        "aria2c",
        f"--dir={directory}",
        f"--continue={'true' if resume else 'false'}",
        "--file-allocation=none",
        "--auto-file-renaming=false",
        "--max-connection-per-server=4",
        "--split=4",
        "--min-split-size=64M",
        "--console-log-level=error",
        "--show-console-readout=false",
        "--summary-interval=900",
        "--download-result=hide",
        f"--max-overall-download-limit={limit}",
        f"--user-agent={USER_AGENT}",
        *extra,
        url,
    ]
    return subprocess.run(command, check=False).returncode == 0


def free_space(directory: Path) -> int:
    return shutil.disk_usage(directory).free


def write_atomic(path: Path, text: str) -> None:
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


# --- library ---------------------------------------------------------------


def split_book(book: str) -> tuple[str, str]:
    for flavour in FLAVOURS:
        if book.endswith("_" + flavour):
            return book[: -len(flavour) - 1], flavour
    return book, ""


def resolve(book: str) -> tuple[str, str, int] | None:
    """Newest release of a book: (updated, metalink URL, size in bytes)."""
    name, flavour = split_book(book)
    query = urllib.parse.urlencode({"name": name, "count": 100})
    root = ET.fromstring(fetch(f"{CATALOG}?{query}"))
    best = None
    for entry in root.findall("a:entry", ATOM):
        if (entry.findtext("a:flavour", "", ATOM) or "").strip() != flavour:
            continue
        for link in entry.findall("a:link", ATOM):
            if link.get("type") == "application/x-zim" and link.get("href"):
                candidate = (
                    entry.findtext("a:updated", "", ATOM) or "",
                    link.get("href", ""),
                    int(link.get("length") or 0),
                )
                if best is None or candidate[0] > best[0]:
                    best = candidate
    return best


def complete_zims(directory: Path) -> list[Path]:
    if not directory.is_dir():
        return []
    return [
        zim
        for zim in sorted(directory.glob("*.zim"))
        if not (directory / (zim.name + ".aria2")).exists()
    ]


def finished_zims(config: dict) -> list[Path]:
    library = Path(config["kiwix"]["library"])
    directories = {library.parent} | {Path(b["dir"]) for b in config["kiwix"]["books"]}
    return [z for d in sorted(directories) for z in complete_zims(d)]


def write_shelf(config: dict) -> None:
    """Links to every finished book, whichever drive it is on, in one
    directory: the Kiwix desktop app watches a single one."""
    shelf = Path(config["kiwix"]["shelf"])
    shelf.mkdir(parents=True, exist_ok=True)
    wanted = {z.name: z for z in finished_zims(config)}
    for link in shelf.iterdir():
        if link.is_symlink() and (link.name not in wanted or Path(os.readlink(link)) != wanted[link.name]):
            link.unlink()
    for name, target in wanted.items():
        if not (shelf / name).is_symlink():
            (shelf / name).symlink_to(target)


def write_library(config: dict) -> None:
    """library.xml lists every finished ZIM; kiwix-serve reloads it on change."""
    library = Path(config["kiwix"]["library"])
    zims = [str(z) for z in finished_zims(config)]
    write_shelf(config)
    tmp = library.with_name(library.name + ".tmp")
    tmp.unlink(missing_ok=True)
    if zims:
        result = subprocess.run(
            ["kiwix-manage", str(tmp), "add", *zims],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            log(f"! kiwix-manage: {result.stderr.strip()[:500]}")
    if not tmp.exists():
        tmp.write_text('<library version="20110515"></library>\n')
    os.replace(tmp, library)


def ensure_library(config: dict) -> None:
    """An empty library.xml, so kiwix-serve can start before the first book."""
    library = Path(config["kiwix"]["library"])
    library.parent.mkdir(parents=True, exist_ok=True)
    if not library.exists():
        write_library(config)


def sync_library(config: dict) -> None:
    kiwix = config["kiwix"]
    limit = config["downloadLimit"]
    manifest_path = Path(config["stateDir"]) / "kiwix-manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}

    ensure_library(config)
    plan = []
    for item in kiwix["books"]:
        book = item["book"]
        try:
            hit = resolve(book)
        except Exception as error:
            log(f"! {book}: catalog lookup failed ({error}); keeping what is on disk")
            continue
        if hit is None:
            log(f"! {book}: not in the Kiwix catalog (renamed or withdrawn?)")
            continue
        _, metalink, size = hit
        filename = Path(urllib.parse.urlparse(metalink).path).name.removesuffix(".meta4")
        plan.append((size, book, Path(item["dir"]), filename, metalink))

    # smallest first: the survival and medical titles land long before the
    # encyclopedias, and the library is usable from the first finished book
    for size, book, directory, filename, metalink in sorted(plan):
        directory.mkdir(parents=True, exist_ok=True)
        target = directory / filename
        partial = directory / (filename + ".aria2")
        if not target.exists() or partial.exists():
            have = target.stat().st_size if target.exists() else 0
            if free_space(directory) < size - have + 2 * GIB:
                log(f"! {book}: needs {size / GIB:.1f} GiB, {directory} is too full; skipped")
                continue
            log(f"↓ {book} ({size / GIB:.1f} GiB) → {directory}")
            # aria2 checks the metalink's SHA-256 when a download completes;
            # --check-integrity re-checks what an interrupted run left behind
            resume = ("--check-integrity=true",) if partial.exists() else ()
            if not aria2(metalink, directory, limit, "--follow-metalink=mem", *resume):
                log(f"! {book}: download failed; it resumes on the next run")
                continue
            log(f"✓ {filename}")
        manifest[book] = str(target)
        manifest_path.write_text(json.dumps(manifest, indent=1, sort_keys=True))
        for old in directory.glob(f"{book}_*.zim"):
            match = DATED.match(old.name)
            if match and match["book"] == book and old.name != filename:
                if not (directory / (old.name + ".aria2")).exists():
                    log(f"  removing the older {old.name}")
                    old.unlink()
        write_library(config)
        # the hub's status page follows a long first run book by book
        write_status(config)

    # books this tool downloaded earlier that are no longer configured
    wanted = {item["book"] for item in kiwix["books"]}
    for book in sorted(set(manifest) - wanted):
        path = Path(manifest.pop(book))
        if path.exists():
            log(f"  removing {path.name} (no longer configured)")
            path.unlink()
    manifest_path.write_text(json.dumps(manifest, indent=1, sort_keys=True))
    write_library(config)


# --- maps ------------------------------------------------------------------


def build_date(key: str) -> datetime:
    return datetime.strptime(key[:8], "%Y%m%d").replace(tzinfo=timezone.utc)


def sync_maps(config: dict) -> None:
    maps = config["maps"]
    directory = Path(maps["dir"])
    directory.mkdir(parents=True, exist_ok=True)
    current = directory / "planet.pmtiles"
    meta_path = directory / "planet.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}

    builds = json.loads(fetch(BUILDS))
    latest = max(builds, key=lambda build: build["key"])
    if current.exists() and meta.get("key"):
        behind = (build_date(latest["key"]) - build_date(meta["key"])).days
        if behind < maps["refreshDays"]:
            log(f"= planet map {meta['key']} ({behind} days behind the newest build)")
            return

    # builds are kept for a week upstream: drop partials of builds that went away
    for stale in directory.glob("*.pmtiles"):
        if stale.name not in ("planet.pmtiles", latest["key"]):
            stale.unlink()
            (directory / (stale.name + ".aria2")).unlink(missing_ok=True)

    size = int(latest["size"])
    partial = directory / latest["key"]
    have = partial.stat().st_size if partial.exists() else 0
    if free_space(directory) < size - have + 2 * GIB:
        log(f"! planet map: needs {size / GIB:.0f} GiB, {directory} is too full; skipped")
        return
    log(f"↓ planet map {latest['key']} ({size / GIB:.0f} GiB) → {directory}")
    if not aria2(PLANET.format(key=latest["key"]), directory, config["downloadLimit"]):
        log("! planet map: download failed; it resumes on the next run")
        return
    log("  verifying (BLAKE3)")
    digest = subprocess.run(
        ["b3sum", "--no-names", str(partial)], capture_output=True, text=True, check=True
    ).stdout.strip()
    if digest != latest["b3sum"]:
        log("! planet map: checksum mismatch, deleted; the next run downloads it again")
        partial.unlink()
        return
    os.replace(partial, current)
    write_atomic(
        meta_path,
        json.dumps({k: latest.get(k) for k in ("key", "version", "size", "b3sum")}),
    )
    log(f"✓ planet map {latest['key']}")


# --- documents and phone apps ----------------------------------------------


def download(url: str, target: Path, limit: str, sha256: str | None = None, newer: bool = False) -> bool:
    """One file to `target`, checked against `sha256` when given. With
    `newer`, a file already on disk is fetched again only when the server's
    copy is newer (and then whole: a changed file can't be resumed)."""
    target.parent.mkdir(parents=True, exist_ok=True)
    extra = [f"--out={target.name}"]
    if sha256:
        extra.append(f"--checksum=sha-256={sha256}")
    if newer:
        extra += ["--conditional-get=true", "--allow-overwrite=true", "--remote-time=true"]
    return aria2(url, target.parent, limit, *extra, resume=not newer)


def forget(manifest: dict, keep: dict, root: Path) -> None:
    """Delete the files a manifest lists that `keep` no longer does: only
    files this tool downloaded, never anything else in the directory."""
    for key, path in sorted(manifest.items()):
        if keep.get(key) != path and (root / path).exists():
            log(f"  removing {path} (no longer configured)")
            (root / path).unlink()


def sync_docs(config: dict) -> None:
    docs = config["docs"]
    root = Path(docs["dir"])
    manifest_path = Path(config["stateDir"]) / "docs-manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    keep = {}
    for path, url in sorted(docs["files"].items()):
        target = root / path
        new = not target.exists()
        if new:
            log(f"↓ {path}")
        if not download(url, target, config["downloadLimit"], newer=True):
            log(f"! {path}: download failed; it is tried again on the next run")
        elif new:
            log(f"✓ {path}")
        keep[path] = path
    forget(manifest, keep, root)
    write_atomic(manifest_path, json.dumps(keep, indent=1, sort_keys=True))


def app_name(package: dict, fallback: str) -> str:
    name = (package["metadata"].get("name") or {}).get("en-US") or fallback
    # "CoMaps - Hike, Bike, Drive Offline" -> "CoMaps"
    return re.split(r" - |・|: | \| ", name)[0].strip().replace("/", "-")


def sync_apps(config: dict) -> None:
    apps = config["apps"]
    root = Path(apps["dir"])
    limit = config["downloadLimit"]
    manifest_path = Path(config["stateDir"]) / "apps-manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    keep = {}
    index: dict | None = None
    if apps["fdroid"]:
        try:
            index = json.loads(fetch(f"{FDROID}/index-v2.json"))["packages"]
        except Exception as error:
            log(f"! F-Droid index: {error}; keeping the apps already on disk")
    for package in apps["fdroid"]:
        if index is None or package not in index:
            if index is not None:
                log(f"! {package}: not in F-Droid (renamed or removed?)")
            if package in manifest:
                keep[package] = manifest[package]
            continue
        # F-Droid builds some apps once per CPU: the newest build that runs on the phones
        builds: list[dict] = [
            v
            for v in index[package]["versions"].values()
            if not v["manifest"].get("nativecode") or apps["abi"] in v["manifest"]["nativecode"]
        ]
        if not builds:
            log(f"! {package}: no build for {apps['abi']}")
            continue
        best = max(builds, key=lambda v: v["manifest"]["versionCode"])
        filename = f"{app_name(index[package], package)} {best['manifest']['versionName']}.apk".replace("/", "-")
        if manifest.get(package) == filename and (root / filename).exists():
            keep[package] = filename
            continue
        log(f"↓ {filename} ({best['file']['size'] / 2**20:.0f} MiB)")
        partial = root / (filename + ".part")
        if not download(FDROID + best["file"]["name"], partial, limit, sha256=best["file"]["sha256"]):
            log(f"! {package}: download failed; it resumes on the next run")
            if package in manifest:
                keep[package] = manifest[package]
            continue
        os.replace(partial, root / filename)
        keep[package] = filename
        log(f"✓ {filename}")
    for filename, url in sorted(apps["direct"].items()):
        key = "direct:" + filename
        if not download(url, root / filename, limit, newer=True):
            log(f"! {filename}: download failed; it is tried again on the next run")
        keep[key] = filename
    forget(manifest, keep, root)
    write_atomic(manifest_path, json.dumps(keep, indent=1, sort_keys=True))


# --- navigation: directions and place search -------------------------------


def md5sum(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch_checked(url: str, target: Path, limit: str) -> bool:
    """`url` to `target` when the server's copy differs from the one on disk,
    checked against the .md5 published next to it. A new copy goes in only
    once complete and verified, so the old one stays usable meanwhile.
    False if it couldn't be fetched."""
    try:
        request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=60) as response:
            size = int(response.headers.get("Content-Length") or 0)
            stamp = response.headers.get("Last-Modified")
        modified = email.utils.parsedate_to_datetime(stamp).timestamp() if stamp else time.time()
        if target.exists() and target.stat().st_size == size and abs(target.stat().st_mtime - modified) < 2:
            return True
        md5 = fetch(url + ".md5").decode().split()[0]
    except Exception as error:
        log(f"! {target.name}: {error}; keeping what is on disk")
        return False
    part = target.with_name(target.name + ".part")
    log(f"↓ {target.name} ({size / 2**20:.0f} MiB)")
    if not aria2(url, target.parent, limit, f"--out={part.name}"):
        log(f"! {target.name}: download failed; it resumes on the next run")
        return False
    if md5sum(part) != md5:
        # most likely a new release replaced the file mid-download
        log(f"! {target.name}: checksum mismatch; fetched again on the next run")
        part.unlink()
        return False
    os.utime(part, (modified, modified))
    os.replace(part, target)
    log(f"✓ {target.name}")
    return True


def inputs_stamp(paths: list[Path]) -> str:
    return json.dumps([[p.name, p.stat().st_size, int(p.stat().st_mtime)] for p in paths])


def swap(new: Path, live: Path) -> None:
    """Put a finished build in place of the old one."""
    old = live.with_name(live.name + ".old")
    shutil.rmtree(old, ignore_errors=True)
    if live.exists():
        live.rename(old)
    new.rename(live)
    shutil.rmtree(old, ignore_errors=True)


def restart(unit: str) -> None:
    # allowed for this user by the module's polkit rule
    subprocess.run(["systemctl", "restart", "--no-block", unit], check=False)


def build_routing(nav: dict, pbfs: list[Path]) -> bool:
    root = Path(nav["dir"])
    live, new = root / "valhalla", root / "valhalla.new"

    def config(at: Path) -> str:
        return subprocess.run(
            [
                "valhalla_build_config",
                "--mjolnir-tile-dir", str(at / "tiles"),
                "--mjolnir-tile-extract", str(at / "tiles.tar"),
                "--mjolnir-admin", str(at / "admins.sqlite"),
                # no time zones or traffic: both would need more downloads
                "--mjolnir-timezone", str(at / "timezones.sqlite"),
                "--mjolnir-traffic-extract", str(at / "traffic.tar"),
                "--httpd-service-listen", nav["listen"],
            ],
            capture_output=True, text=True, check=True,
        ).stdout

    shutil.rmtree(new, ignore_errors=True)
    new.mkdir(parents=True)
    build = new / "build.json"
    build.write_text(config(new))
    # Valhalla only says "std::exception" when it fails; its log says why
    build_log = root / "valhalla-build.log"
    log(f"  building routing tiles for {', '.join(nav['regions'])} (log: {build_log})")
    try:
        with build_log.open("w") as out:
            sources = [str(p) for p in pbfs]
            if len(sources) > 1:
                # neighbouring extracts share the roads that cross their
                # borders, and Valhalla fails on the duplicates: one merged file
                merged = new / "merged.osm.pbf"
                subprocess.run(["osmium", "merge", "--overwrite", "-o", str(merged), *sources], check=True, stdout=out, stderr=subprocess.STDOUT)
                sources = [str(merged)]
            for tool in ("valhalla_build_admins", "valhalla_build_tiles"):
                subprocess.run([tool, "-c", str(build), *sources], check=True, stdout=out, stderr=subprocess.STDOUT)
            subprocess.run(["valhalla_build_extract", "-c", str(build), "-v"], check=True, stdout=out, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as error:
        log(f"! routing tiles: {Path(error.cmd[0]).name} failed (exit {error.returncode}); keeping the previous ones")
        shutil.rmtree(new, ignore_errors=True)
        return False
    # the service reads the single tiles.tar
    (new / "merged.osm.pbf").unlink(missing_ok=True)
    shutil.rmtree(new / "tiles", ignore_errors=True)
    build.unlink()
    (new / "valhalla.json").write_text(config(live))
    (new / "inputs.json").write_text(inputs_stamp(pbfs))
    swap(new, live)
    log("✓ routing tiles")
    return True


def build_search(nav: dict, dumps: list[Path]) -> bool:
    root = Path(nav["dir"])
    live, new = root / "photon", root / "photon.new"
    shutil.rmtree(new, ignore_errors=True)
    new.mkdir(parents=True)
    log(f"  building the place index for {', '.join(nav['regions'])}")
    importer = subprocess.Popen(
        ["offline-photon", "import", "-import-file", "-", "-data-dir", str(new), "-languages", ",".join(nav["languages"])],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        env=dict(os.environ, JAVA_OPTS="-Xmx4g"),
    )
    assert importer.stdin is not None
    try:
        for n, dump in enumerate(dumps):
            unpack = subprocess.Popen(["zstd", "-dc", str(dump)], stdout=subprocess.PIPE)
            assert unpack.stdout is not None
            for i, line in enumerate(unpack.stdout):
                # one file, one header: the dumps after the first lose theirs
                if i == 0 and n > 0 and b'"NominatimDumpFile"' in line:
                    continue
                importer.stdin.write(line)
            if unpack.wait() != 0:
                raise RuntimeError(f"can't unpack {dump.name}")
        importer.stdin.close()
        if importer.wait() != 0:
            raise RuntimeError("photon import failed")
    except (OSError, RuntimeError) as error:
        importer.kill()
        log(f"! place index: {error}; keeping the previous one")
        shutil.rmtree(new, ignore_errors=True)
        return False
    (new / "inputs.json").write_text(inputs_stamp(dumps))
    swap(new, live)
    log("✓ place index")
    return True


def sync_navigation(config: dict) -> None:
    nav = config["navigation"]
    root = Path(nav["dir"])
    data = root / "osm"
    data.mkdir(parents=True, exist_ok=True)
    pbfs, dumps = [], []
    for region in nav["regions"]:
        name = region.rsplit("/", 1)[-1]
        pbf = data / f"{name}-latest.osm.pbf"
        dump = data / f"photon-dump-{name}.jsonl.zst"
        fetch_checked(f"{GEOFABRIK}/{region}-latest.osm.pbf", pbf, config["downloadLimit"])
        fetch_checked(
            f"{PHOTON_DUMPS}/{region}/photon-dump-{name}-{PHOTON_DUMP_VERSION}-latest.jsonl.zst",
            dump,
            config["downloadLimit"],
        )
        pbfs += [pbf] if pbf.exists() else []
        dumps += [dump] if dump.exists() else []
    # regions no longer configured
    on_disk = set(data.glob("*.osm.pbf")) | set(data.glob("photon-dump-*.jsonl.zst"))
    for old in sorted(on_disk - set(pbfs) - set(dumps)):
        log(f"  removing {old.name} (no longer configured)")
        old.unlink()

    def stale(built: Path, sources: list[Path]) -> bool:
        stamp = built / "inputs.json"
        return bool(sources) and (not stamp.exists() or stamp.read_text() != inputs_stamp(sources))

    if stale(root / "valhalla", pbfs) and build_routing(nav, pbfs):
        restart("offline-routing.service")
    if stale(root / "photon", dumps) and build_search(nav, dumps):
        restart("offline-search.service")


# --- archive: offline Nix cache and model copies ---------------------------


def system_roots() -> list[str]:
    """The running system and the two newest generations (to roll back to)."""
    profiles = Path("/nix/var/nix/profiles")
    generations = sorted(
        profiles.glob("system-*-link"),
        key=lambda p: int(p.name.split("-")[1]),
    )[-2:]
    roots = {os.path.realpath("/run/current-system")}
    roots.update(os.path.realpath(g) for g in generations)
    return sorted(roots)


def store_hash(path: str) -> str:
    return Path(path).name.split("-", 1)[0]


def sync_archive(config: dict) -> None:
    archive = config["archive"]
    # root copies the models in next; the directories should be the user's
    for directory in archive.get("modelDirs") or []:
        Path(directory).mkdir(parents=True, exist_ok=True)
    if archive.get("cacheDir"):
        cache = Path(archive["cacheDir"])
        cache.mkdir(parents=True, exist_ok=True)
        url = f"file://{cache}?compression=zstd&parallel-compression=true"
        roots = system_roots()
        log(f"↓ nix cache: {len(roots)} system generation(s) → {cache}")
        subprocess.run(["nix", "copy", "--to", url, *roots], check=True)
        live = set()
        closure = subprocess.run(
            ["nix", "path-info", "--recursive", *roots],
            capture_output=True, text=True, check=True,
        ).stdout.split()
        live.update(store_hash(p) for p in closure)
        if archive.get("flake"):
            flake = f"git+file://{archive['flake']}"
            log(f"↓ nix cache: every input of {archive['flake']}")
            subprocess.run(["nix", "flake", "archive", "--to", url, flake], check=True)
            listing = json.loads(
                subprocess.run(
                    ["nix", "flake", "archive", "--json", "--dry-run", flake],
                    capture_output=True, text=True, check=True,
                ).stdout
            )
            stack = [listing]
            while stack:
                node = stack.pop()
                if node.get("path"):
                    live.add(store_hash(node["path"]))
                stack.extend((node.get("inputs") or {}).values())
        prune_cache(cache, live)

    if archive.get("flake") and archive.get("bundle"):
        # the repo itself, all history in one file: what a reinstall clones
        bundle = Path(archive["bundle"])
        bundle.parent.mkdir(parents=True, exist_ok=True)
        tmp = bundle.with_name(bundle.name + ".tmp")
        subprocess.run(["git", "-C", archive["flake"], "bundle", "create", str(tmp), "--all"], check=True)
        os.replace(tmp, bundle)
        log(f"✓ {bundle}")



def prune_cache(cache: Path, live: set[str]) -> None:
    """Drop what no kept generation or flake input refers to any more."""
    removed = 0
    referenced = set()
    for narinfo in cache.glob("*.narinfo"):
        if narinfo.stem not in live:
            narinfo.unlink()
            removed += 1
            continue
        for line in narinfo.read_text().splitlines():
            if line.startswith("URL: "):
                referenced.add(line[5:].strip())
    nar_dir = cache / "nar"
    if nar_dir.is_dir():
        for nar in nar_dir.iterdir():
            if f"nar/{nar.name}" not in referenced:
                nar.unlink()
    if removed:
        log(f"  pruned {removed} path(s) no generation needs any more")


# --- status ----------------------------------------------------------------


def status(config: dict) -> dict:
    library = []
    directories = {Path(config["kiwix"]["library"]).parent} | {
        Path(b["dir"]) for b in config["kiwix"]["books"]
    }
    for directory in sorted(directories):
        for zim in complete_zims(directory):
            match = DATED.match(zim.name)
            library.append(
                {
                    "book": match["book"] if match else zim.stem,
                    "release": match["date"] if match else "",
                    "bytes": zim.stat().st_size,
                    "dir": str(directory),
                }
            )
    wanted = {b["book"] for b in config["kiwix"]["books"]}
    have = {entry["book"] for entry in library}
    maps_meta = Path(config["maps"]["dir"]) / "planet.json"
    disks = {}
    for directory in sorted(directories | {Path(config["maps"]["dir"])}):
        if directory.is_dir():
            usage = shutil.disk_usage(directory)
            disks[str(directory)] = {"free": usage.free, "total": usage.total}
    docs_dir, apps_dir = Path(config["docs"]["dir"]), Path(config["apps"]["dir"])
    nav_dir = Path(config["navigation"]["dir"])

    def finished(path: Path) -> bool:  # not a download in progress
        return path.is_file() and path.suffix not in (".aria2", ".part") and not path.with_name(path.name + ".aria2").exists()

    return {
        "updated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "library": library,
        "missing": sorted(wanted - have),
        "maps": json.loads(maps_meta.read_text()) if maps_meta.exists() else None,
        "docs": sum(1 for p in docs_dir.rglob("*") if finished(p)) if config["docs"]["enable"] and docs_dir.is_dir() else 0,
        "apps": sorted(p.name for p in apps_dir.glob("*.apk") if finished(p)) if config["apps"]["enable"] and apps_dir.is_dir() else [],
        "navigation": {
            "regions": config["navigation"]["regions"],
            "routing": (nav_dir / "valhalla" / "valhalla.json").exists(),
            "search": (nav_dir / "photon" / "photon_data").exists(),
        }
        if config["navigation"]["enable"]
        else None,
        "disks": disks,
    }


def write_status(config: dict) -> None:
    state = Path(config["stateDir"])
    if state.is_dir() and os.access(state, os.W_OK):
        write_atomic(state / "status.json", json.dumps(status(config), indent=1))


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else "all"
    config = json.loads(Path(os.environ["OFFLINE_CONFIG"]).read_text())
    if command == "status":
        report = status(config)
        for entry in report["library"]:
            log(f"{entry['bytes'] / GIB:8.1f} GiB  {entry['book']}  {entry['release']}")
        for book in report["missing"]:
            log(f"     missing  {book}")
        log(f"map: {report['maps']['key'] if report['maps'] else 'not downloaded'}")
        log(f"documents: {report['docs']}; apps: {', '.join(report['apps']) or 'none'}")
        return 0
    if command == "prepare":
        ensure_library(config)
        write_shelf(config)
        return 0
    if command not in ("library", "maps", "docs", "apps", "navigation", "all", "archive"):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        # the small things first: they are there within minutes of a first run
        if command in ("docs", "all") and config["docs"]["enable"]:
            sync_docs(config)
        if command in ("apps", "all") and config["apps"]["enable"]:
            sync_apps(config)
        if command in ("navigation", "all") and config["navigation"]["enable"]:
            sync_navigation(config)
        if command in ("library", "all") and config["kiwix"]["enable"]:
            sync_library(config)
        if command in ("maps", "all") and config["maps"]["enable"]:
            sync_maps(config)
        if command == "archive":
            sync_archive(config)
    finally:
        write_status(config)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
