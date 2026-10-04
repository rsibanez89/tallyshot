#!/usr/bin/env bash
# Builds dist/TallyShot.app, signed with $SIGNING_IDENTITY_NAME when present.
# Optional environment:
#   VERSION=v1.2.3 or 1.2.3   sets CFBundleShortVersionString (default: Info.plist's value)
#   BUILD_NUMBER=42           sets CFBundleVersion
#   REQUIRE_SIGNING=1         fails instead of falling back to ad-hoc signing (releases)
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing-identity.sh

if [[ "${REQUIRE_SIGNING:-}" == 1 ]] && ! has_signing_identity; then
  echo "error: REQUIRE_SIGNING=1 but no \"$SIGNING_IDENTITY_NAME\" certificate is available." >&2
  exit 1
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TallyShot"
APP=dist/TallyShot.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TallyShot"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [[ -n "${VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "${VERSION#v}" "$APP/Contents/Info.plist"
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
fi

if has_signing_identity; then
  codesign --force --sign "$SIGNING_IDENTITY_NAME" "$APP"
else
  echo "warning: no \"$SIGNING_IDENTITY_NAME\" certificate, signing ad-hoc." >&2
  echo "warning: macOS will ask for Screen Recording again after every rebuild. Run ./scripts/setup-signing.sh once." >&2
  codesign --force --sign - "$APP"
fi
echo "Built $APP $(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist") ($(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist"))"
