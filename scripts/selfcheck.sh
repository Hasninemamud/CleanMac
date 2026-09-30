#!/usr/bin/env bash
# Smoke: safety never returns system paths in junk; CLI JSON contracts hold.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/homebrew/bin:$PATH"
BIN="$ROOT/bin/cleanmac"

cd "$ROOT"
go test ./internal/safety/...

[[ -x "$BIN" ]] || make -C "$ROOT" build

"$BIN" version | grep -q .
"$BIN" status --json | grep -q '"diskTotal"'
"$BIN" optimize --dry-run --json | grep -q '"actions"'
"$BIN" doctor --json | grep -q '"checks"'
"$BIN" whitelist list --json | grep -q '"paths"'
"$BIN" analyze treemap --json | grep -q '"children\|"path"'
"$BIN" software updates --json | grep -q '"items"'
"$BIN" software startup --json | grep -q '"items"'

# Junk must not contain blocked prefixes
OUT="$("$BIN" junk --json 2>/dev/null || true)"
for bad in '"/System' '"/usr/' '"/bin/' '"/sbin/'; do
  if echo "$OUT" | grep -Fq "$bad"; then
    echo "FAIL: junk JSON contains blocked path prefix $bad"
    exit 1
  fi
done

echo "selfcheck ok"
