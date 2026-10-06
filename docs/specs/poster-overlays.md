# Poster overlays

**Status:** draft

Rating badges burned onto Jellyfin poster artwork by Kometa, visible in every client including the Apple TV app.

## Goal

The MDBList plugin decorates only the details page in a browser; native clients show plain posters.
Done when library posters show IMDb and Rotten Tomatoes badges in Swiftfin and the web UI.

## Scope

- In: Kometa as a scheduled container, overlay config for movies (and TV once there is a TV library).
- Out: StarTrack's social layer (reviews, diary, watchlists); collections, which SmartLists already covers.

## Design

- Kometa runs on a schedule (nightly), talks to Jellyfin at `jellyfin:8096` with an API key, reads ratings via MDBList.
- Config under `config/kometa/`, versioned; state under `data/kometa/`.
- Kometa keeps original artwork so overlays can be removed; confirm that before the first run.
- See [Jellyfin plugins](../jellyfin-plugins.md) for where ratings come from today.

## Tasks

- [ ] Confirm Kometa's Jellyfin support covers overlays on the current Jellyfin version.
- [ ] Add the pinned service to a stack, plus Diun.
- [ ] Write the overlay config; dry-run on a test library.
- [ ] Run on the real library.

## Done when

- [ ] Badges appear in Swiftfin and the web UI.
- [ ] Removing the overlays restores the originals.
- [ ] A `docs/kometa.md` exists, this spec is deleted and removed from `roadmap.md` and `AGENTS.md`.

## Open questions

- Does Kometa support Jellyfin well enough yet? Default: verify first; drop the spec if not.

## Related

- [Jellyfin plugins](../jellyfin-plugins.md)
