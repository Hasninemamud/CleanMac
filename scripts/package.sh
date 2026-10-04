#!/usr/bin/env bash
# Build zip + DMG for GitHub Releases.
# Downloaded apps may need: xattr -cr ~/Downloads/CleanMac.app
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$ROOT/macos/CleanMac.app"
VERSION="${CLEANMAC_VERSION:-2.2.4}"
ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] && ARCH="x64"
DMG_NAME="CleanMac-${VERSION}-${ARCH}.dmg"
ZIP_NAME="CleanMac-${VERSION}-${ARCH}.zip"
BG="$ROOT/packaging/dmg-background.png"

make -C "$ROOT" app
mkdir -p "$DIST"
xattr -cr "$APP" 2>/dev/null || true

STAGE="$DIST/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/CleanMac.app"

rm -f "$DIST/$ZIP_NAME" "$DIST/$DMG_NAME"
ditto -c -k --keepParent "$STAGE/CleanMac.app" "$DIST/$ZIP_NAME"

ICNS="$APP/Contents/Resources/AppIcon.icns"
# Window 660×400; background 1320×800 (@2x). Icon centers match gen-dmg-background.sh.
CREATE_DMG_ARGS=(
  --volname "CleanMac"
  --window-pos 200 120
  --window-size 660 400
  --icon-size 128
  --text-size 12
  --icon "CleanMac.app" 180 200
  --hide-extension "CleanMac.app"
  --app-drop-link 480 200
  --no-internet-enable
)
[[ -f "$BG" ]] && CREATE_DMG_ARGS+=(--background "$BG")
[[ -f "$ICNS" ]] && CREATE_DMG_ARGS+=(--volicon "$ICNS")

# Always refresh artwork so layout stays in sync with icon coords.
bash "$ROOT/scripts/gen-dmg-background.sh"

(
  cd "$DIST"
  rm -f "$DMG_NAME"
  create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_NAME" "$STAGE"
)

if [[ ! -f "$DIST/$DMG_NAME" ]]; then
  found="$(ls -1 "$DIST"/CleanMac-"${VERSION}"*.dmg 2>/dev/null | head -1 || true)"
  [[ -n "$found" ]] && mv "$found" "$DIST/$DMG_NAME"
fi

rm -rf "$STAGE"
# Stable names so website /releases/latest/download/CleanMac-arm64.dmg always works.
# rm first so a leftover symlink isn't followed/overwritten in place.
rm -f "$DIST/CleanMac-${ARCH}.dmg" "$DIST/CleanMac-${ARCH}.zip"
cp -f "$DIST/$DMG_NAME" "$DIST/CleanMac-${ARCH}.dmg"
cp -f "$DIST/$ZIP_NAME" "$DIST/CleanMac-${ARCH}.zip"
ls -lh "$DIST/$DMG_NAME" "$DIST/$ZIP_NAME" "$DIST/CleanMac-${ARCH}.dmg"
echo "Packaged $DIST/$DMG_NAME (+ CleanMac-${ARCH}.dmg alias)"
