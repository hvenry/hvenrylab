# Power guard

A systemd timer that shuts the stack and the laptop down cleanly before the battery runs out.

## Why

The laptop battery already acts as a UPS, but nothing acted on it: an outage that outlasted the battery cut power mid-write with about fourteen SQLite databases open, plus Prometheus' TSDB.
WAL mode usually survives that, but a rename truncates halfway, a library scan corrupts, and Prometheus drops its head block.
`upower` cannot do the job here: its critical action wants hibernate, and every sleep target is masked.

## How it works

`homelab-powerguard.timer` runs the script every minute; it keys on `/sys/class/power_supply/AC0/online`.

| Battery | Action |
|---|---|
| Mains lost | Notify once: on battery, at N% |
| <= 40% (`POWERGUARD_WARN_AT`) | Notify again |
| <= 15% (`POWERGUARD_THRESHOLD`) | Notify, `docker compose down` under `timeout 120`, `systemctl poweroff` |
| Mains restored | Notify, clear state |

State lives in `/run` (tmpfs), so each transition notifies once and a reboot starts clean.

Install, as root: `install` the script to `/usr/local/bin/homelab-powerguard`, the units to `/etc/systemd/system/`, `daemon-reload`, `enable --now homelab-powerguard.timer`.
Check with `journalctl -t homelab-powerguard -n 20`.

## Tech

- systemd timer and oneshot service, sysfs power supply, [ntfy](notifications.md)

## Key files

- `host/powerguard/homelab-powerguard.sh` - the check
- `host/powerguard/homelab-powerguard.service` - thresholds as `Environment=` lines
- `host/powerguard/homelab-powerguard.timer` - every minute

## Decisions and gotchas

- **AC, not `BAT0/status`.** With the Razer charge limit set, `status` reads `Not charging` on mains with a healthy battery; a status check would shut down a plugged-in machine.
- `timeout 120` on `compose down` means a container that refuses to stop cannot keep the machine up until the battery dies.
- Thresholds live in the unit file; after editing the installed copy, `systemctl daemon-reload`.
- Never test the shutdown path by pulling the plug.
  Copy the script with `AC`, `BAT` and `STATE` pointed at a fake sysfs tree in a temp dir, put stub `docker` and `systemctl` scripts first on `PATH`, and run it.
  Unplugging briefly is fine for testing the notification path.

## Related

- [Host](host.md)
- [Notifications](notifications.md)
