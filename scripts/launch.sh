#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/macos/CleanMac.app"
BIN="$ROOT/bin/cleanmac"

if [[ ! -d "$APP" ]]; then
  make -C "$ROOT" app
fi

# Browser downloads set com.apple.quarantine → Gatekeeper reports "damaged".
xattr -cr "$APP" 2>/dev/null || true
open "$APP"
