# Maintenance

How images are updated and rolled back, and the routine upkeep of the host.

## Why

Under `:latest` an unattended pull can break a service, and the previous version has no name to return to.
Pinning every image makes updates deliberate and rollbacks a one-line revert.

## How it works

1. Diun posts a new tag to ntfy (see [Monitoring](monitoring.md)).
2. Confirm the tag exists: `docker manifest inspect <image:tag>`.
3. Bump the tag in `stacks/<stack>.yaml` and in `config/diun/images.yml`.
4. `docker compose up -d <service>`.
5. If it misbehaves, restore the old tag and run the same command.

The version a running container reports, which is where the pinned tags came from:

```bash
docker inspect radarr --format '{{index .Config.Labels "org.opencontainers.image.version"}}'
```

Regenerate the Diun list from the stacks:

```bash
grep -hoP '(?<=^    image: )\S+' stacks/*.yaml | grep -v -e '\${' -e '^clear-rag:' | sort -u
```

Locally built images (`clear-rag`, `ootd`, `ootd-worker`) are rebuilt from their own repos and bumped the same way (see [Local AI](ai.md), [ootd](ootd.md)).

Host: update Arch every week or two, read the Arch news first, reboot after kernel or NVIDIA updates (see [Host](host.md)).

## Tech

- Docker Compose, Diun, pacman

## Key files

- `stacks/*.yaml` - pinned tags
- `config/diun/images.yml` - watched images, kept in step with the stacks

## Decisions and gotchas

- `docker compose pull` only re-pulls the pinned tags; it never updates anything.
- `docker image prune -f` after updates reclaims the old layers.
- Diun never updates anything itself; that is the point of pinning.
- Regenerate the Diun list rather than hand-editing it; hand edits drifted and left the monitoring images unwatched.

## Related

- [Compose layout](compose-layout.md)
- [Monitoring](monitoring.md)
- [Backup](backup.md)
