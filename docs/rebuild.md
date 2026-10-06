# Rebuild

The order to bring this stack up from a bare machine, with the values this machine uses; each step links the doc holding the detail.

## Why

Several pieces depend on each other in non-obvious ways: Caddy cannot serve before DNS and the Cloudflare token exist, and Bazarr needs API keys from Radarr and Sonarr.
Doing it out of order produces failures that look unrelated to their cause.

## How it works

1. **Host:** pacman grub hook, then `linux-lts` and `nvidia-open-dkms`; Docker with the NVIDIA toolkit; mask sleep targets; ignore the lid ([Host](host.md)).
2. **Tailscale:** `tailscale up --ssh --hostname=hvenrylab`; MagicDNS on, Global nameservers + Override local DNS, key expiry disabled ([Ingress](ingress.md)).
3. **Storage:** mount `@media` at `/srv/media` and `@backup` at `/srv/backup`, create `library/{movies,tv,music}`, `chown -R 1001:1001 /srv/media` ([Storage](storage.md)).
4. **DNS:** `*.hvenry.com` A record to the Tailscale IP, DNS only; create the Cloudflare token ([Ingress](ingress.md)).
5. **Config:** `cp .env.example .env` and fill it in (values below).
6. **Restore `data/`** from restic if this is a rebuild rather than a first build ([Backup](backup.md)).
7. **Up:** `docker compose up -d`, then `docker logs caddy 2>&1 | grep 'certificate obtained'`.
8. **Jellyfin:** wizard, libraries, NVENC transcoding, plugins ([Jellyfin](jellyfin.md), [Jellyfin plugins](jellyfin-plugins.md)).
9. **Radarr, Sonarr, Bazarr:** root folders, naming, library import, subtitles ([Library managers](library-managers.md)).
10. **Dashboard keys:** copy API keys into `.env`, recreate `homepage` ([Dashboard](dashboard.md)).
11. **Monitoring:** Grafana login, import dashboard 1860; Uptime Kuma monitors and notification ([Monitoring](monitoring.md)).
12. **Local images:** build `clear-rag` and `ootd`, re-seed the corpus ([Local AI](ai.md), [ootd](ootd.md)).
13. **Host units:** install backup and power guard as root ([Backup](backup.md), [Power guard](powerguard.md)).
14. **End to end:** copy a film into the library, confirm Radarr renames it and Jellyfin plays it with a GPU transcode.

`.env` values for this machine (secrets omitted):

| Key | Value |
|---|---|
| `PUID` / `PGID` | `1001`, owner of `data/` and `/srv/media` |
| `TZ` | `America/Toronto` |
| `DOMAIN` | `hvenry.com` |
| `TS_IP` | the machine's Tailscale IP (`tailscale ip -4`), the interface Caddy binds |
| `MEDIA_DIR` | `/srv/media/library` |
| `CLOUDFLARE_API_TOKEN` | `Zone:DNS:Edit` on the one zone |
| `GRAFANA_PASSWORD`, `NTFY_TOPIC`, `OOTD_DB_PASSWORD` | Required; Compose refuses to start the service without the first and last |
| `*_API_KEY` | Dashboard widgets, filled in at step 10 |

## Tech

- See each linked doc.

## Key files

- `.env.example` - every variable with its reasoning
- `compose.yaml` - the project entry point

## Decisions and gotchas

- Until Caddy has its certificate the `hvenry.com` names fail; the `127.0.0.1` fallbacks still work.
- `usermod -aG docker` takes effect only in a new login session.
- Use letters and digits in passwords you choose: `.env` is Compose syntax, and `#` or `$` mid-value break it.

## Related

- [Compose layout](compose-layout.md)
- [Architecture](architecture.md)
