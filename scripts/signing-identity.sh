# Sourced by the other scripts. Name of the local certificate every build is signed with.
# A stable certificate keeps the Screen Recording grant across rebuilds; ad-hoc signatures do not.
SIGNING_IDENTITY_NAME="TallyShot Local Signing"

has_signing_identity() {
  security find-identity -p codesigning | grep -q "\"$SIGNING_IDENTITY_NAME\""
}
