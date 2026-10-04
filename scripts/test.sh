#!/usr/bin/env bash
# With only Command Line Tools, the Swift Testing macro plugin sits outside the default search path.
# With Xcode (CI), swift finds it on its own; passing the CLT plugin would mix toolchains.
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools* && -d "$PLUGINS" ]]; then
  swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
else
  swift test "$@"
fi
