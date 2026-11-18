#!/usr/bin/env bash
# privacy-check: this repo is public, so it names no hardware of the machines
# it configures (models, memory sizes, serial numbers, display modes). Those
# live in ~/.config/dots-local and /var/lib/dots (docs/offline.md).
#
#   privacy-check.sh files          tracked files (pre-commit hook, CI)
#   privacy-check.sh message FILE   a commit message (commit-msg hook)
#
# A line that must name hardware anyway can carry `privacy: allow`.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

# drive models, GPU models and CUDA architectures, memory sizes, CPU model
# numbers, by-id device paths and USB serials, monitor modes and refresh rates
PATTERN='\b(WD ?(Black|Blue|Red|Green)|FireCuda|BarraCuda|IronWolf|(Samsung ?)?[89][0-9]0 ?(EVO|PRO|Pro|Evo)|Intel ?[0-9]{3}p|SN[0-9]{3,4}X?)\b|\b(RTX|GTX) ?[0-9]{3,4}\b|\bRX ?[0-9]{4}\b|\bsm_[0-9]{2,3}\b|CUDA_ARCHITECTURES=[0-9]|\b[0-9]+ ?Gi?B (card|VRAM|of VRAM|RAM|of RAM)\b|\b(i[3579]-)?1[0-9]{4}(F|K|KF|KS|T)\b|\bRyzen [0-9] [0-9]{4}|/dev/disk/by-id/(nvme|ata|scsi|usb|wwn|mmc)-[A-Za-z0-9][A-Za-z0-9_.:-]{7,}|_[0-9A-F]{12,}-[0-9]{2}\b|\b[0-9]{3,4}x[0-9]{3,4}@[0-9]|\b[0-9]{3}(\.[0-9]+)? ?Hz\b'

case "${1:-files}" in
files)
    # binary files, and this script (its pattern would match itself)
    hits=$(git ls-files -z | grep -zvE '\.(png|jpe?g|svgz?|ttf|otf|qsb|wav|gif|lock|zip)$|^scripts/privacy-check\.sh$' |
        xargs -0 grep -nIE "$PATTERN" 2>/dev/null | grep -v 'privacy: allow')
    ;;
message)
    # what git keeps: the text above `commit -v`'s scissors line, without
    # comment lines (the numbers stay those of the message file)
    hits=$(sed '/^# -* >8 -*$/,$d' "${2:?message file}" | grep -nE "$PATTERN" |
        grep -vE '^[0-9]+:#' | grep -v 'privacy: allow')
    ;;
*)
    echo "usage: privacy-check.sh files | message FILE" >&2
    exit 2
    ;;
esac
[ -z "$hits" ] && exit 0
echo "privacy-check: hardware details in a public repo (move them to ~/.config/dots-local, or mark the line 'privacy: allow'):"
printf '%s\n' "$hits" | cut -c1-200 | sed 's/^/    /'
exit 1
