#!/usr/bin/env bash

set -euo pipefail

FLAKE="${FLAKE:-$HOME/dots}"
ATTR="claude-vm"
IMG="/data/vms/${ATTR}.qcow2"
SHARE="/data/vms/share"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

preflight() {
  [[ -e /dev/kvm ]] || die "no /dev/kvm — is virtualisation enabled in firmware?"
  [[ -w /dev/kvm ]] || die "/dev/kvm not writable — are you in the kvm group?"
  mkdir -p "$SHARE" "$(dirname "$IMG")"
}

build() {
  nix build "${FLAKE}#nixosConfigurations.${ATTR}.config.system.build.vm" \
    --out-link "/tmp/${ATTR}-result"
}

boot() {
  local runner="/tmp/${ATTR}-result/bin/run-${ATTR}-vm"
  [[ -x $runner ]] || die "run build first"
  echo "Ctrl-a x to power off. ssh -p 2222 dev@localhost (password: dev)"
  QEMU_OPTS="${QEMU_OPTS:-} $1" "$runner"
}

case "${1:-run}" in
build)
  preflight
  build
  ;;
run)
  preflight
  build

  boot "-snapshot"
  ;;
persist)
  preflight
  build
  boot ""
  ;;
ssh)
  shift
  exec ssh -p 2222 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    dev@localhost "$@"
  ;;
reset)
  rm -fv "$IMG"
  ;;
*)
  die "usage: $0 {build|run|persist|ssh|reset}"
  ;;
esac
