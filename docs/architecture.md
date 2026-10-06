# Architecture

The four independent jobs a self-hosted media stack does, and which pieces of this repo do each.

## Why

Self-hosting guides introduce twenty tool names at once and present one opinionated stack as a package deal.
Placing each tool in one job makes the stack legible and shows that swapping one piece does not affect the others.

## How it works

| Job | Question | Here |
|---|---|---|
| Access | Who can reach the server, and how? | Tailscale, Caddy, wildcard TLS ([Ingress](ingress.md)) |
| Identity | Who is allowed in once they reach it? | Each app's own login; no SSO ([Ingress](ingress.md)) |
| Serving | How do I watch what I have? | Jellyfin ([Jellyfin](jellyfin.md)) |
| Library | How is it named and organised? | Radarr, Sonarr, Bazarr ([Library managers](library-managers.md)) |

A request passes through each layer in turn:

```
your phone --Tailscale--> Caddy (TS_IP:443) --host matcher--> container:port
```

Tailscale decides who can connect, Caddy who gets which service, the app's own login who gets in.

Around the media stack:

- Operations: [Dashboard](dashboard.md), [Monitoring](monitoring.md), [Notifications](notifications.md), [Backup](backup.md), [Power guard](powerguard.md).
- GPU workloads sharing the 3070: [Local AI](ai.md), [ootd](ootd.md).

## Tech

- See each linked doc.

## Key files

- `compose.yaml`, `stacks/` - every service, grouped by role
- `Caddyfile` - the access layer's routing

## Decisions and gotchas

- **The jobs are independent.** Jellyfin does not care how files are named until Radarr fixes them; Tailscale does not care what sits behind it; swapping one piece leaves the others alone.
- The stack is one Compose project on one laptop; a `hosts/` split is only worth adding when a second machine exists.

## Related

- [Compose layout](compose-layout.md)
- [Rebuild](rebuild.md)
