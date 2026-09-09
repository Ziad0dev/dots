#!/usr/bin/env python3
"""Fix parseStorageInventory's volume selection.

Upstream picks the FIRST mounted volume it walks into, and the first mountpoint
in that volume's list. On a disk with an ESP ahead of the root partition that
reports /boot at 30% instead of / at 72%, and a root volume mounted at both
/nix/store and / reports /nix/store.

Three changes:
  1. within a volume, prefer "/" over its other mountpoints
  2. across a disk's volumes, prefer the one mounted at "/", else the largest
     by total bytes, instead of the first one found
  3. drop container types (crypto_LUKS, LVM2_member) from the filesystem list —
     they are not filesystems, and they made the NVMe read
     "VFAT + CRYPTO_LUKS + EXT4 + NTFS"

Idempotent, brace-checked, refuses to write on any anchor mismatch.
Usage: run from the repo root, or pass the rise dir as $1.
"""
import shutil
import sys
from pathlib import Path

RISE = Path(sys.argv[1] if len(sys.argv) > 1 else "config/quickshell/rise")

OLD_MOUNT = '''            var mountedAt = ""
            for (var m = 0; m < mounts.length; m++) {
                var candidate = textValue(mounts[m])
                if (candidate !== "" && candidate !== "[SWAP]") {
                    mountedAt = candidate
                    break
                }
            }'''

NEW_MOUNT = '''            var mountedAt = ""
            for (var m = 0; m < mounts.length; m++) {
                var candidate = textValue(mounts[m])
                if (candidate === "" || candidate === "[SWAP]") continue
                if (candidate === "/") { mountedAt = "/"; break }
                if (mountedAt === "") mountedAt = candidate
            }'''

OLD_PICK = '''                if (fileSystems.indexOf(volumes[v].fs) < 0) fileSystems.push(volumes[v].fs)
                if (mountedAt === "" && volumes[v].mount !== "") {
                    mountedAt = volumes[v].mount
                    usage = volumes[v].percent
                    freeBytes = volumes[v].freeBytes
                    usedBytes = volumes[v].usedBytes
                }
            }'''

NEW_PICK = '''                var vol = volumes[v]
                if (vol.fs !== "" && !volumeIsContainer(vol.fs)
                        && fileSystems.indexOf(vol.fs) < 0) fileSystems.push(vol.fs)
                if (vol.mount === "") continue
                var better = mountedAt === ""
                    || (vol.mount === "/" && mountedAt !== "/")
                    || (mountedAt !== "/" && volumeTotal(vol) > bestTotal)
                if (!better) continue
                mountedAt = vol.mount
                usage = vol.percent
                freeBytes = vol.freeBytes
                usedBytes = vol.usedBytes
                bestTotal = volumeTotal(vol)
            }'''

HELPERS = '''        function volumeIsContainer(fs) {
            var f = String(fs).toLowerCase()
            return f === "crypto_luks" || f === "lvm2_member" || f === "linux_raid_member"
        }
        function volumeTotal(vol) {
            return (vol.usedBytes >= 0 ? vol.usedBytes : 0)
                + (vol.freeBytes >= 0 ? vol.freeBytes : 0)
        }
'''

FILE_EDITS = {
    "Theme.qml": [
        ("volumeIsContainer", "volume helpers",
         "        function collectVolumes(node, target) {",
         "before-block", HELPERS),
        ('if (candidate === "/") { mountedAt = "/"; break }', "prefer / within a volume",
         OLD_MOUNT, "replace", NEW_MOUNT),
        ("var bestTotal = -1", "declare the best-volume tracker",
         "            var usedBytes = -1\n            for (var v = 0; v < volumes.length; v++) {",
         "replace",
         "            var usedBytes = -1\n            var bestTotal = -1\n            for (var v = 0; v < volumes.length; v++) {"),
        ("volumeTotal(vol) > bestTotal", "prefer / or the largest volume",
         OLD_PICK, "replace", NEW_PICK),
    ],
}


def _load_checker():
    import importlib.util
    here = Path(__file__).resolve().parent
    for cand in (here / "port-v2-telemetry.py", Path("scripts/port-v2-telemetry.py")):
        if cand.is_file():
            spec = importlib.util.spec_from_file_location("_chk", cand)
            mod = importlib.util.module_from_spec(spec)
            argv, sys.argv = sys.argv, ["_chk"]
            try:
                spec.loader.exec_module(mod)
            finally:
                sys.argv = argv
            return mod
    sys.exit("port-v2-telemetry.py must sit next to this script (it supplies the brace checker)")


def main():
    chk = _load_checker()
    if not RISE.is_dir():
        sys.exit("not a directory: %s (run from the repo root, or pass the rise dir)" % RISE)

    for rel, edits in FILE_EDITS.items():
        path = RISE / rel
        if not path.is_file():
            sys.exit("not found: %s" % path)
        src = path.read_text()
        bad = chk.balance(src, "input " + rel)
        if bad:
            sys.exit("refusing to patch, input unbalanced:\n  " + "\n  ".join(bad))

        applied, skipped = [], []
        for guard, label, anchor, mode, payload in edits:
            if guard in src:
                skipped.append(label)
                continue
            count = src.count(anchor)
            if count != 1:
                sys.exit("%s: anchor for %r matched %d times, expected 1:\n%s"
                         % (rel, label, count, anchor[:160]))
            if mode == "before-block":
                src = src[:src.index(anchor)] + payload + src[src.index(anchor):]
                applied.append(label)
                continue
            if mode == "replace":
                src = src.replace(anchor, payload)
            else:
                end = src.index(anchor) + len(anchor)
                if mode == "after-line":
                    end = src.index("\n", end)
                    if not payload.startswith("\n"):
                        payload = "\n" + payload
                src = src[:end] + payload + src[end:]
            applied.append(label)

        problems = chk.balance(src, "result " + rel)
        if problems:
            sys.exit("%s: patched output unbalanced, NOT writing:\n  %s"
                     % (rel, "\n  ".join(problems)))

        if applied:
            shutil.copy2(path, str(path) + ".bak")
            path.write_text(src)
        print(rel)
        for name in applied:
            print("  +", name)
        for name in skipped:
            print("  =", name, "(already present)")


if __name__ == "__main__":
    main()
