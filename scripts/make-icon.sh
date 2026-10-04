#!/usr/bin/env bash
# Renders every icon size from scripts/render-icon.swift into Resources/AppIcon/ and the website's docs/.
# Each size is drawn from vectors, not downscaled, so small sizes stay crisp.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=Resources/AppIcon
ICONSET="$(mktemp -d)/AppIcon.iconset"
trap 'rm -rf "$(dirname "$ICONSET")"' EXIT
mkdir -p "$ICONSET" "$OUT"

for points in 16 32 128 256 512; do
  swift scripts/render-icon.swift "$points" "$ICONSET/icon_${points}x${points}.png"
  swift scripts/render-icon.swift "$((points * 2))" "$ICONSET/icon_${points}x${points}@2x.png"
done
iconutil --convert icns --output "$OUT/AppIcon.icns" "$ICONSET"
cp "$ICONSET/icon_512x512@2x.png" "$OUT/AppIcon-1024.png"
cp "$ICONSET/icon_128x128@2x.png" docs/icon.png
cp "$ICONSET/icon_32x32@2x.png" docs/favicon.png
echo "Wrote $OUT/AppIcon.icns, $OUT/AppIcon-1024.png, docs/icon.png and docs/favicon.png"
