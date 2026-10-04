#!/usr/bin/env bash
# Release builds only. Imports the release signing identity into a temporary keychain
# and puts that keychain on the search list, where codesign looks for identities.
# Environment: CERT_P12 (base64 .p12), CERT_PASSWORD, KEYCHAIN (optional path).
set -euo pipefail

: "${CERT_P12:?CERT_P12 is empty. Set the TALLYSHOT_RELEASE_CERT_P12 secret (scripts/setup-release-signing.sh).}"
: "${CERT_PASSWORD:?CERT_PASSWORD is empty. Set the TALLYSHOT_RELEASE_CERT_PASSWORD secret.}"
TMP="${RUNNER_TEMP:-$(mktemp -d)}"
KEYCHAIN="${KEYCHAIN:-$TMP/release-signing.keychain-db}"
KEYCHAIN_PASSWORD="$(openssl rand -hex 16)"

printf '%s' "$CERT_P12" | base64 --decode > "$TMP/release-signing.p12"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$TMP/release-signing.p12" -k "$KEYCHAIN" -P "$CERT_PASSWORD" -T /usr/bin/codesign
rm -f "$TMP/release-signing.p12"
# Lets codesign use the key without a password prompt.
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" > /dev/null
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
security find-identity -p codesigning "$KEYCHAIN"
