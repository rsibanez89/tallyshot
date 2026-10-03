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

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -subj "/CN=$SIGNING_IDENTITY_NAME" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$WORK/identity.p12" -passout "pass:$P12_PASSWORD"
security import "$WORK/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P "$P12_PASSWORD" -T /usr/bin/codesign
echo "Created \"$SIGNING_IDENTITY_NAME\" in the login keychain."

tccutil reset ScreenCapture local.tallyshot.TallyShot || true
tccutil reset ScreenCapture local.screensum.ScreenSum || true
echo "Cleared old Screen Recording entries. Run ./scripts/install.sh next."
