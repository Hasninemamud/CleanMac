# CleanMac

Mac space cleaner — **Go kernel + shell scripts + SwiftUI app** (Mole-style architecture).

Electron (`electron/`, `src/`) is **deprecated**; use the native stack below.

## Architecture

```
Go (cmd/cleanmac)     scanners, analyze, optimize, status — JSON CLI
Shell (scripts/)      install / launch / selfcheck / build-app
SwiftUI (macos/)      review-first UI; Trash via FileManager
```

| Module | CLI |
| --- | --- |
| Junk / Installers / Purge | `cleanmac junk\|installer\|purge --json` |
| Apps leftovers | `cleanmac apps --json` |
| Disk / Large / Dupes | `cleanmac analyze overview\|large\|dupes --json` |
| Optimize | `cleanmac optimize [--dry-run] --json` |
| Status | `cleanmac status --json` |

Files go to **Trash** only (Swift UI). System paths stay blocked.

## Develop

```bash
# Go CLI
make build
./bin/cleanmac version
make selfcheck

# SwiftUI app (.app with embedded binary)
make app
open macos/CleanMac.app

# Or launch helper
./scripts/launch.sh
```

Install CLI to `~/bin`:

```bash
make install
```

## Legacy Electron

```bash
npm install && npm start   # deprecated
npm run dist:unsigned      # old DMG path
```

Website: `website/index.html`
