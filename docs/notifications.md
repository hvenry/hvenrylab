# Notifications

ntfy at `ntfy.hvenry.com`: the one push channel every part of the stack reports through.

## Why

Backups, power loss and new image tags all need to reach a phone without depending on a third-party service that reads the message.
Self-hosting ntfy keeps message bodies on the tailnet.

## How it works

- One topic, `NTFY_TOPIC` in `.env`, carries everything.
- Publishers:
  - Diun posts new image tags container to container at `http://ntfy:80`.
  - `homelab-backup` and `homelab-powerguard` run on the host, read the topic out of `.env` with `sed` (never sourcing it), and post to `http://127.0.0.1:8082/<topic>`.
- Messages are cached 72h; users live in `data/ntfy/lib/user.db`.

## Tech

- ntfy (`binwiederhier/ntfy`)
- Apple Push Notification service via the `ntfy.sh` upstream

## Key files

- `stacks/platform.yaml` - ntfy service and its env
- `host/backup/homelab-backup.sh`, `host/powerguard/homelab-powerguard.sh` - host-side publishers
- `stacks/monitoring.yaml` - Diun's ntfy settings

## Decisions and gotchas

- **The topic is the credential.** Anyone who can reach the server and knows the string can read and publish; generate it with `echo "homelab-$(openssl rand -hex 8)"`.
- **iOS needs `NTFY_UPSTREAM_BASE_URL=https://ntfy.sh`.** Apple only wakes an app via APNs, which a self-hosted server cannot reach.
  ntfy forwards a poll request carrying only the message ID; the phone then fetches the body from here.
  Without it, iOS receives nothing while the app is backgrounded.
- Host publishers fail open (`|| true`): a dead ntfy never fails a backup or blocks a shutdown.

## Related

- [Backup](backup.md)
- [Power guard](powerguard.md)
- [Monitoring](monitoring.md)
