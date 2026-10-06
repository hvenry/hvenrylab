# Grafana alerting

**Status:** draft

Alerts on slow trends the uptime checks cannot see, delivered to the phone through ntfy.

## Goal

Uptime Kuma answers "is it up"; nothing answers "the disk will be full in a week" or "the CPU has been at 90C for an hour".
Done when each rule below fires against a forced condition and reaches the phone.

## Scope

- In: provisioned alert rules and an ntfy contact point, as files under `config/grafana/provisioning/alerting/`.
- Out: per-container alerts (need [Per-container metrics](per-container-metrics.md)); replacing Uptime Kuma.

## Design

- Contact point: a webhook to `http://ntfy:80/<topic>`, the topic injected from `.env` via Grafana env interpolation so it is not committed.
- Rules, all over existing node-exporter series:
  - `/srv/media` and `/` predicted full within 7 days (`predict_linear` on `node_filesystem_avail_bytes`).
  - CPU package temperature above 90C for 30 minutes.
  - Battery health (full capacity vs design) below a threshold, as a slow-degradation notice.
  - node-exporter target down for 5 minutes.
- Files, not the UI, so the rules are versioned like the dashboards (see [Monitoring](../monitoring.md)).

## Tasks

- [ ] Add the contact point and notification policy files.
- [ ] Add the four rules; tune thresholds against 90 days of history.
- [ ] Force each condition (a lowered threshold) and confirm delivery.

## Done when

- [ ] Every rule has fired once to the phone in testing.
- [ ] `docs/monitoring.md` describes the alerts, this spec is deleted and removed from `roadmap.md` and `AGENTS.md`.

## Open questions

- Battery health threshold. Default: alert below 80% of design capacity.

## Related

- [Monitoring](../monitoring.md)
- [Notifications](../notifications.md)
