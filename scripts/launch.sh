#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/macos/CleanMac.app"
INST="/Applications/CleanMac.app"
WANT="$("$ROOT/scripts/version.sh")"

app_version() {
  defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo ""
}

need_build() {
  [[ ! -d "$APP" ]] && return 0
  [[ "$(app_version "$APP")" != "$WANT" ]] && return 0
  [[ ! -x "$APP/Contents/Resources/cleanmac" ]] && return 0
  "$APP/Contents/Resources/cleanmac" version 2>/dev/null | grep -qx "$WANT" || return 0
  return 1
}

if need_build; then
  make -C "$ROOT" app
fi

TARGET="$APP"
if [[ -d "$INST" ]]; then
  if [[ "$(app_version "$INST")" != "$WANT" ]]; then
    make -C "$ROOT" app
  fi
  TARGET="$INST"
fi

xattr -cr "$TARGET" 2>/dev/null || true
open "$TARGET"
