#!/usr/bin/env bash
# Load + browser smoke tests for the marketing site.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/website"
PORT="${CLEANMAC_TEST_PORT:-8765}"
BASE="http://127.0.0.1:${PORT}"

cd "$WEB"
python3 -m http.server "$PORT" --bind 127.0.0.1 >/tmp/cleanmac-web-test.log 2>&1 &
PID=$!
cleanup() { kill "$PID" 2>/dev/null || true; }
trap cleanup EXIT

for i in $(seq 1 40); do
  if curl -sf "$BASE/" >/dev/null; then break; fi
  sleep 0.1
  if [[ $i -eq 40 ]]; then
    echo "FAIL: server did not start on $PORT"
    exit 1
  fi
done

echo "== load test (ab) =="
ab -n 200 -c 20 -q "$BASE/" | tee /tmp/cleanmac-ab.txt
FAILED=$(awk '/Failed requests/ {print $3}' /tmp/cleanmac-ab.txt)
NON2XX=$(awk '/Non-2xx responses/ {print $3}' /tmp/cleanmac-ab.txt)
FAILED=${FAILED:-0}
NON2XX=${NON2XX:-0}
if [[ "$FAILED" != "0" || "$NON2XX" != "0" ]]; then
  echo "FAIL: ab failures failed=$FAILED non2xx=$NON2XX"
  exit 1
fi
echo "load ok (200 requests, 0 failed)"

echo "== browser smoke (playwright) =="
if [[ ! -d "$WEB/node_modules/playwright" ]]; then
  (cd "$WEB" && npm install --no-fund --no-audit >/tmp/cleanmac-pw-npm.log 2>&1)
fi
(cd "$WEB" && npx playwright install chromium >/tmp/cleanmac-pw-install.log 2>&1)
(cd "$WEB" && node "$WEB/browser-test.mjs" "$BASE")
echo "browser ok"

echo "website tests passed"
