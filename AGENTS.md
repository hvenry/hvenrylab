# hvenrylab

Docker Compose homelab on one Arch laptop (`hvenrylab`, RTX 3070 Laptop), serving a personal media library, local AI and small apps.
Every service gets `https://<name>.hvenry.com`, reachable only over Tailscale.
There is no application code: the repo is compose files, Caddy, Homepage, Prometheus and Grafana config, host systemd units, and docs.
Stack: Docker Compose, Caddy, Tailscale, Cloudflare DNS, Jellyfin, Radarr/Sonarr/Bazarr, Prometheus and Grafana, Ollama, restic.

## Commands

No build or test suite: validation is Compose's parser, Caddy's validator, and checking the running containers.

```bash
docker compose config --quiet                                   # validate the merged project (needs .env)
docker compose up -d <service>                                  # apply a change to one service
docker compose logs -f <service>                                # follow one service's logs
docker exec caddy caddy validate --config /etc/caddy/Caddyfile  # check a Caddyfile edit
docker exec caddy caddy reload --config /etc/caddy/Caddyfile    # apply a Caddyfile edit
docker manifest inspect <image:tag>                             # confirm a tag exists before pinning it
curl -X POST http://127.0.0.1:9090/-/reload                     # reload Prometheus config
```

## Repo map

```
compose.yaml   project name, include: of stacks/, pinned subnet
stacks/        services by role: media, platform, monitoring, ai, ootd
Caddyfile      wildcard TLS and one host matcher per service
homepage/      dashboard config
config/        prometheus, grafana provisioning and dashboards, diun image list
host/          systemd units and scripts installed by hand as root
docs/          one doc per concept; specs/ holds planned work
data/          container state, gitignored, backed up nightly
```

## Conventions

- **Pin every image to an exact tag, and mirror it in `config/diun/images.yml`.** `:latest` breaks unattended and leaves nothing to roll back to.
- **Bind mounts under `./data/` only, never named volumes.** The restic job backs up `data/`; a named volume goes silently unbacked.
- **Publish `127.0.0.1:<port>` only; Caddy alone binds `${TS_IP}:443`.** Docker's iptables bypass ufw, so `0.0.0.0` exposes the service to the LAN.
- **Never mount the Docker socket.** It is root on the host; Homepage, Prometheus and Diun all work without it.
- **Run as `${PUID}:${PGID}` (1001) where the image allows.** `data/` and `/srv/media` are owned by that user.
- **Mount the library read-only everywhere except the library managers.** Jellyfin never needs to write, so it cannot damage the library.
- **Keep `.env.example` in sync with every variable used.** It is the only record of what `.env` needs.
- **Comments in compose and config explain why, usually a failure that was hit.** Keep them when editing.
- **Never run `host/setup-data-disk.sh` or `host/migrate-to-data-disk.sh`; address disks by serial.** They are one-shot records, and NVMe names swap across reboots.
- **After changing docs, re-seed the clear-rag corpus** (command in `docs/ai.md`), or `rag.hvenry.com` answers from stale docs.

## Docs

Host:

- Before rebuilding the machine from scratch, read `docs/rebuild.md`.
- Before changing the kernel, GPU driver or power settings, read `docs/host.md`.
- Before touching disks or media paths, read `docs/storage.md`.

Platform:

- Before adding a stack file or project-wide setting, read `docs/compose-layout.md`.
- Before adding a service or changing DNS, TLS or Caddy, read `docs/ingress.md`.
- Before editing Homepage, read `docs/dashboard.md`.
- Before changing ntfy or anything that notifies, read `docs/notifications.md`.

Media:

- Before changing Jellyfin, read `docs/jellyfin.md` and `docs/jellyfin-plugins.md`.
- Before changing Radarr, Sonarr or Bazarr, read `docs/library-managers.md`.

Operations:

- Before updating images, read `docs/maintenance.md`.
- Before changing metrics, Grafana, Uptime Kuma or Diun, read `docs/monitoring.md`.
- Before changing backups or restoring, read `docs/backup.md`.
- Before changing the low-battery shutdown, read `docs/powerguard.md`.

Apps:

- Before changing Ollama, clear-rag or GPU memory settings, read `docs/ai.md`.
- Before changing ootd, read `docs/ootd.md`.

Start with `docs/architecture.md` for how the pieces fit together.

## Planned

Build order: `docs/specs/roadmap.md`.

- Before implementing Grafana alerting, read `docs/specs/grafana-alerting.md`.
- Before implementing the off-site backup, read `docs/specs/offsite-backup.md`.
- Before implementing per-container metrics, read `docs/specs/per-container-metrics.md`.
- Before implementing poster overlays, read `docs/specs/poster-overlays.md`.
