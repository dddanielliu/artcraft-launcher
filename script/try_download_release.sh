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

# Plain grep/sed instead of jq: GitHub's response has occasionally included
# raw control characters inside release notes, which jq's strict parser
# rejects outright ("Invalid string: control characters ... must be
# escaped") even though the asset list itself parses fine. Line-based text
# extraction doesn't care about what's in unrelated fields.
echo "$response" \
  | grep -o '"browser_download_url": *"[^"]*-web-[^"]*\.zip"' \
  | head -n1 \
  | sed -E 's/.*"(https:[^"]+)"$/\1/'
