#!/bin/bash
# Downloads the latest Scrub release and installs Scrub.app into /Applications.
#
# Because this fetches over curl (not a browser), the download carries no Gatekeeper
# quarantine flag — so there's no right-click-to-Open dance. You still grant Accessibility
# permission on first launch so Scrub can lock input (see README).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/NuttapongPun/scrub/main/install.sh | bash
set -euo pipefail

REPO="NuttapongPun/scrub"
APP="Scrub.app"
DEST="${SCRUB_INSTALL_DIR:-/Applications}"

echo "Finding the latest Scrub release…"
# Resolve the latest release's zip asset via the GitHub API.
ASSET_URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*\.zip"' \
    | head -n1 | sed 's/.*"\(https[^"]*\)"/\1/')"

if [ -z "${ASSET_URL:-}" ]; then
    echo "error: could not find a release zip for $REPO." >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $(basename "$ASSET_URL")…"
curl -fsSL "$ASSET_URL" -o "$TMP/scrub.zip"

echo "Unpacking…"
ditto -x -k "$TMP/scrub.zip" "$TMP"

if [ ! -d "$TMP/$APP" ]; then
    echo "error: $APP not found in the downloaded archive." >&2
    exit 1
fi

echo "Installing to $DEST…"
rm -rf "${DEST:?}/$APP"
mv "$TMP/$APP" "$DEST/$APP"
# Clear any quarantine flag just in case, so Gatekeeper won't block the first launch.
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

echo
echo "Installed $DEST/$APP"
echo "Launch it, then grant Accessibility permission when prompted:"
echo "  System Settings → Privacy & Security → Accessibility"
echo
echo "Opening Scrub…"
open "$DEST/$APP" || true
