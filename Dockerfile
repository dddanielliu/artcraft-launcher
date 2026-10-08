# ArtCraft Launcher
#
# Clones each of the open-source "crafting apps" (storytold/<slug> on GitHub),
# builds their browser/WASM builds with Trunk, and serves them all behind one
# tile-based home page via nginx. Each app is fully independent (its own repo,
# its own local-first storage) — this image just gives them one front door.
#
# Each app gets its own build stage (all FROM `toolchain`, none depending on
# each other), so BuildKit's DAG scheduler builds them concurrently instead of
# one at a time — this is the thing that makes the "multi-stage build" here
# actually parallel, not just multiple stages.
#
# To add an app: add a line to apps.txt, add a `FROM toolchain AS build-<slug>`
# stage below (copy an existing one), then add its two COPY lines in `final`.

FROM rust:1-slim-bookworm AS toolchain

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
# Pinned for filmcraft/lightcraft/effectcraft, which use `cargo xtask web` instead of Trunk
# and check this exact version against their Cargo.lock. Trunk manages its own wasm-bindgen
# fetch per-project regardless, so pinning here doesn't affect the other 9 apps.
RUN cargo install wasm-bindgen-cli --version 0.2.129 --locked

WORKDIR /build

# --- One independent stage per app ---

FROM toolchain AS build-photocraft
RUN git clone --depth 1 https://github.com/storytold/photocraft.git photocraft
RUN cd photocraft/apps/photocraft-web && trunk build --release

FROM toolchain AS build-vectorcraft
RUN git clone --depth 1 https://github.com/storytold/vectorcraft.git vectorcraft
RUN cd vectorcraft/apps/vectorcraft-web && trunk build --release

FROM toolchain AS build-pdfcraft
RUN git clone --depth 1 https://github.com/storytold/pdfcraft.git pdfcraft
RUN cd pdfcraft/apps/pdfcraft-web && trunk build --release

# NB: filmcraft/lightcraft/effectcraft don't use Trunk — they build via a `cargo xtask web`
# command run from the repo root, invoking wasm-bindgen directly.
FROM toolchain AS build-filmcraft
RUN git clone --depth 1 https://github.com/storytold/filmcraft.git filmcraft
RUN cd filmcraft && cargo xtask web

FROM toolchain AS build-lightcraft
RUN git clone --depth 1 https://github.com/storytold/lightcraft.git lightcraft
RUN cd lightcraft && cargo xtask web

FROM toolchain AS build-effectcraft
RUN git clone --depth 1 https://github.com/storytold/effectcraft.git effectcraft
RUN cd effectcraft && cargo xtask web

FROM toolchain AS build-designcraft
RUN git clone --depth 1 https://github.com/storytold/designcraft.git designcraft
RUN cd designcraft/apps/designcraft-web && trunk build --release

FROM toolchain AS build-wordcraft
RUN git clone --depth 1 https://github.com/storytold/wordcraft.git wordcraft
RUN cd wordcraft/apps/wordcraft-web && trunk build --release

FROM toolchain AS build-gridcraft
RUN git clone --depth 1 https://github.com/storytold/gridcraft.git gridcraft
RUN cd gridcraft/apps/gridcraft-web && trunk build --release

FROM toolchain AS build-deckcraft
RUN git clone --depth 1 https://github.com/storytold/deckcraft.git deckcraft
RUN cd deckcraft/apps/deckcraft-web && trunk build --release

FROM toolchain AS build-soundcraft
RUN git clone --depth 1 https://github.com/storytold/soundcraft.git soundcraft
RUN cd soundcraft/apps/soundcraft-web && trunk build --release

FROM toolchain AS build-cadcraft
RUN git clone --depth 1 https://github.com/storytold/cadcraft.git cadcraft
RUN cd cadcraft/apps/cadcraft-web && trunk build --release

# --- Assemble the final image ---

FROM nginx:alpine AS final

COPY launcher/index.html /usr/share/nginx/html/index.html

# Per-app static builds
COPY --from=build-photocraft   /build/photocraft/dist/web   /usr/share/nginx/html/apps/photocraft
COPY --from=build-vectorcraft  /build/vectorcraft/dist/web  /usr/share/nginx/html/apps/vectorcraft
COPY --from=build-pdfcraft     /build/pdfcraft/dist/web     /usr/share/nginx/html/apps/pdfcraft
COPY --from=build-filmcraft    /build/filmcraft/target/web/dist    /usr/share/nginx/html/apps/filmcraft
COPY --from=build-lightcraft   /build/lightcraft/target/web        /usr/share/nginx/html/apps/lightcraft
COPY --from=build-effectcraft  /build/effectcraft/target/web/dist  /usr/share/nginx/html/apps/effectcraft
COPY --from=build-designcraft  /build/designcraft/dist/web  /usr/share/nginx/html/apps/designcraft
COPY --from=build-wordcraft    /build/wordcraft/dist/web    /usr/share/nginx/html/apps/wordcraft
COPY --from=build-gridcraft    /build/gridcraft/dist/web    /usr/share/nginx/html/apps/gridcraft
COPY --from=build-deckcraft    /build/deckcraft/dist/web    /usr/share/nginx/html/apps/deckcraft
COPY --from=build-soundcraft   /build/soundcraft/dist/web   /usr/share/nginx/html/apps/soundcraft
COPY --from=build-cadcraft     /build/cadcraft/dist/web     /usr/share/nginx/html/apps/cadcraft

# Per-app icons (served at /icons/<slug>.png for the tile grid)
COPY --from=build-photocraft   /build/photocraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.photocraft.png     /usr/share/nginx/html/icons/photocraft.png
COPY --from=build-vectorcraft  /build/vectorcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.vectorcraft.png   /usr/share/nginx/html/icons/vectorcraft.png
COPY --from=build-pdfcraft     /build/pdfcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.pdfcraft.png         /usr/share/nginx/html/icons/pdfcraft.png
COPY --from=build-filmcraft    /build/filmcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.filmcraft.png       /usr/share/nginx/html/icons/filmcraft.png
COPY --from=build-lightcraft   /build/lightcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.lightcraft.png     /usr/share/nginx/html/icons/lightcraft.png
COPY --from=build-effectcraft  /build/effectcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.effectcraft.png   /usr/share/nginx/html/icons/effectcraft.png
COPY --from=build-designcraft  /build/designcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.designcraft.png   /usr/share/nginx/html/icons/designcraft.png
COPY --from=build-wordcraft    /build/wordcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.wordcraft.png       /usr/share/nginx/html/icons/wordcraft.png
COPY --from=build-gridcraft    /build/gridcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.gridcraft.png       /usr/share/nginx/html/icons/gridcraft.png
COPY --from=build-deckcraft    /build/deckcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.deckcraft.png       /usr/share/nginx/html/icons/deckcraft.png
COPY --from=build-soundcraft   /build/soundcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.soundcraft.png     /usr/share/nginx/html/icons/soundcraft.png
COPY --from=build-cadcraft     /build/cadcraft/assets/app-icon/hicolor/128x128/apps/ai.storyteller.cadcraft.png         /usr/share/nginx/html/icons/cadcraft.png

EXPOSE 80
