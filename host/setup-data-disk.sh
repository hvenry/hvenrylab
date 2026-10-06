#!/usr/bin/env bash
# One-shot, already run (see docs/storage.md): free space on the 990 PRO becomes
# btrfs partition 5 with subvolumes @media (library) and @backup (restic repo).
# Dry run unless --yes:
#   sudo bash host/setup-data-disk.sh          # show the plan
#   sudo bash host/setup-data-disk.sh --yes    # do it

set -euo pipefail

WIN_SERIAL="<data-disk-serial>"    # Samsung SSD 990 PRO 2TB, the Windows disk
ARCH_SERIAL="<system-disk-serial>"    # Samsung MZVLB512HBJQ, the live system: never touch
LABEL="homelab-data"
APPLY="${1:-}"

die() { echo "ERROR: $*" >&2; exit 1; }

# --- Dependencies, checked before anything is announced -------------------
# Failing midway with "creating partition 5" on screen alarms even if nothing was written.
missing=()
for t in sgdisk partprobe udevadm mkfs.btrfs btrfs blkid parted; do
  command -v "$t" >/dev/null || missing+=("$t")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "ERROR: missing required tools: ${missing[*]}" >&2
  echo "       sgdisk/gdisk come from the 'gptfdisk' package:" >&2
  echo "         sudo pacman -S gptfdisk" >&2
  exit 1
fi

# --- Resolve by serial, never by device name ------------------------------
# These disks swapped names (nvme0n1 <-> nvme1n1) across a reboot once; a
# hardcoded /dev/nvmeXn1 would eventually format the running system.
DISK=$(lsblk -dno NAME,SERIAL | awk -v s="$WIN_SERIAL" '$2==s{print "/dev/"$1}')
[ -n "$DISK" ] || die "no disk with serial $WIN_SERIAL"

ARCH=$(lsblk -dno NAME,SERIAL | awk -v s="$ARCH_SERIAL" '$2==s{print "/dev/"$1}')
[ "$DISK" != "$ARCH" ] || die "resolved to the Arch disk. Refusing."

# --- Safety gates ---------------------------------------------------------
lsblk -no MOUNTPOINT "$DISK" | grep -q . && die "$DISK has mounted partitions. Refusing."
for mp in / /home /boot; do
  src=$(findmnt -no SOURCE "$mp" 2>/dev/null || true)
  case "$src" in "$DISK"*) die "$mp lives on $DISK. Refusing." ;; esac
done
lsblk -no NAME "$DISK" | grep -qx "$(basename "$DISK")p5" && \
  die "${DISK}p5 already exists. Nothing to do."

echo "Target disk : $DISK  ($(lsblk -dno MODEL,SIZE "$DISK" | xargs))"
echo "Arch disk   : $ARCH  (excluded)"
echo
echo "Current partitions and free space:"
parted -s "$DISK" unit GiB print free | sed 's/^/    /'
echo
echo "Plan:"
echo "    1. create partition 5 in the largest free block (type 8300)"
echo "    2. mkfs.btrfs -L $LABEL"
echo "    3. create subvolumes @media and @backup"
echo

if [ "$APPLY" != "--yes" ]; then
  echo "Dry run. Re-run with --yes to apply."
  exit 0
fi

echo "==> creating partition 5"
sgdisk --largest-new=5 --typecode=5:8300 --change-name=5:"$LABEL" "$DISK"
partprobe "$DISK"; udevadm settle; sleep 2

PART="${DISK}p5"
[ -b "$PART" ] || die "$PART did not appear"
echo "==> $PART is $(lsblk -dno SIZE "$PART")"

echo "==> formatting btrfs"
# No compression: video already is. btrfs is for checksums: archive bitrot is otherwise silent.
mkfs.btrfs -L "$LABEL" "$PART"

echo "==> creating subvolumes"
MNT=$(mktemp -d)
mount "$PART" "$MNT"
btrfs subvolume create "$MNT/@media"
btrfs subvolume create "$MNT/@backup"
btrfs subvolume list "$MNT"
umount "$MNT"; rmdir "$MNT"

echo
echo "Done. UUID for fstab:"
blkid -s UUID -o value "$PART"
