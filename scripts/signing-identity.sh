# Sourced by the other scripts.
# A stable certificate keeps the Screen Recording grant across rebuilds; ad-hoc signatures do not.
# Local builds use "TallyShot Local Signing" (setup-signing.sh).
# Releases set SIGNING_IDENTITY_NAME to "TallyShot Release Signing" (setup-release-signing.sh).
SIGNING_IDENTITY_NAME="${SIGNING_IDENTITY_NAME:-TallyShot Local Signing}"

has_signing_identity() {
  security find-identity -p codesigning | grep -q "\"$SIGNING_IDENTITY_NAME\""
}

# Writes a self-signed code signing identity (key and certificate) to a password-protected .p12.
# Usage: make_signing_p12 <common name> <out.p12> <password>
make_signing_p12() {
  local name="$1" out="$2" password="$3" work
  work="$(mktemp -d)"
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$work/key.pem" -out "$work/cert.pem" -subj "/CN=$name" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
  openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" -out "$out" -passout "pass:$password"
  rm -rf "$work"
}
