# Backup

Nightly restic backup of `~/homelab/data/`, the stack's configuration and state, to the data disk.

## Why

`data/` holds everything that cannot be re-created by pulling images: Jellyfin watch history, the *arr databases, Grafana, Uptime Kuma history, Caddy's ACME key and certificates, and ootd's photographs.
Media is not included: at ~700 GB it needs its own plan, and the originals exist elsewhere.

## How it works

- `homelab-backup.timer` fires daily at 03:30 (`Persistent=true`, so a machine that was off catches up at boot).
- The script:
  1. Clears any stale restic lock.
  2. Dumps ootd's Postgres to `data/ootd/db.sql` via a temp file, so a failed dump never replaces the last good one.
  3. Runs `restic backup data`, excluding regenerable caches: Jellyfin cache and metadata, transcodes, `data/ollama`, clear-rag's `vectors.npy`, ootd's live `postgres/` and `hf-cache/`, logs.
  4. Keeps 7 daily, 4 weekly, 6 monthly, prunes, and runs a metadata `restic check`.
  5. Posts "Backup ok" or "Backup failed" to [ntfy](notifications.md).
- The repository is `/srv/backup/restic` on the `@backup` subvolume of the 990 PRO (see [Storage](storage.md)); the password is in `/etc/homelab-backup.pass`.

Restore one file (stop the container first; never restore a database under a running process):

```bash
sudo env RESTIC_REPOSITORY=/srv/backup/restic RESTIC_PASSWORD_FILE=/etc/homelab-backup.pass \
  restic restore latest --target / --include /home/hvenry/homelab/data/radarr/radarr.db
```

Rehearse a full restore into `/tmp/restore-test`, check `radarr.db` and `caddy/caddy` exist, then delete it.
A backup nobody has restored is a hypothesis.

Install, as root: `install` the script to `/usr/local/bin/homelab-backup`, the env to `/etc/homelab-backup.env` (mode 600), the units to `/etc/systemd/system/`, `restic init` once, run the service by hand, and enable the timer only after that run succeeds.

## Tech

- restic, systemd timer, `pg_dump`

## Key files

- `host/backup/homelab-backup.sh` - the backup run
- `host/backup/homelab-backup.env` - repository path and retention
- `host/backup/homelab-backup.service`, `homelab-backup.timer` - schedule
- `/etc/homelab-backup.pass` - repository password, also kept off this machine

## Decisions and gotchas

- **Runs as root.** `data/caddy/caddy` and `data/diun/diun.db` are root-owned; a user-level backup "succeeds" while silently skipping the certificate store.
- **Postgres is dumped, never copied as files**: a copy of a running cluster's files is not a consistent database.
  Restore ootd with `docker exec -i ootd-db psql -U ootd -d ootd < data/ootd/db.sql` into an empty cluster.
- restic exit 3 (some files unreadable, usually rewritten mid-run) is a warning; the snapshot is still written.
- `RESTIC_CACHE_DIR` is set explicitly because systemd sets no `HOME` for a root service.
- **Lose the password, lose the repository.** It must be recorded outside this machine.
- The repository is on the same laptop as the data: it survives the system disk dying, not theft or fire (see [Off-site backup](specs/offsite-backup.md)).
- restic records the absolute path of `data/`, so `--include` and the restored tree use `/home/hvenry/homelab/data/...`; confirm with `restic ls latest | head` before a real restore.

## Related

- [Storage](storage.md)
- [Notifications](notifications.md)
- [ootd](ootd.md)
