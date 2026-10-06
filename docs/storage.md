# Storage

Where the media library and backups live on disk, and why disks are addressed by serial.

## Why

The library outgrew the 512 GB system disk, so it lives on a btrfs partition carved out of a second 2 TB NVMe (shared with Windows).
Two NVMe disks in one laptop also means device names that cannot be trusted, which nearly formatted the wrong disk once.

## How it works

| Disk | Role |
|---|---|
| 512 GB NVMe | Arch system disk; `data/` lives here |
| 2 TB NVMe | Windows, plus partition 5: btrfs `homelab-data` |

Partition 5 holds two subvolumes, mounted from `/etc/fstab` with `noatime,nofail,x-systemd.device-timeout=15`:

- `@media` at `/srv/media`
- `@backup` at `/srv/backup` (the restic repository, see [Backup](backup.md))

```
/srv/media/library/    MEDIA_DIR: read-only /media in Jellyfin, read-write /data/library in the *arrs
├── movies/            Heat (1995)/Heat (1995).mkv
├── tv/                Show (2008)/Season 01/Show S01E01.mkv
└── music/
```

Everything is owned by `1001:1001`, the `PUID`/`PGID` the containers run as.
Files arrive over Tailscale with `rsync -avP "<Title> (<Year>)" hvenrylab:/srv/media/library/movies/`.

## Tech

- btrfs subvolumes, systemd fstab mounts

## Key files

- `host/setup-data-disk.sh` - one-shot record: created partition 5 and the subvolumes
- `host/migrate-to-data-disk.sh` - one-shot record: moved `/srv/media` and the restic repo onto it
- `stacks/media.yaml` - the library mounts

## Decisions and gotchas

- **Identify disks by serial, never `/dev/nvmeXn1`.** The two disks swapped names across a reboot; a plan that said `mkfs.btrfs /dev/nvme1n1p5` would have formatted the running system that day.
  Anything mounted at `/`, `/home` or `/boot` is the wrong disk by definition, and both scripts check for it.
- The serials in `host/setup-data-disk.sh` are placeholders in this copy.
- The one-shot scripts are records, not tooling: both refuse to run again (`setup` when partition 5 exists, `migrate` when fstab already has the UUID).
- `nofail` means a missing data disk does not block boot, but Docker does not wait for the mount either; Jellyfin would then see an empty library.
- Jellyfin gets the library read-only: it never needs to modify a file.

## Related

- [Library managers](library-managers.md)
- [Backup](backup.md)
- [Host](host.md)
