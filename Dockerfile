# ArtCraft Launcher
#
# Clones each of the open-source "crafting apps" (storytold/<slug> on GitHub)
# and serves their browser/WASM builds behind one tile-based home page via
# nginx. Each app is fully independent (its own repo, its own local-first
# storage) — this image just gives them one front door.
#
# Each app's stage first tries to grab the prebuilt `*-web-*.zip` asset off
# its latest GitHub release via plain `curl` against the public,
# unauthenticated GitHub API (no token needed for public repos — this is NOT
# `gh`, which requires one). Only if no such asset exists does it fall back
# to building from source with Trunk (or `cargo xtask web` for the three apps
# that don't use Trunk: filmcraft, lightcraft, effectcraft). The fallback
# path is what used to always run — it's slow and, at 12-way concurrency,
# can OOM even a well-resourced machine — so it's a last resort now, not the
# default.
#
# All 12 stages are independent (none depend on each other), so BuildKit
# builds them concurrently. That's safe now since the common case is just a
# handful of HTTP requests per app, not a Rust compile.
#
# To add an app: add a line to apps.txt, copy one of the `FROM toolchain AS
# build-<slug>` stages below (trunk-style or xtask-style, matching how that
# app actually builds), then add its two COPY lines in `final`.

FROM rust:1-slim-bookworm AS toolchain

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        git \
        curl \
        unzip \
        jq \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN rustup target add wasm32-unknown-unknown
RUN cargo install trunk --locked
# Pinned for filmcraft/lightcraft/effectcraft's fallback build, which uses
# `cargo xtask web` instead of Trunk and checks this exact version against
# their Cargo.lock. Trunk manages its own wasm-bindgen fetch per-project
# regardless, so pinning here doesn't affect the other 9 apps' fallback.
RUN cargo install wasm-bindgen-cli --version 0.2.129 --locked

WORKDIR /build

# Fetches the prebuilt web zip from the latest GitHub release, if one exists.
# Prints the download URL on success, or nothing (and nothing to stderr) if
# there's no matching asset, so the caller can fall back to a source build.
COPY script/try_download_release.sh /usr/local/bin/try_download_release.sh
RUN chmod +x /usr/local/bin/try_download_release.sh

# --- One independent stage per app ---

FROM toolchain AS build-photocraft
RUN set -eux; \
    url=$(try_download_release.sh photocraft); \
    if [ -n "$url" ]; then \
      echo "[photocraft] using prebuilt release: $url"; \
      mkdir -p dist/photocraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/photocraft/; \
    else \
      echo "[photocraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/photocraft.git photocraft && \
      (cd photocraft/apps/photocraft-web && trunk build --release) && \
      mkdir -p dist/photocraft && cp -r photocraft/dist/web/. dist/photocraft/; \
    fi

FROM toolchain AS build-vectorcraft
RUN set -eux; \
    url=$(try_download_release.sh vectorcraft); \
    if [ -n "$url" ]; then \
      echo "[vectorcraft] using prebuilt release: $url"; \
      mkdir -p dist/vectorcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/vectorcraft/; \
    else \
      echo "[vectorcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/vectorcraft.git vectorcraft && \
      (cd vectorcraft/apps/vectorcraft-web && trunk build --release) && \
      mkdir -p dist/vectorcraft && cp -r vectorcraft/dist/web/. dist/vectorcraft/; \
    fi

FROM toolchain AS build-pdfcraft
RUN set -eux; \
    url=$(try_download_release.sh pdfcraft); \
    if [ -n "$url" ]; then \
      echo "[pdfcraft] using prebuilt release: $url"; \
      mkdir -p dist/pdfcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/pdfcraft/; \
    else \
      echo "[pdfcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/pdfcraft.git pdfcraft && \
      (cd pdfcraft/apps/pdfcraft-web && trunk build --release) && \
      mkdir -p dist/pdfcraft && cp -r pdfcraft/dist/web/. dist/pdfcraft/; \
    fi

# NB: filmcraft/lightcraft/effectcraft's fallback doesn't use Trunk — they build via a
# `cargo xtask web` command run from the repo root, invoking wasm-bindgen directly.
FROM toolchain AS build-filmcraft
RUN set -eux; \
    url=$(try_download_release.sh filmcraft); \
    if [ -n "$url" ]; then \
      echo "[filmcraft] using prebuilt release: $url"; \
      mkdir -p dist/filmcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/filmcraft/; \
    else \
      echo "[filmcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/filmcraft.git filmcraft && \
      cd filmcraft && cargo xtask web && mkdir -p ../dist/filmcraft && cp -r target/web/dist/. ../dist/filmcraft/; \
    fi

FROM toolchain AS build-lightcraft
RUN set -eux; \
    url=$(try_download_release.sh lightcraft); \
    if [ -n "$url" ]; then \
      echo "[lightcraft] using prebuilt release: $url"; \
      mkdir -p dist/lightcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/lightcraft/; \
    else \
      echo "[lightcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/lightcraft.git lightcraft && \
      cd lightcraft && cargo xtask web && mkdir -p ../dist/lightcraft && cp -r target/web/. ../dist/lightcraft/; \
    fi

FROM toolchain AS build-effectcraft
RUN set -eux; \
    url=$(try_download_release.sh effectcraft); \
    if [ -n "$url" ]; then \
      echo "[effectcraft] using prebuilt release: $url"; \
      mkdir -p dist/effectcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/effectcraft/; \
    else \
      echo "[effectcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/effectcraft.git effectcraft && \
      cd effectcraft && cargo xtask web && mkdir -p ../dist/effectcraft && cp -r target/web/dist/. ../dist/effectcraft/; \
    fi

FROM toolchain AS build-designcraft
RUN set -eux; \
    url=$(try_download_release.sh designcraft); \
    if [ -n "$url" ]; then \
      echo "[designcraft] using prebuilt release: $url"; \
      mkdir -p dist/designcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/designcraft/; \
    else \
      echo "[designcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/designcraft.git designcraft && \
      (cd designcraft/apps/designcraft-web && trunk build --release) && \
      mkdir -p dist/designcraft && cp -r designcraft/dist/web/. dist/designcraft/; \
    fi

FROM toolchain AS build-wordcraft
RUN set -eux; \
    url=$(try_download_release.sh wordcraft); \
    if [ -n "$url" ]; then \
      echo "[wordcraft] using prebuilt release: $url"; \
      mkdir -p dist/wordcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/wordcraft/; \
    else \
      echo "[wordcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/wordcraft.git wordcraft && \
      (cd wordcraft/apps/wordcraft-web && trunk build --release) && \
      mkdir -p dist/wordcraft && cp -r wordcraft/dist/web/. dist/wordcraft/; \
    fi

FROM toolchain AS build-gridcraft
RUN set -eux; \
    url=$(try_download_release.sh gridcraft); \
    if [ -n "$url" ]; then \
      echo "[gridcraft] using prebuilt release: $url"; \
      mkdir -p dist/gridcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/gridcraft/; \
    else \
      echo "[gridcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/gridcraft.git gridcraft && \
      (cd gridcraft/apps/gridcraft-web && trunk build --release) && \
      mkdir -p dist/gridcraft && cp -r gridcraft/dist/web/. dist/gridcraft/; \
    fi

FROM toolchain AS build-deckcraft
RUN set -eux; \
    url=$(try_download_release.sh deckcraft); \
    if [ -n "$url" ]; then \
      echo "[deckcraft] using prebuilt release: $url"; \
      mkdir -p dist/deckcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/deckcraft/; \
    else \
      echo "[deckcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/deckcraft.git deckcraft && \
      (cd deckcraft/apps/deckcraft-web && trunk build --release) && \
      mkdir -p dist/deckcraft && cp -r deckcraft/dist/web/. dist/deckcraft/; \
    fi

FROM toolchain AS build-soundcraft
RUN set -eux; \
    url=$(try_download_release.sh soundcraft); \
    if [ -n "$url" ]; then \
      echo "[soundcraft] using prebuilt release: $url"; \
      mkdir -p dist/soundcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/soundcraft/; \
    else \
      echo "[soundcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/soundcraft.git soundcraft && \
      (cd soundcraft/apps/soundcraft-web && trunk build --release) && \
      mkdir -p dist/soundcraft && cp -r soundcraft/dist/web/. dist/soundcraft/; \
    fi

FROM toolchain AS build-cadcraft
RUN set -eux; \
    url=$(try_download_release.sh cadcraft); \
    if [ -n "$url" ]; then \
      echo "[cadcraft] using prebuilt release: $url"; \
      mkdir -p dist/cadcraft && curl -fsSL -o /tmp/web.zip "$url" && unzip -q /tmp/web.zip -d /tmp/extract && mv /tmp/extract/*/* dist/cadcraft/; \
    else \
      echo "[cadcraft] no prebuilt release found; building from source"; \
      git clone --depth 1 https://github.com/storytold/cadcraft.git cadcraft && \
      (cd cadcraft/apps/cadcraft-web && trunk build --release) && \
      mkdir -p dist/cadcraft && cp -r cadcraft/dist/web/. dist/cadcraft/; \
    fi

# --- Assemble the final image ---

FROM nginx:alpine AS final

RUN apk add --no-cache curl

COPY launcher/index.html /usr/share/nginx/html/index.html

RUN curl -fsSL -o /usr/share/nginx/html/favicon.png \
      "https://avatars.githubusercontent.com/u/76897702?s=200&v=4"

# Per-app static builds. The fallback (source-build) paths land at
# <slug>/dist/web; the curl path lands at dist/<slug> directly — both stages
# normalize to dist/<slug> for the trunk-style apps. The three xtask apps
# normalize to dist/<slug> too (see their RUN commands above).
COPY --from=build-photocraft   /build/dist/photocraft   /usr/share/nginx/html/apps/photocraft
COPY --from=build-vectorcraft  /build/dist/vectorcraft  /usr/share/nginx/html/apps/vectorcraft
COPY --from=build-pdfcraft     /build/dist/pdfcraft     /usr/share/nginx/html/apps/pdfcraft
COPY --from=build-filmcraft    /build/dist/filmcraft    /usr/share/nginx/html/apps/filmcraft
COPY --from=build-lightcraft   /build/dist/lightcraft   /usr/share/nginx/html/apps/lightcraft
COPY --from=build-effectcraft  /build/dist/effectcraft  /usr/share/nginx/html/apps/effectcraft
COPY --from=build-designcraft  /build/dist/designcraft  /usr/share/nginx/html/apps/designcraft
COPY --from=build-wordcraft    /build/dist/wordcraft    /usr/share/nginx/html/apps/wordcraft
COPY --from=build-gridcraft    /build/dist/gridcraft    /usr/share/nginx/html/apps/gridcraft
COPY --from=build-deckcraft    /build/dist/deckcraft    /usr/share/nginx/html/apps/deckcraft
COPY --from=build-soundcraft   /build/dist/soundcraft   /usr/share/nginx/html/apps/soundcraft
COPY --from=build-cadcraft     /build/dist/cadcraft     /usr/share/nginx/html/apps/cadcraft

# Generic "leave site?" warning, injected into every app's index.html (not the
# launcher's own home page). See launcher/beforeunload.html for why this is
# unconditional rather than tied to real unsaved-changes state.
COPY launcher/beforeunload.html /tmp/beforeunload.html
RUN set -eux; \
    for slug in photocraft vectorcraft pdfcraft filmcraft lightcraft effectcraft designcraft wordcraft gridcraft deckcraft soundcraft cadcraft; do \
      f="/usr/share/nginx/html/apps/${slug}/index.html"; \
      awk '/<\/head>/{while((getline line < "/tmp/beforeunload.html") > 0) print line; close("/tmp/beforeunload.html")} {print}' "$f" > /tmp/out.html; \
      mv /tmp/out.html "$f"; \
    done

# Per-app icons (served at /icons/<slug>.png for the tile grid). Fetched directly
# from each repo's main branch — independent of which build path that app took.
RUN set -eux; \
    mkdir -p /usr/share/nginx/html/icons; \
    for slug in photocraft vectorcraft pdfcraft filmcraft lightcraft effectcraft designcraft wordcraft gridcraft deckcraft soundcraft cadcraft; do \
      curl -fsSL -o "/usr/share/nginx/html/icons/${slug}.png" \
        "https://raw.githubusercontent.com/storytold/${slug}/main/assets/app-icon/hicolor/128x128/apps/ai.storyteller.${slug}.png"; \
    done

EXPOSE 80
