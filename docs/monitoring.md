# Monitoring

Host metrics, uptime history and image-update notices, built without giving any container the Docker socket.

## Why

A headless laptop running on battery needs temperature, charge and throughput history, and someone needs to be told when a service goes down or a pinned image has a new tag.
The conventional stack (cAdvisor, socket-discovering Diun) needs the Docker socket, which is root on the host.

## How it works

| Service | Job | Address |
|---|---|---|
| node-exporter | Host metrics, `pid: host`, `/:/host:ro`, host networking | `172.28.0.1:9100`, internal |
| Prometheus | Scrapes `node` and itself every 30s, 90 day retention | `prometheus.hvenry.com` |
| Grafana | Dashboards over Prometheus | `grafana.hvenry.com` |
| Uptime Kuma | HTTP checks with history and alerting | `uptime.hvenry.com` |
| Glances | Live per-core, sensors, processes | `glances.hvenry.com` |
| Diun | Checks pinned images daily at 06:00, notifies via [ntfy](notifications.md) | no UI |

- Grafana's datasource and the **Hardware** dashboard (battery health, charge, AC, CPU temperature per core, network) are provisioned from files.
  "Node Exporter Full" (ID 1860) was imported by hand.
- Uptime Kuma monitors use container names and health endpoints, retries 2:

| Monitor | URL |
|---|---|
| Jellyfin | `http://jellyfin:8096/health` |
| Radarr, Sonarr | `http://radarr:7878/ping`, `http://sonarr:8989/ping` |
| Bazarr | `http://bazarr:6767` |
| Grafana, Prometheus | `http://grafana:3000/api/health`, `http://prometheus:9090/-/healthy` |
| TLS certificate | `https://jellyfin.hvenry.com` |

Check scrape targets:

```bash
docker exec homepage wget -qO- 'http://prometheus:9090/api/v1/targets?state=active' | grep -o '"health":"[a-z]*"'
```

## Tech

- Prometheus, node-exporter, Grafana, Uptime Kuma, Glances, Diun

## Key files

- `stacks/monitoring.yaml` - all six services
- `config/prometheus/prometheus.yml` - scrape jobs
- `config/grafana/provisioning/` - datasource and dashboard provider
- `config/grafana/dashboards/hardware.json` - provisioned dashboard; edit the JSON, not the UI
- `config/diun/images.yml` - static list of watched images

## Decisions and gotchas

- **No Docker socket anywhere**, so there are **no per-container metrics** (see [Per-container metrics](specs/per-container-metrics.md)).
- **node-exporter needs host networking.** `/proc/net` is per network namespace; on the bridge it reported Docker bridge traffic and the WiFi throughput appeared nowhere.
  It binds `172.28.0.1` so host metrics are not published to the LAN.
- `--collector.systemd` is off: it needs the host dbus socket at a path `--path.rootfs` does not redirect, and failed every scrape.
- Root health endpoints redirect to login pages and fail Kuma's 200-299 range; use the paths above.
- The TLS monitor uses the public URL because a broken DNS-01 renewal is silent until clients stop trusting the certificate.
- Grafana's empty provisioning dirs (`alerting`, `notifiers`, `plugins`) are committed so it does not log errors on every start.
- Grafana refuses to start without `GRAFANA_PASSWORD`; there is no default.
- Diun reads a static list, so a tag bump must also update `config/diun/images.yml`; locally built images (clear-rag, ootd) cannot be watched.

## Related

- [Dashboard](dashboard.md)
- [Notifications](notifications.md)
- [Maintenance](maintenance.md)
