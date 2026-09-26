#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/macos/CleanMac.app"
BIN="$ROOT/bin/cleanmac"

if [[ -d "$APP" ]]; then
  open "$APP"
  exit 0
fi

if [[ ! -x "$BIN" ]]; then
  make -C "$ROOT" build
fi

exec "$BIN" "$@"
