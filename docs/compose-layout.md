# Compose layout

How the Compose project is split into files, and the rules every service in it follows.

## Why

One `compose.yaml` holding twenty-odd services was hard to navigate.
Splitting it by role keeps each service findable, while Compose still treats the whole thing as one project, so `docker compose up -d` brings everything up and services resolve each other by container name.

## How it works

- `compose.yaml` holds only the project name (`homelab`), an `include:` of every file in `stacks/`, and the default network pinned to `172.28.0.0/16`.
- Each include sets `project_directory: .`, so a bind mount written `./data/...` inside `stacks/` resolves from the repo root rather than `stacks/data/...`.
- All stacks share one project and one network.

| Stack | Services |
|---|---|
| `media.yaml` | jellyfin, radarr, sonarr, bazarr |
| `platform.yaml` | caddy, homepage, ntfy |
| `monitoring.yaml` | glances, node-exporter, prometheus, grafana, uptime-kuma, diun |
| `ai.yaml` | ollama, clear-rag |
| `ootd.yaml` | ootd-db, ootd, ootd-dev, ootd-worker |

Rules every service follows:

- **Pinned image tag**, never `:latest`, so an update is a deliberate bump and a rollback has a name (see [Maintenance](maintenance.md)).
- **State under `./data/<service>/`** as a bind mount, never a named volume, so the nightly restic job covers it (see [Backup](backup.md)).
- **Runs as `${PUID}:${PGID}` (1001)** where the image allows: `user:` for most images, `PUID`/`PGID` env for LinuxServer.io images.
- **Publishes only `127.0.0.1:<port>`**, a fallback for when Caddy is down; Caddy is the only thing bound to a non-loopback address (see [Ingress](ingress.md)).
- **Secrets come from `.env`**, which is gitignored; `.env.example` documents every variable.

## Tech

- Docker Compose `include:` with `project_directory`
- Compose profiles and `.env` interpolation

## Key files

- `compose.yaml` - project name, includes, pinned subnet
- `stacks/*.yaml` - the services, one file per role
- `.env.example` - every variable with its reasoning
- `data/` - container state, gitignored

## Decisions and gotchas

- The subnet is pinned because node-exporter binds the bridge gateway `172.28.0.1`, and Prometheus scrapes it at that fixed address.
- A new stack file must be added to `include:` with `project_directory: .`, or its relative paths silently resolve under `stacks/`.
- `.env` is parsed by Compose, not a shell: `#` starts a comment mid-line, `$` starts a variable, and a duplicated key silently overrides the earlier one.
- Comments in the stack files record the failure that motivated each setting; keep them when editing.
- The split changed nothing at runtime: `docker compose config` was byte-identical before and after.
- LinuxServer.io images (`lscr.io/linuxserver/*`) take `PUID`/`PGID` env; everything else (Grafana, ntfy, Postgres) ignores those and needs `user:` instead, or it writes as its own uid into a directory it cannot own.
- Any path passed between containers must be identical in each (one shared parent mounted at the same place), or a file one app moves cannot be found by the next.
- Mount read-only (`:ro`) wherever a container only reads; Jellyfin cannot touch the library.

## Related

- [Ingress](ingress.md)
- [Architecture](architecture.md)
- [Maintenance](maintenance.md)
