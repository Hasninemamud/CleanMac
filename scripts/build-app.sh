#!/usr/bin/env bash
# Build a signed .app that wraps the SwiftUI binary + embeds Go kernel.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
APP="$ROOT/macos/CleanMac.app"
SRC="$ROOT/macos/CleanMac"
BIN="$ROOT/bin/cleanmac"
VERSION="${CLEANMAC_VERSION:-2.2.11}"

[[ -x "$BIN" ]] || make -C "$ROOT" build

cd "$SRC"
swift build -c release --product CleanMac 2>/dev/null || swift build -c release

SWIFT_BIN="$(swift build -c release --show-bin-path)/CleanMac"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SWIFT_BIN" "$APP/Contents/MacOS/CleanMac"
cp "$BIN" "$APP/Contents/Resources/cleanmac"

LOGO_SRC="$SRC/Sources/Resources/logo.png"
ICON_SRC="$SRC/Sources/Resources/AppIcon.png"
[[ -f "$LOGO_SRC" ]] && cp "$LOGO_SRC" "$APP/Contents/Resources/logo.png"
[[ -f "$ICON_SRC" ]] && cp "$ICON_SRC" "$APP/Contents/Resources/AppIcon.png"

# Finder/Dock need .icns (PNG alone is ignored → stale/generic icon).
if [[ -f "$ICON_SRC" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z "$((s * 2))" "$((s * 2))" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$(dirname "$ICONSET")"
fi

chmod +x "$APP/Contents/MacOS/CleanMac" "$APP/Contents/Resources/cleanmac"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CleanMac</string>
  <key>CFBundleIdentifier</key>
  <string>com.cleanmac.app</string>
  <key>CFBundleName</key>
  <string>CleanMac</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppearanceName</key>
  <string>NSAppearanceNameDarkAqua</string>
</dict>
</plist>
PLIST

# Seal Info.plist + resources. Incomplete signature + quarantine → "damaged" dialog.
codesign --force --deep --sign - "$APP" 2>/dev/null || codesign --force --sign - "$APP"
xattr -cr "$APP" 2>/dev/null || true
codesign --verify --verbose=2 "$APP" 2>&1 | head -5 || true

echo "Built $APP (v${VERSION})"
