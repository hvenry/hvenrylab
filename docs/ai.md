# Local AI

Ollama for local inference, and clear-rag at `rag.hvenry.com` answering questions from this repository's own docs.

## Why

"How do I restore the ootd database?" should be answerable from a phone, with a citation, without a hosted model.
clear-rag answers only from indexed documents and refuses otherwise, so its corpus here is the homelab docs themselves.
It is deliberately not a chat app; for open-ended chat, point something else at the same Ollama.

## How it works

- `ollama` serves `qwen2.5:7b` (chat) and `nomic-embed-text` (embeddings) on the GPU.
- `clear-rag` talks to `http://ollama:11434` over the compose network and keeps its workspace in `data/clear-rag`.
- Documents go in over the API (`POST /api/documents`), from the web UI or a phone; there is no path-based ingest.

Re-seed the corpus after changing docs; `DELETE /api/documents` empties the index first, so renamed or deleted docs do not linger:

```bash
cd ~/homelab
curl -sS -X DELETE http://127.0.0.1:8010/api/documents
args=(); for f in README.md AGENTS.md docs/*.md; do args+=(-F "files=@$f"); done
curl -sS -X POST "${args[@]}" http://127.0.0.1:8010/api/documents
```

Build and deploy a new clear-rag image:

```bash
docker build -t clear-rag:<tag> --target slim ~/dev/clear-rag   # then bump the tag in stacks/ai.yaml
docker compose up -d clear-rag
```

## Tech

- Ollama, clear-rag (built locally from `~/dev/clear-rag`)
- `qwen2.5:7b`, `nomic-embed-text`

## Key files

- `stacks/ai.yaml` - both services and the VRAM-related settings
- `data/ollama/` - model weights, excluded from backups
- `data/clear-rag/` - corpus and index; `vectors.npy` is excluded from backups and re-indexes

## Decisions and gotchas

- **Use a 7B model.** `llama3.2` (3B) answered with a bare citation marker (`[3]`) under the grounded prompt while retrieval was healthy (5 chunks, 54% of budget); `qwen2.5:7b` answers and still refuses out-of-corpus questions.
- VRAM on the shared 8 GB: `qwen2.5:7b` 5.1 GB plus embedder 0.3 GB, leaving ~2.5 GB for Jellyfin and ootd-worker.
- `OLLAMA_MAX_LOADED_MODELS=2`: every query embeds before it generates, so a limit of 1 thrashes the chat model in and out.
- `CLEARRAG_KEEP_ALIVE=2m` and `CLEARRAG_PRELOAD=false` (upstream 30m and true): the GPU is shared, and idle VRAM is idle draw on battery.
- `CLEARRAG_NUM_CTX=8192`: below that Ollama silently truncates the instructions out of the prompt.
- `CLEARRAG_OLLAMA_URL` overrides upstream's `host.docker.internal`, which exists only because Docker on macOS has no GPU.
- **No authentication**: every write endpoint is open to the tailnet; auth belongs in the app, not as `basic_auth` in Caddy.
  The corpus is re-seedable in one command, so the worst case is inconvenience.
- Diun cannot watch the local `clear-rag` tag; `ollama/ollama` is watched normally.

## Related

- [ootd](ootd.md)
- [Jellyfin](jellyfin.md)
- [Maintenance](maintenance.md)
