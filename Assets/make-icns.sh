#!/bin/bash
# Generates Assets/AppIcon.icns from the 1024×1024 master Assets/AppIcon.png.
# Run after editing the master; build.sh copies the resulting .icns into the bundle.
set -euo pipefail

cd "$(dirname "$0")"

MASTER="AppIcon.png"
SET="AppIcon.iconset"
OUT="AppIcon.icns"

rm -rf "$SET"
mkdir -p "$SET"

sips -z 16 16     "$MASTER" --out "$SET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$MASTER" --out "$SET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$MASTER" --out "$SET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$MASTER" --out "$SET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$MASTER" --out "$SET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$MASTER" --out "$SET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$MASTER" --out "$SET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$MASTER" --out "$SET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$MASTER" --out "$SET/icon_512x512.png"    >/dev/null
cp                "$MASTER"        "$SET/icon_512x512@2x.png"

iconutil -c icns "$SET" -o "$OUT"
rm -rf "$SET"
echo "Built $OUT"
