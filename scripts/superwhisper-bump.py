#!/usr/bin/env python3
"""Move flakes/superwhisper/package.nix to the latest stable Superwhisper.

Reads the stable manifest, downloads each architecture's archive, checks its
size and SHA-256 against the manifest and its minisign signature against the
pinned release key (the one upstream's installer and updater use), and only
then rewrites `version` and the two hashes. Prints the new version, or
nothing when the package is already current. Run with `python3 -I`;
minisign must be on PATH.

Used by .github/workflows/superwhisper-update.yml; works locally too:
  nix shell nixpkgs#minisign -c python3 -I scripts/superwhisper-bump.py
"""

import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import NoReturn
from urllib.parse import urlparse
from urllib.request import Request, urlopen

MANIFEST = "https://tux.superwhisper.com/stable.json"
# app/assets/linux-release.pub in every release; a new key fails closed.
PUBLIC_KEY = "RWRmuTeuIEhSvCYQejUR+zzMNsfxAn7pr9iOZ2ZJ9U1/zJwfsqvhzATB"
ARCHES = {"x86_64": "x86_64-linux", "aarch64": "aarch64-linux"}
PACKAGE = Path(__file__).resolve().parent.parent / "flakes/superwhisper/package.nix"
# Stable releases only; prereleases go to the beta channel.
VERSION = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
MAX_ARCHIVE = 512 * 1024 * 1024
TIMEOUT = 60


def die(msg) -> NoReturn:
    print(f"superwhisper-bump: {msg}", file=sys.stderr)
    sys.exit(1)


def trusted(url):
    # Same rule as upstream's updater: HTTPS on its host or GitHub.
    u = urlparse(url)
    host = u.hostname or ""
    return u.scheme == "https" and (
        host in ("tux.superwhisper.com", "github.com")
        or host.endswith(".github.com")
        or host.endswith(".githubusercontent.com")
    )


def open_url(url):
    if not trusted(url):
        die(f"untrusted URL: {url}")
    resp = urlopen(Request(url, headers={"User-Agent": "superwhisper-bump"}), timeout=TIMEOUT)
    if not trusted(resp.geturl()):
        resp.close()
        die(f"redirected to an untrusted URL: {resp.geturl()}")
    return resp


def fetch_text(url, limit=1024 * 1024):
    with open_url(url) as r:
        data = r.read(limit + 1)
    if len(data) > limit:
        die(f"{url} is larger than expected")
    return data.decode()


def download(url, dest, size):
    if size > MAX_ARCHIVE:
        die(f"archive size {size} is implausible")
    digest = hashlib.sha256()
    got = 0
    with open_url(url) as r, open(dest, "wb") as out:
        while chunk := r.read(1 << 20):
            got += len(chunk)
            if got > size:
                die(f"{url} is larger than the manifest says")
            digest.update(chunk)
            out.write(chunk)
    if got != size:
        die(f"{url}: got {got} bytes, manifest says {size}")
    return digest.hexdigest()


def as_tuple(v):
    return tuple(int(p) for p in v.split("."))


def main():
    text = PACKAGE.read_text()
    m = re.search(r'^  version = "([^"]+)";$', text, re.M)
    if not m:
        die(f"no version line in {PACKAGE}")
    current = m.group(1)

    manifest = json.loads(fetch_text(MANIFEST))
    if manifest.get("schema") != 1 or manifest.get("channel") != "stable":
        die("unexpected manifest schema or channel")
    version = manifest.get("version")
    if not isinstance(version, str) or not VERSION.match(version):
        die(f"invalid version in manifest: {version!r}")
    if as_tuple(version) <= as_tuple(current):
        return  # current, or the manifest went backwards: never downgrade

    hashes = {}
    with tempfile.TemporaryDirectory() as tmp:
        for arch, system in ARCHES.items():
            art = (manifest.get("artifacts") or {}).get(arch)
            if not isinstance(art, dict):
                die(f"release {version} has no {arch} build")
            sha = art.get("sha256")
            size = art.get("size")
            if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha):
                die(f"{arch}: invalid sha256 in manifest")
            if not isinstance(size, int) or size <= 0:
                die(f"{arch}: invalid size in manifest")
            name = f"superwhisper-omarchy-{arch}-{version}.tar.zst"
            if Path(urlparse(art.get("url", "")).path).name != name:
                die(f"{arch}: unexpected archive name in manifest")
            archive = Path(tmp) / name
            if download(art["url"], archive, size) != sha:
                die(f"{arch}: SHA-256 does not match the manifest")
            sig = archive.with_suffix(archive.suffix + ".minisig")
            sig.write_text(fetch_text(art.get("signature", ""), 4096))
            res = subprocess.run(
                ["minisign", "-V", "-P", PUBLIC_KEY, "-m", str(archive), "-x", str(sig)],
                capture_output=True,
                text=True,
                timeout=TIMEOUT,
                check=False,
            )
            if res.returncode != 0:
                die(f"{arch}: signature check failed: {res.stderr.strip()}")
            # The signed comment names the version, so an older signed
            # archive can't be passed off as this one.
            # (1.3.1's: "superwhisper-linux 1.3.1 <commit>")
            if not re.search(rf"\bsuperwhisper-linux {re.escape(version)}(\s|$)", res.stdout, re.M):
                die(f"{arch}: signature is not for {version}")
            hashes[system] = "sha256-" + base64.b64encode(bytes.fromhex(sha)).decode()

    new = text.replace(m.group(0), f'  version = "{version}";', 1)
    for system, sri in hashes.items():
        arch = system.split("-")[0]
        pattern = re.compile(
            re.escape(system) + r' = \{\s*arch = "' + re.escape(arch) + r'";\s*hash = "[^"]+";'
        )
        new, n = pattern.subn(lambda mm, sri=sri: re.sub(r'hash = "[^"]+"', f'hash = "{sri}"', mm.group(0)), new)
        if n != 1:
            die(f"could not find the {system} hash in {PACKAGE}")

    fd, tmpname = tempfile.mkstemp(dir=PACKAGE.parent, prefix=".package.nix.")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(new)
        os.chmod(tmpname, 0o644)
        os.replace(tmpname, PACKAGE)
    except BaseException:
        os.unlink(tmpname)
        raise
    print(version)


if __name__ == "__main__":
    main()
