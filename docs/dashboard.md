# Dashboard

Homepage at `lab.hvenry.com`: a link to every service with live up/down status and a few API widgets.

## Why

Twenty services need one front door that shows what is running without opening each one.
It has to do that without the Docker socket, which every Homepage guide mounts by default.

## How it works

- Services are listed in `homepage/services.yaml`, grouped Watch, Library, Apps, Monitoring.
- `href` is where you click through to, the public `https://<name>.hvenry.com`.
- `siteMonitor` is where Homepage checks status from, always the internal `http://container:port`, so status is accurate from any device.
- API keys are substituted from `.env` through `HOMEPAGE_VAR_*` env vars into `{{HOMEPAGE_VAR_*}}` placeholders, so nothing secret is committed.
- `${MEDIA_DIR}` is mounted read-only at `/srv/media` only so the resources widget can report free space.

Get the *arr keys for `.env`:

```bash
for a in radarr sonarr; do grep -oP '(?<=<ApiKey>)[^<]+' data/$a/config.xml; done
```

## Tech

- Homepage (`ghcr.io/gethomepage/homepage`)

## Key files

- `homepage/services.yaml` - service tiles and widgets
- `homepage/settings.yaml`, `widgets.yaml`, `custom.css`, `custom.js` - layout and styling
- `stacks/platform.yaml` - `HOMEPAGE_ALLOWED_HOSTS` and the `HOMEPAGE_VAR_*` mapping

## Decisions and gotchas

- **No Docker socket.** Even `:ro` it grants full control of the daemon; `siteMonitor` HTTP checks give the same up/down without it.
- `HOMEPAGE_ALLOWED_HOSTS` is read at container start, so adding a name needs a recreate, not a restart.
- Do not monitor `http://homepage:3000` from Uptime Kuma: the allowed-hosts check rejects that Host header with a 400.
- The Jellyfin widget is blocked upstream: Homepage calls `/emby/...?api_key=`, and Jellyfin 12 removed both the `/emby` prefix and query-param auth.
  `JELLYFIN_API_KEY` is already wired for when Homepage catches up.
- Glances is a service tile, not an info widget: the info widget always renders a second resource block that duplicates the RAM readout.
- The ootd tile monitors `ootd-dev:3000`, the dev server currently serving the site; point it back at `ootd:3000` with the Caddyfile (see [ootd](ootd.md)).

## Related

- [Ingress](ingress.md)
- [Monitoring](monitoring.md)
