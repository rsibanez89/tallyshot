#!/usr/bin/env bash
# One-time setup. Creates the "TallyShot Release Signing" identity used by the release workflow,
# stores it in the repo's GitHub Actions secrets, and keeps a backup in ~/.tallyshot/.
# Keep the backup: a new release certificate makes every user grant Screen Recording again.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing-identity.sh

NAME="TallyShot Release Signing"
BACKUP="$HOME/.tallyshot"
if [[ -e "$BACKUP/release-signing.p12" ]]; then
  echo "error: $BACKUP/release-signing.p12 already exists. Delete it first to rotate the certificate." >&2
  exit 1
fi

mkdir -p "$BACKUP"
chmod 700 "$BACKUP"
PASSWORD="$(openssl rand -hex 24)"
make_signing_p12 "$NAME" "$BACKUP/release-signing.p12" "$PASSWORD"
printf '%s\n' "$PASSWORD" > "$BACKUP/release-signing.password"
chmod 600 "$BACKUP/release-signing.p12" "$BACKUP/release-signing.password"

base64 -i "$BACKUP/release-signing.p12" | gh secret set TALLYSHOT_RELEASE_CERT_P12
printf '%s' "$PASSWORD" | gh secret set TALLYSHOT_RELEASE_CERT_PASSWORD
echo "Stored \"$NAME\" in GitHub secrets TALLYSHOT_RELEASE_CERT_P12 and TALLYSHOT_RELEASE_CERT_PASSWORD."
echo "Backup: $BACKUP/release-signing.p12 and .password. Move them to a password manager."
