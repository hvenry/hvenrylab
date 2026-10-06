#!/usr/bin/env bash
# Nightly restic backup of data/ (~180 MB of app state). See docs/backup.md.
# No media: at ~700 GB it needs its own plan, and the originals exist elsewhere.
# Root: caddy certs and diun.db are root-owned; a user run skips them silently.

set -uo pipefail

: "${RESTIC_REPOSITORY:?set in /etc/homelab-backup.env}"
: "${RESTIC_PASSWORD_FILE:?set in /etc/homelab-backup.env}"
PROJECT_DIR="${BACKUP_PROJECT_DIR:-/home/hvenry/homelab}"
KEEP_DAILY="${BACKUP_KEEP_DAILY:-7}"
KEEP_WEEKLY="${BACKUP_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${BACKUP_KEEP_MONTHLY:-6}"

# systemd sets no HOME for root services, and restic derives its cache dir from it.
export RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-/var/cache/restic}"
mkdir -p "$RESTIC_CACHE_DIR"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE

log() { logger -t homelab-backup "$*"; echo "$*"; }

topic() { sed -n 's/^NTFY_TOPIC=//p' "$PROJECT_DIR/.env" 2>/dev/null | head -1; }
notify() { # notify <title> <tags> <priority> <message>
  local t; t="$(topic)"; [ -n "$t" ] || return 0
  curl -fsS --max-time 10 -H "Title: $1" -H "Tags: $2" -H "Priority: $3" \
    -d "$4" "http://127.0.0.1:8082/$t" >/dev/null 2>&1 || true
}

fail() {
  log "FAILED: $1"
  notify "Backup failed" "rotating_light" "5" "$1 - see: journalctl -t homelab-backup"
  exit 1
}

cd "$PROJECT_DIR" || fail "cannot enter $PROJECT_DIR"

# A stale lock from a killed run silently blocks every later backup.
restic unlock >/dev/null 2>&1 || true

# Dump, never the data dir: files copied from a live cluster are inconsistent.
# Temp name first so a failed dump never replaces the last good one.
if docker ps --format '{{.Names}}' | grep -qx ootd-db; then
  if docker exec ootd-db pg_dump -U ootd -d ootd --clean --if-exists \
      > data/ootd/db.sql.tmp 2> >(logger -t homelab-backup); then
    mv data/ootd/db.sql.tmp data/ootd/db.sql
  else
    rm -f data/ootd/db.sql.tmp
    fail "pg_dump of ootd-db failed"
  fi
fi

log "backing up $PROJECT_DIR/data"
# Output to the journal, not /dev/null: an unreadable error is unfixable.
restic backup data \
  --tag homelab \
  --exclude 'data/jellyfin/cache' \
  --exclude 'data/jellyfin/config/metadata' \
  --exclude 'data/*/transcodes' \
  --exclude 'data/ollama' \
  --exclude 'data/clear-rag/vectors.npy' \
  --exclude 'data/ootd/postgres' \
  --exclude 'data/ootd/hf-cache' \
  --exclude '*.log' 2>&1 | logger -t homelab-backup
rc=${PIPESTATUS[0]}
# Exit 3 = some files unreadable (often a container rewriting one mid-run);
# the snapshot is still written, so warn. Anything else is fatal.
case "$rc" in
  0) : ;;
  3) log "WARNING: some files could not be read; snapshot still written" ;;
  *) fail "restic backup exited $rc" ;;
esac

restic forget \
  --tag homelab \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune 2>&1 | logger -t homelab-backup

# Metadata-only check; --read-data rereads the whole repo, not worth it nightly.
restic check --quiet 2>&1 | logger -t homelab-backup
[ "${PIPESTATUS[0]}" -eq 0 ] || fail "repository check failed"

snaps=$(restic snapshots --tag homelab --json 2>/dev/null | grep -o '"short_id"' | wc -l)
size=$(du -sh "${RESTIC_REPOSITORY}" 2>/dev/null | cut -f1)
log "ok: $snaps snapshots, repo $size"
notify "Backup ok" "floppy_disk" "1" "$snaps snapshots retained, repository $size."
