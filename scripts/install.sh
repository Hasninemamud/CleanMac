#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/bin/cleanmac"
DEST="${CLEANMAC_BIN:-$HOME/bin}"

if [[ ! -x "$BIN" ]]; then
  echo "Building cleanmac..."
  make -C "$ROOT" build
fi

mkdir -p "$DEST"
cp "$BIN" "$DEST/cleanmac"
chmod +x "$DEST/cleanmac"
echo "Installed $DEST/cleanmac"
echo "Ensure $DEST is on your PATH."
