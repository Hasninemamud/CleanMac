#!/usr/bin/env bash
# Package a distributable zip. Recipients who download via browser should run:
#   xattr -cr ~/Downloads/CleanMac.app
# (or use: bash scripts/unquarantine.sh /path/to/CleanMac.app)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$ROOT/macos/CleanMac.app"
VERSION="${CLEANMAC_VERSION:-2.1.1}"

make -C "$ROOT" app
mkdir -p "$DIST"
rm -f "$DIST/CleanMac-${VERSION}.zip"
xattr -cr "$APP" 2>/dev/null || true
ditto -c -k --keepParent "$APP" "$DIST/CleanMac-${VERSION}.zip"
# Zip can re-apply quarantine on download; ship a one-liner helper too.
cat > "$DIST/OPEN-ME-FIRST.txt" <<EOF
If macOS says CleanMac is "damaged", the browser quarantined the download.
Fix (Terminal):

  xattr -cr ~/Downloads/CleanMac.app

Then open CleanMac.app. Developer ID notarization removes this permanently.
EOF
echo "Wrote $DIST/CleanMac-${VERSION}.zip"
