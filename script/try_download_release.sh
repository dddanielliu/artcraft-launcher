#!/bin/sh
# Prints the browser_download_url of the "*-web-*.zip" asset on a
# storytold/<slug> repo's latest GitHub release, or nothing if there isn't
# one. Uses the public, unauthenticated GitHub REST API — no token needed
# for public repos (unlike `gh`, which requires one).
set -eu

slug="$1"
api_url="https://api.github.com/repos/storytold/${slug}/releases/latest"

# Don't let `set -e` kill the build on a network hiccup or missing release —
# the caller treats an empty result as "fall back to a source build".
response=$(curl -fsSL "$api_url" 2>/dev/null) || { echo ""; exit 0; }

echo "$response" | jq -r '.assets[]? | select(.name | test("-web-.*\\.zip$")) | .browser_download_url' | head -n1
