# ootd

A closet catalogue at `ootd.hvenry.com`: a garment photographed on the marker rig from a phone is cut out by BiRefNet on the RTX 3070.

## Why

Background removal on the GPU takes under a second per cut, against ~35 s on the CPU, which makes cataloguing a whole closet practical.
Hosting it here keeps the photographs on hardware already backed up nightly.

## How it works

| Container | Role |
|---|---|
| `ootd` | Next.js app built from `~/dev/ootd`; applies pending migrations on start, then serves |
| `ootd-dev` | `next dev` straight off `~/dev/ootd`; what Caddy points at while the app is iterated on |
| `ootd-worker` | Polls Postgres for jobs, runs BiRefNet fp16 on CUDA |
| `ootd-db` | Postgres 17, ootd's alone |

**Dev mode (current):** Caddy proxies `ootd-dev:3000`, the built `ootd` container is stopped, and the worker runs its Python from the checkout through a read-only mount over the image's copy.

| Change in `~/dev/ootd` | To make it live |
|---|---|
| App code | Nothing, it hot-reloads |
| `.env`, `package.json`, lockfile | `docker restart ootd-dev` (reinstalls on start) |
| Worker Python | `docker restart ootd-worker` |
| A new migration | `docker exec ootd-dev corepack pnpm db:migrate` |
| Worker dependencies | Rebuild the worker image |

**Built image:** build with the GPU overlay, set `OOTD_TAG` in `.env`, then `docker compose up -d ootd ootd-worker`:

```bash
cd ~/dev/ootd && OOTD_TAG=<tag> docker compose -f docker-compose.yml -f docker-compose.gpu.yml build app worker
```

To switch back from dev mode: point the Caddyfile at `ootd:3000`, `docker restart caddy`, `docker stop ootd-dev && docker start ootd`, and drop the worker's code mount in `stacks/ootd.yaml` before `docker compose up -d ootd-worker`.

## Tech

- Next.js, pnpm (via corepack), Postgres 17
- PyTorch, BiRefNet, CUDA via the NVIDIA Container Toolkit

## Key files

- `stacks/ootd.yaml` - all four containers
- `data/ootd/storage/` - originals and cutouts, backed up
- `data/ootd/db.sql` - `pg_dump` written by the backup job; `data/ootd/postgres/` itself is excluded
- `data/ootd/hf-cache/` - BiRefNet weights, excluded (re-downloadable)

## Decisions and gotchas

- **Rig measurements are compiled into the client bundle** from `NEXT_PUBLIC_SHEET_*` in `~/dev/ootd/.env`; a re-measured rig needs a rebuild and tag bump for the built image.
- **`CUTOUT_DEVICE=cuda`, not `auto`.** With `auto` a missing GPU (usually a driver upgrade without a reboot) silently turns cuts into 35 s CPU runs; with `cuda` the job fails and says why.
  The GPU overlay is what makes the worker a CUDA build.
- **VRAM is shared three ways**, and everything at once does not fit in 8 GB: Ollama 5.4 GB loaded, BiRefNet 0.47 GB weights and 1.7 GB peak per 1024x1024 cut, Jellyfin ~0.3 GB per transcode.
  The worker calls `torch.cuda.empty_cache()` after every cut, and `MODEL_KEEP_ALIVE_SECONDS=300` unloads BiRefNet after five idle minutes; a reload from `hf-cache` takes about a second.
- cuDNN autotuning is off: it spiked the first cut to 5.9 GB and 28 s with no later speedup, which is an out-of-memory error with Ollama resident.
  A cut that does run out of memory is retried (`MAX_ATTEMPTS=3`).
- `HOME=/tmp` and `USER=ootd` on the worker: there is no passwd entry for 1001 in the image, and torch's `getpass` raises `uid not found` without `USER`.
- Dev mode edits run against the only copy of the closet: take a `pg_dump` before a migration you have not tried.
- `docker restart caddy`, not `caddy reload`, after a Caddyfile edit here: the single-file bind mount can keep the old inode.
- No login; Tailscale is the boundary.

## Related

- [Local AI](ai.md)
- [Backup](backup.md)
- [Ingress](ingress.md)
