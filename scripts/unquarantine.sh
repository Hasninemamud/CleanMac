#!/usr/bin/env bash
# Clear Gatekeeper quarantine so an unsigned/adhoc .app can open after download.
set -euo pipefail
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "usage: $0 /path/to/CleanMac.app" >&2
  exit 1
fi
if [[ ! -d "$TARGET" ]]; then
  echo "not an app bundle: $TARGET" >&2
  exit 1
fi
xattr -cr "$TARGET"
echo "Cleared quarantine on $TARGET — you can open it now."
