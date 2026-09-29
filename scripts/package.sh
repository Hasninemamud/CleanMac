#!/usr/bin/env bash
# Build zip + DMG for GitHub Releases.
# Downloaded apps may need: xattr -cr ~/Downloads/CleanMac.app
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$ROOT/macos/CleanMac.app"
VERSION="${CLEANMAC_VERSION:-2.1.2}"
ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] && ARCH="x64"
DMG_NAME="CleanMac-${VERSION}-${ARCH}.dmg"
ZIP_NAME="CleanMac-${VERSION}-${ARCH}.zip"

make -C "$ROOT" app
mkdir -p "$DIST"
xattr -cr "$APP" 2>/dev/null || true

STAGE="$DIST/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/CleanMac.app"
cat > "$STAGE/How to open if blocked.txt" <<EOF
If macOS says CleanMac is "damaged", the browser quarantined the download.

Fix (Terminal):

  xattr -cr /Applications/CleanMac.app

Or after mounting this DMG:

  xattr -cr /Volumes/CleanMac/CleanMac.app

Then drag CleanMac to Applications and open it.
Developer ID notarization removes this permanently.
EOF

rm -f "$DIST/$ZIP_NAME" "$DIST/$DMG_NAME"
ditto -c -k --keepParent "$STAGE/CleanMac.app" "$DIST/$ZIP_NAME"

ICNS="$APP/Contents/Resources/AppIcon.icns"
CREATE_DMG_ARGS=(
  --volname "CleanMac"
  --window-pos 200 120
  --window-size 540 380
  --icon-size 128
  --icon "CleanMac.app" 140 180
  --hide-extension "CleanMac.app"
  --app-drop-link 380 180
  --no-internet-enable
)
[[ -f "$ICNS" ]] && CREATE_DMG_ARGS+=(--volicon "$ICNS")

# create-dmg writes into cwd; run from dist with a staging folder as source.
(
  cd "$DIST"
  rm -f "$DMG_NAME"
  create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_NAME" "$STAGE"
)

# create-dmg sometimes leaves rw. / temporary names
if [[ ! -f "$DIST/$DMG_NAME" ]]; then
  found="$(ls -1 "$DIST"/*.dmg 2>/dev/null | head -1 || true)"
  [[ -n "$found" ]] && mv "$found" "$DIST/$DMG_NAME"
fi

rm -rf "$STAGE"
ls -lh "$DIST/$DMG_NAME" "$DIST/$ZIP_NAME"
echo "Packaged $DIST/$DMG_NAME"
