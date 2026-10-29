#!/usr/bin/env bash
set -euo pipefail

staging=${1:?usage: dots-restic-snapshot STAGING_DIR}
work="${staging}.new"
units=(
  sonarr.service
  radarr.service
  prowlarr.service
  qbittorrent.service
  jellyfin.service
  audiobookshelf.service
  calibre-web.service
)
sources=(
  sonarr
  radarr
  private/prowlarr
  qBittorrent
  jellyfin
  audiobookshelf
  calibre-web
)
active=()

restart_services() {
  if ((${#active[@]})); then
    systemctl start "${active[@]}"
  fi
}

cleanup() {
  rm -rf -- "$work"
  restart_services
}

for unit in "${units[@]}"; do
  if systemctl is-active --quiet "$unit"; then
    active+=("$unit")
  fi
done

# Restic must never read a partial copy. Any stop/copy failure reaches this
# trap, which restores only the services that were active before preparation.
trap cleanup EXIT
systemctl stop "${units[@]}"

rm -rf -- "$work"
install -d -m 0700 "$work"
for source in "${sources[@]}"; do
  destination="$work/${source##*/}"
  excludes=(
    --exclude='MediaCover/'
    --exclude='logs/'
    --exclude='Cache/'
    --exclude='CachedData/'
    --exclude='Code Cache/'
    --exclude='GPUCache/'
    --exclude='ShaderCache/'
    --exclude='node_modules/'
    --exclude='.direnv/'
    --exclude='target/'
    --exclude='zig-cache/'
    --exclude='zig-out/'
    --exclude='.venv/'
    --exclude='__pycache__/'
  )
  if [ "$source" = jellyfin ]; then
    excludes+=(
      --exclude='/metadata/'
      --exclude='/log/'
    )
  fi
  install -d -m 0700 "$destination"
  rsync -aHAX --numeric-ids "${excludes[@]}" \
    "/var/lib/$source/" "$destination/"
done

# Replace the previous staging tree only after every source copied cleanly.
rm -rf -- "$staging"
mv -- "$work" "$staging"

# The upload, prune, and integrity check run after services are back online.
restart_services
trap - EXIT
