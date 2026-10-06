# Per-container metrics

**Status:** draft

CPU, memory and network per container in Grafana, without giving a web-facing service the Docker socket.

## Goal

Host metrics are complete, but there is no way to see which container is using the CPU or the memory.
Done when Grafana graphs per-container CPU and memory, and no container but the socket proxy mounts the socket.

## Scope

- In: cAdvisor scraped by Prometheus, reaching Docker only through `docker-socket-proxy` with a minimal allowlist.
- Out: giving cAdvisor the socket directly; container alerting.

## Design

- `docker-socket-proxy` (pinned) mounts `/var/run/docker.sock:ro` on an internal-only network, with only the read endpoints cAdvisor needs (`CONTAINERS=1`, `INFO=1`, everything else 0, `POST=0`).
- cAdvisor talks to the proxy over `DOCKER_HOST`; it publishes no port and joins Prometheus' network.
- A `cadvisor` scrape job in `config/prometheus/prometheus.yml` and a provisioned dashboard JSON.
- This is a deliberate, narrow exception to the no-socket rule; record it in [Monitoring](../monitoring.md).

## Tasks

- [ ] Confirm cAdvisor can run against the proxy's allowlist (it also reads cgroups from `/sys`).
- [ ] Add both services to `stacks/monitoring.yaml` and Diun.
- [ ] Add the scrape job and dashboard.

## Done when

- [ ] Per-container CPU and memory graphs render.
- [ ] `POST` to the proxy is refused.
- [ ] `docs/monitoring.md` updated, this spec is deleted and removed from `roadmap.md` and `AGENTS.md`.

## Open questions

- Whether cAdvisor's cgroup reads alone (no Docker API) are enough for named series. Owner: whoever builds it; default use the proxy.

## Related

- [Monitoring](../monitoring.md)
- [Dashboard](../dashboard.md)
