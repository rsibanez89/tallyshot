#!/usr/bin/env bash
# One-time setup. Creates a self-signed code signing certificate in the login keychain,
# then clears TallyShot's old Screen Recording entries, which belonged to ad-hoc builds.
# The certificate never leaves this Mac and is only trusted for signing TallyShot builds.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing-identity.sh

if has_signing_identity; then
  echo "\"$SIGNING_IDENTITY_NAME\" already exists in the login keychain. Nothing to do."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
P12_PASSWORD="$(openssl rand -hex 16)"
make_signing_p12 "$SIGNING_IDENTITY_NAME" "$WORK/identity.p12" "$P12_PASSWORD"
security import "$WORK/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P "$P12_PASSWORD" -T /usr/bin/codesign
echo "Created \"$SIGNING_IDENTITY_NAME\" in the login keychain."

tccutil reset ScreenCapture local.tallyshot.TallyShot || true
tccutil reset ScreenCapture local.screensum.ScreenSum || true
echo "Cleared old Screen Recording entries. Run ./scripts/install.sh next."
