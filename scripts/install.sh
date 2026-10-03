#!/usr/bin/env bash
# Builds, quits the running copy, replaces /Applications/TallyShot.app and relaunches it.
# Always installing to the same path keeps macOS permission entries pointing at one app.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh
TARGET=/Applications/TallyShot.app

if pkill -x TallyShot; then
  echo "Quit running TallyShot."
  sleep 1
fi
rm -rf "$TARGET"
ditto dist/TallyShot.app "$TARGET"
echo "Installed $TARGET"
codesign -dr - "$TARGET" 2>&1 | grep designated
open "$TARGET"
