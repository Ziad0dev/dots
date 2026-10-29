#!/usr/bin/env bash
# Snapshot the notes. Run it from cron, a timer, or by hand.
#   ./tools/backup.sh [destination-directory]
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
db="${DB_PATH:-$here/data.db}"
dest="${1:-${BACKUP_DIR:-$here/backups}}"
mkdir -p "$dest"
stamp="$(date +%Y%m%d-%H%M%S)"
sqlite3 "$db" ".backup '$dest/data-$stamp.db'"
sqlite3 "$db" ".dump" > "$dest/notes-$stamp.sql"
ls -1t "$dest"/data-*.db | tail -n +15 | xargs -r rm --
ls -1t "$dest"/notes-*.sql | tail -n +15 | xargs -r rm --
echo "$dest/notes-$stamp.sql"
