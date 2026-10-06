# Jellyfin plugins

Third-party plugins that add external ratings and rule-based lists to Jellyfin.

## Why

Jellyfin shows only TMDb's rating and has no smart playlists.
IMDb, Letterboxd and Metacritic scores, and lists like "unwatched, IMDb above 7.5, pre-1990", make the library browsable by quality.

## How it works

Installed through Dashboard, Plugins, Repositories, then Catalog:

| Repository | Manifest URL |
|---|---|
| SmartLists | `https://raw.githubusercontent.com/jyourstone/jellyfin-plugin-manifest/main/manifest.json` |
| MDBList Ratings | `https://raw.githubusercontent.com/Druidblack/Jellyfin.Plugin.MDBList_Ratings/main/manifest.json` |
| IAmParadox | `https://www.iamparadox.dev/jellyfin/plugins/manifest.json` |

| Plugin | Does |
|---|---|
| MDBList Ratings | IMDb, Letterboxd, Rotten Tomatoes, Metacritic, Trakt ratings |
| File Transformation | Required by MDBList Ratings; rewrites `index.html` in memory |
| SmartLists | Rule-based playlists and collections, re-evaluated every 15 minutes |

**MDBList Ratings** looks items up by TMDb ID and works in two layers:

- Written into metadata: `CommunityRating` and `CriticRating` are overwritten, so the poster star becomes IMDb.
- Rendered in the browser only: the "All ratings" panel comes from the plugin cache via File Transformation.
  Letterboxd, the Certified Fresh badge and Metacritic Must-See appear only here.

The **Update MDBList ratings** scheduled task backfills the library daily at 04:00.

**SmartLists** has its admin page under Dashboard, Plugins; the user page is at `/Plugins/SmartLists/Pages/UserPlaylists` unless the optional Plugin Pages plugin is installed.

## Tech

- MDBList API (free tier: 1000 requests a day, one per item, cached 24h)
- Jellyfin plugin catalog

## Key files

- `data/jellyfin/config/plugins/configurations/` - plugin settings, including the MDBList key
- `data/jellyfin/config/plugins/configurations/MdbListRatings/state.json` - remaining API quota, the quickest proof the key works

## Decisions and gotchas

- **Jellyfin 12 constrains everything.** Most plugin builds still target the 10.11 ABI and will not load; the catalog filters to compatible builds, a sideloaded `.zip` does not.
- **Two defaults silently defeat the key**, and both are changed:
  - `EnableWebAllRatingsFromCache` `false` -> `true`: the "All ratings" panel, the only place Letterboxd appears, is off out of the box.
  - `UpdateOnlyWhenEmpty` `true` -> `false`: TMDb already fills `CommunityRating`, so IMDb would never replace it.
- The MDBList key is not in `.env`: Jellyfin stores plugin config in its own data directory and has no env route into it.
- The bundled TMDb plugin must stay enabled; items that never matched TMDb get no ratings.
- Letterboxd has no public API; MDBList is how every tool gets those numbers.
- `jellyfin_ratings` is a Tampermonkey userscript, not a plugin; its author replaced it with MDBList Ratings.
- Season and episode ratings need Trakt and TMDb credentials and log warnings on every run; harmless.

## Related

- [Jellyfin](jellyfin.md)
