#!/usr/bin/env bash
# Builds dist/TallyShot.app, signed with the local certificate from setup-signing.sh when present.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing-identity.sh

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TallyShot"
APP=dist/TallyShot.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TallyShot"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if has_signing_identity; then
  codesign --force --sign "$SIGNING_IDENTITY_NAME" "$APP"
else
  echo "warning: no \"$SIGNING_IDENTITY_NAME\" certificate, signing ad-hoc." >&2
  echo "warning: macOS will ask for Screen Recording again after every rebuild. Run ./scripts/setup-signing.sh once." >&2
  codesign --force --sign - "$APP"
fi
echo "Built $APP"
