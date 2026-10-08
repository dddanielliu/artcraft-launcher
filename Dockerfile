# ArtCraft Launcher
#
# Clones each of the open-source "crafting apps" (storytold/<slug> on GitHub),
# builds their browser/WASM builds with Trunk, and serves them all behind one
# tile-based home page via nginx. Each app is fully independent (its own repo,
# its own local-first storage) — this image just gives them one front door.
#
# To add an app: add a line to apps.txt, then add its two COPY lines in the
# final stage below (dist + icon).

FROM rust:1-slim-bookworm AS wasm-builder

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        git \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN rustup target add wasm32-unknown-unknown
RUN cargo install trunk --locked
RUN cargo install wasm-bindgen-cli --locked

WORKDIR /build
COPY apps.txt .

# Clone + build every app's web crate. Shallow clones keep this fast; each
# app builds independently so one app's source has no effect on another's.
RUN set -eux; \
    while IFS='|' read -r slug name category; do \
      [ -z "$slug" ] && continue; \
      echo "=== Building $slug ==="; \
      git clone --depth 1 "https://github.com/storytold/${slug}.git" "${slug}"; \
      ( cd "${slug}/apps/${slug}-web" && trunk build --release ); \
    done < apps.txt

FROM nginx:alpine AS final

COPY launcher/index.html /usr/share/nginx/html/index.html

# --- Per-app static builds ---
COPY --from=wasm-builder /build/photocraft/dist/web   /usr/share/nginx/html/apps/photocraft
COPY --from=wasm-builder /build/vectorcraft/dist/web  /usr/share/nginx/html/apps/vectorcraft
COPY --from=wasm-builder /build/pdfcraft/dist/web     /usr/share/nginx/html/apps/pdfcraft
COPY --from=wasm-builder /build/filmcraft/dist/web    /usr/share/nginx/html/apps/filmcraft
COPY --from=wasm-builder /build/lightcraft/dist/web   /usr/share/nginx/html/apps/lightcraft
COPY --from=wasm-builder /build/effectcraft/dist/web  /usr/share/nginx/html/apps/effectcraft
COPY --from=wasm-builder /build/designcraft/dist/web  /usr/share/nginx/html/apps/designcraft
COPY --from=wasm-builder /build/wordcraft/dist/web    /usr/share/nginx/html/apps/wordcraft
COPY --from=wasm-builder /build/gridcraft/dist/web    /usr/share/nginx/html/apps/gridcraft
COPY --from=wasm-builder /build/deckcraft/dist/web    /usr/share/nginx/html/apps/deckcraft
COPY --from=wasm-builder /build/soundcraft/dist/web   /usr/share/nginx/html/apps/soundcraft
COPY --from=wasm-builder /build/cadcraft/dist/web     /usr/share/nginx/html/apps/cadcraft

# --- Per-app icons (served at /icons/<slug>.png for the tile grid) ---
COPY --from=wasm-builder /build/photocraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.photocraft.png   /usr/share/nginx/html/icons/photocraft.png
COPY --from=wasm-builder /build/vectorcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.vectorcraft.png /usr/share/nginx/html/icons/vectorcraft.png
COPY --from=wasm-builder /build/pdfcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.pdfcraft.png       /usr/share/nginx/html/icons/pdfcraft.png
COPY --from=wasm-builder /build/filmcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.filmcraft.png     /usr/share/nginx/html/icons/filmcraft.png
COPY --from=wasm-builder /build/lightcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.lightcraft.png   /usr/share/nginx/html/icons/lightcraft.png
COPY --from=wasm-builder /build/effectcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.effectcraft.png /usr/share/nginx/html/icons/effectcraft.png
COPY --from=wasm-builder /build/designcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.designcraft.png /usr/share/nginx/html/icons/designcraft.png
COPY --from=wasm-builder /build/wordcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.wordcraft.png     /usr/share/nginx/html/icons/wordcraft.png
COPY --from=wasm-builder /build/gridcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.gridcraft.png     /usr/share/nginx/html/icons/gridcraft.png
COPY --from=wasm-builder /build/deckcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.deckcraft.png     /usr/share/nginx/html/icons/deckcraft.png
COPY --from=wasm-builder /build/soundcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.soundcraft.png   /usr/share/nginx/html/icons/soundcraft.png
COPY --from=wasm-builder /build/cadcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.cadcraft.png       /usr/share/nginx/html/icons/cadcraft.png

EXPOSE 80
