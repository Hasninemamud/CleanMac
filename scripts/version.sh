#!/usr/bin/env bash
# Single source of truth: cmd/cleanmac/main.go
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -E '^\s*const version = ' "$ROOT/cmd/cleanmac/main.go" | sed -E 's/.*"([^"]+)".*/\1/'
