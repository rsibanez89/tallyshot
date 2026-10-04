#!/usr/bin/env bash
# TallyShot installer.
#   curl -fsSL https://rsibanez89.github.io/tallyshot/install.sh | bash
#
# Downloads the latest TallyShot.dmg from GitHub Releases, copies TallyShot.app
# into /Applications (or ~/Applications if /Applications is not writable), and opens it.
# Files downloaded with curl are not quarantined, so macOS does not show the
# "Apple could not verify" dialog that browser downloads get.
#
# Optional environment, used for testing:
#   INSTALL_DIR=/some/dir   install there instead
#   TALLYSHOT_NO_OPEN=1     do not open the app afterwards
set -euo pipefail

URL="https://github.com/rsibanez89/tallyshot/releases/latest/download/TallyShot.dmg"

fail() { echo "TallyShot install failed: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "TallyShot runs on macOS only."
[[ "$(uname -m)" == "arm64" ]] || fail "this build needs a Mac with Apple silicon."
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
(( MACOS_MAJOR >= 14 )) || fail "macOS 14 Sonoma or later is required."

if [[ -n "${INSTALL_DIR:-}" ]]; then
  DEST_DIR="$INSTALL_DIR"
elif [[ -w /Applications ]]; then
  DEST_DIR=/Applications
else
  DEST_DIR="$HOME/Applications"
fi
mkdir -p "$DEST_DIR"
DEST="$DEST_DIR/TallyShot.app"

WORK="$(mktemp -d)"
MOUNT="$WORK/mount"
cleanup() {
  hdiutil detach -quiet "$MOUNT" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "Downloading TallyShot..."
curl -fL --progress-bar -o "$WORK/TallyShot.dmg" "$URL" || fail "could not download $URL"

hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT" "$WORK/TallyShot.dmg" \
  || fail "could not open the downloaded disk image."
[[ -d "$MOUNT/TallyShot.app" ]] || fail "the disk image does not contain TallyShot.app."

# Quit only the copy being replaced, so an update can overwrite it.
if pgrep -f "$DEST/Contents/MacOS/TallyShot" > /dev/null; then
  echo "Quitting the running TallyShot..."
  pkill -f "$DEST/Contents/MacOS/TallyShot" || true
  sleep 1
fi

rm -rf "$DEST"
ditto "$MOUNT/TallyShot.app" "$DEST"
echo "Installed $DEST"

if [[ "${TALLYSHOT_NO_OPEN:-}" != 1 ]]; then
  open "$DEST"
  echo "TallyShot is in your menu bar. Press Cmd+Shift+6 and drag over a table."
  echo "The first time, allow Screen Recording when asked, then quit and reopen TallyShot."
fi
