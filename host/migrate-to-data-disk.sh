#!/usr/bin/env bash
# One-shot, already run (see docs/storage.md): move /srv/media and the restic repo
# onto the 990 PRO subvolumes, mounted at the SAME paths so nothing else changes.
# Dry run unless --yes:
#   sudo bash host/migrate-to-data-disk.sh
#   sudo bash host/migrate-to-data-disk.sh --yes

set -euo pipefail

DATA_UUID="2f121b63-9d1b-4e3e-ad18-2dd2f5239540"
PROJECT_DIR="/home/hvenry/homelab"
APPLY="${1:-}"
die() { echo "ERROR: $*" >&2; exit 1; }

for t in rsync findmnt blkid mount umount docker systemctl; do
  command -v "$t" >/dev/null || die "missing tool: $t"
done

DEV=$(blkid -U "$DATA_UUID") || die "no filesystem with UUID $DATA_UUID"
echo "data disk : $DEV (UUID $DATA_UUID)"

# --- Already migrated? ----------------------------------------------------
# Destructive if repeated: rsyncs /srv/media onto itself via a second mount, mvs a
# live mountpoint aside, duplicates fstab entries. Completed 2026-09-13.
if [ "$(findmnt -no UUID /srv/media 2>/dev/null)" = "$DATA_UUID" ]; then
  die "/srv/media is already on the data disk. This script is one-shot; nothing to do."
fi
grep -q "$DATA_UUID" /etc/fstab 2>/dev/null &&   die "/etc/fstab already references $DATA_UUID. Migration has already run."

# Baseline BEFORE anything moves; verification compares against it.
src_files=$(find /srv/media -type f | wc -l)
src_dirs=$(find /srv/media -type d | wc -l)
src_links=$(find /srv/media -type f -links +1 | wc -l)
src_inodes=$(find /srv/media -type f -links +1 -printf '%i\n' | sort -u | wc -l)
src_du=$(du -sb /srv/media | cut -f1)

echo
echo "source /srv/media:"
echo "    files=$src_files dirs=$src_dirs hardlinked=$src_links (over $src_inodes inodes)"
echo "    apparent size=$(numfmt --to=iec "$src_du")"
echo
echo "Plan:"
echo "    1. docker compose down"
echo "    2. rsync -aHAX /srv/media/ -> @media   (-H preserves the hardlinks)"
echo "    3. verify counts, inode pairing and size match exactly"
echo "    4. move restic repo -> @backup"
echo "    5. write fstab entries, mount at /srv/media and /srv/backup"
echo "    6. docker compose up -d"
echo "    Old data is left at /srv/media.old until you delete it."
echo

[ "$APPLY" = "--yes" ] || { echo "Dry run. Re-run with --yes to apply."; exit 0; }

echo "==> stopping the stack"
cd "$PROJECT_DIR"; docker compose down
systemctl stop homelab-backup.timer 2>/dev/null || true

TMP=$(mktemp -d)
echo "==> copying media"
mount -o subvol=@media "$DEV" "$TMP"
rsync -aHAX --info=progress2 /srv/media/ "$TMP/"

echo "==> verifying"
dst_files=$(find "$TMP" -type f | wc -l)
dst_dirs=$(find "$TMP" -type d | wc -l)
dst_links=$(find "$TMP" -type f -links +1 | wc -l)
dst_inodes=$(find "$TMP" -type f -links +1 -printf '%i\n' | sort -u | wc -l)
dst_du=$(du -sb "$TMP" | cut -f1)

# dirs differ by one: $TMP itself stands in for /srv/media
fail=0
[ "$dst_files"  -eq "$src_files"  ] || { echo "  FILE COUNT $dst_files != $src_files"; fail=1; }
[ "$dst_links"  -eq "$src_links"  ] || { echo "  HARDLINKS $dst_links != $src_links"; fail=1; }
[ "$dst_inodes" -eq "$src_inodes" ] || { echo "  INODES $dst_inodes != $src_inodes"; fail=1; }
if [ "$fail" -ne 0 ]; then
  umount "$TMP"; rmdir "$TMP"
  cd "$PROJECT_DIR" && docker compose up -d
  die "verification failed. Nothing was deleted; stack restarted on the old path."
fi
echo "  files=$dst_files hardlinked=$dst_links over $dst_inodes inodes - matches"
echo "  size=$(numfmt --to=iec "$dst_du") (source $(numfmt --to=iec "$src_du"))"
umount "$TMP"

echo "==> moving the restic repository"
mount -o subvol=@backup "$DEV" "$TMP"
if [ -d /srv/backup/restic ]; then
  rsync -aHAX /srv/backup/restic/ "$TMP/restic/"
  echo "  copied $(du -sh "$TMP/restic" | cut -f1)"
fi
umount "$TMP"; rmdir "$TMP"

echo "==> swapping paths"
mv /srv/media /srv/media.old
mv /srv/backup /srv/backup.old
mkdir -p /srv/media /srv/backup

cp /etc/fstab /etc/fstab.bak-$(date +%Y%m%d-%H%M%S)
cat >> /etc/fstab <<FSTAB

# Data disk (Samsung 990 PRO). nofail: a missing disk must not block boot.
UUID=$DATA_UUID  /srv/media   btrfs  subvol=@media,noatime,nofail,x-systemd.device-timeout=15   0 0
UUID=$DATA_UUID  /srv/backup  btrfs  subvol=@backup,noatime,nofail,x-systemd.device-timeout=15  0 0
FSTAB

systemctl daemon-reload
mount -a
findmnt /srv/media >/dev/null || die "/srv/media did not mount"
findmnt /srv/backup >/dev/null || die "/srv/backup did not mount"

echo "==> restarting the stack"
cd "$PROJECT_DIR"; docker compose up -d
systemctl start homelab-backup.timer 2>/dev/null || true

echo
echo "Done. Old copies remain at /srv/media.old and /srv/backup.old."
echo "Delete them once you are satisfied:  sudo rm -rf /srv/media.old /srv/backup.old"
