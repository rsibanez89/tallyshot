#!/usr/bin/env bash
# Packs dist/TallyShot.app into dist/TallyShot.dmg with an Applications shortcut,
# so users drag the app into /Applications instead of running it from Downloads.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=dist/TallyShot.app
DMG=dist/TallyShot.dmg
[[ -d "$APP" ]] || { echo "error: $APP not found. Run ./scripts/build-app.sh first." >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/TallyShot.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -quiet -volname TallyShot -srcfolder "$STAGE" -fs HFS+ -format UDZO "$DMG"
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
