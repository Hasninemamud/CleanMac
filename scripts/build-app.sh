#!/usr/bin/env bash
# Build a minimal .app that wraps the SwiftUI binary + embeds Go kernel.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/homebrew/bin:$PATH"
APP="$ROOT/macos/CleanMac.app"
SRC="$ROOT/macos/CleanMac"
BIN="$ROOT/bin/cleanmac"

[[ -x "$BIN" ]] || make -C "$ROOT" build

cd "$SRC"
swift build -c release --product CleanMac 2>/dev/null || swift build -c release

SWIFT_BIN="$(swift build -c release --show-bin-path)/CleanMac"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SWIFT_BIN" "$APP/Contents/MacOS/CleanMac"
cp "$BIN" "$APP/Contents/Resources/cleanmac"
# Brand assets
LOGO_SRC="$SRC/Sources/Resources/logo.png"
ICON_SRC="$SRC/Sources/Resources/AppIcon.png"
[[ -f "$LOGO_SRC" ]] && cp "$LOGO_SRC" "$APP/Contents/Resources/logo.png"
[[ -f "$ICON_SRC" ]] && cp "$ICON_SRC" "$APP/Contents/Resources/AppIcon.png"
chmod +x "$APP/Contents/MacOS/CleanMac" "$APP/Contents/Resources/cleanmac"

cat > "$APP/Contents/Info.plist" <<'PLIST'
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
  <string>2.1.0</string>
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

echo "Built $APP"
