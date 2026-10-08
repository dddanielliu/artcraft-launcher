# ArtCraft Launcher

An unofficial, M365-style home screen for the open-source [ArtCraft](https://getartcraft.com)
"crafting apps" — PhotoCraft, VectorCraft, PdfCraft, FilmCraft, LightCraft, EffectCraft,
DesignCraft, WordCraft, GridCraft, DeckCraft, SoundCraft and CadCraft.

Each app is independently maintained in its own `storytold/<slug>` repo and already ships a
browser/WASM build (`apps/<slug>-web`, built with [Trunk](https://trunkrs.dev)). This repo
doesn't change any of them — it just clones each one at build time, compiles its web build,
and serves all twelve behind a single tile-based home page via nginx.

Each app is fully independent: local-first storage (browser OPFS/IndexedDB), no account, no
sync between apps. This is purely a shared front door, not a shared workspace.

## Run it

```bash
docker compose up --build
```

Then open <http://localhost:8080>.

The first build compiles 12 Rust/WASM apps from source, so it's slow (expect it to take a
while) — subsequent builds reuse Docker's layer cache unless `apps.txt` or the Dockerfile
changes.

## Adding an app

1. Add a `slug|Name|Category` line to `apps.txt`.
2. Add the two matching `COPY --from=wasm-builder` lines in the `Dockerfile` (dist + icon).
3. Add the matching entry to the `apps` array in `launcher/index.html`.
