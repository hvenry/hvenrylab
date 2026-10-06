# Jellyfin

The media server at `jellyfin.hvenry.com`: scans the library, fetches metadata, and streams to clients, transcoding on the GPU when a client cannot play the original.

## Why

Jellyfin is free, has no account system outside this server, and includes hardware transcoding with no paid tier.
NVENC lets the laptop transcode several streams while barely touching the CPU.
Plex has better TV apps but routes auth through Plex's servers and paywalls hardware transcoding; Emby is the closed-source project Jellyfin forked from.

## How it works

- Libraries use container paths: Movies `/media/movies`, Shows `/media/tv`, Music `/media/music`, each with real-time monitoring on.
- The server is `hvenrylab`, admin user `hvenry`.
- Remote connections are allowed (that is how the tailnet reaches it); automatic port mapping is off, since it is UPnP asking the router to open a port.
- Transcoding, under Dashboard, Playback, Transcoding, with **NVIDIA NVENC**:

| Setting | Value for this Ampere GPU |
|---|---|
| Decode | H264, HEVC, VP8, VP9, AV1, HEVC 10bit, VP9 10bit |
| Decode, off | MPEG2, MPEG4, VC1 (GPU worse than CPU); HEVC RExt (unsupported) |
| Hardware encoding | On |
| Encode AV1 | Off: Ampere decodes AV1 but cannot encode it |
| Encode HEVC | Off for browsers, which cannot decode it; on for native clients such as Apple TV, which halve the bitrate |
| Tone mapping | On, defaults |

On play, Jellyfin picks the cheapest path the client allows:

- **Direct play:** the client handles the file as-is.
- **Direct stream:** only the container or audio is converted; video passes through, so stuttering here is the client failing to decode.
- **Transcode:** video is re-encoded live, triggered by an unsupported codec, unsupported audio (7.1 TrueHD on a phone), burned-in subtitles, or bandwidth.

Read what Jellyfin chose for the current stream:

```bash
docker exec jellyfin nvidia-smi                                         # ffmpeg listed = GPU transcode
docker logs jellyfin --tail=50 | grep -oE '\-codec:v:0 [a-z0-9_]+'
```

`copy` is a direct stream, `h264_nvenc`/`hevc_nvenc` a hardware transcode, `libx264` a software fallback (hardware acceleration broken).

Files are added over Tailscale with `rsync -avP "<Title> (<Year>)" hvenrylab:/srv/media/library/movies/`.
Naming follows Jellyfin's conventions, `Title (Year)/Title (Year).mkv` and `Show/Season 01/Show S01E01.mkv`.

## Tech

- Jellyfin (`jellyfin/jellyfin`), NVENC/NVDEC via the NVIDIA Container Toolkit

## Key files

- `stacks/media.yaml` - service, GPU reservation, read-only `/media` mount
- `data/jellyfin/config/` - server config, watch history, plugin config
- `data/jellyfin/cache/` - transcode and image cache, excluded from backups

## Decisions and gotchas

- **GPU generation matters more than GPU power**: the video engine decides which codecs work. Ampere decodes AV1 but cannot encode it or decode HEVC RExt (both Ada features).
  Enabling a codec the GPU cannot handle breaks playback instead of falling back to CPU.
- `.mkv`/`.mp4` are containers; the codecs inside (H.264, HEVC, AV1) decide playability. MKV is preferred for multiple audio and subtitle tracks.
- Image-based subtitles (PGS from Blu-ray) are burned in and force a full transcode on any client; SRT text subtitles cost nothing, which is one reason [Bazarr](library-managers.md) runs.
- No `ffmpeg` in `nvidia-smi` during playback means either direct play (ideal) or a silent CPU fallback; pick a quality below the source to force a transcode when testing.
- The GPU is shared with Ollama and ootd-worker; an NVENC transcode needs ~0.3 GB of the 8 GB (see [Local AI](ai.md)).
- `JELLYFIN_PublishedServerUrl` is the public HTTPS name, so clients that discover the server get a URL that works.

## Related

- [Jellyfin plugins](jellyfin-plugins.md)
- [Storage](storage.md)
- [Architecture](architecture.md)
