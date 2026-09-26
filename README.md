# CleanMac

Mac space cleaner — **Go kernel + shell scripts + SwiftUI app**.

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
cd ~/cleanmac
make build
./bin/cleanmac version
make selfcheck

make app
open macos/CleanMac.app
```

Install CLI to `~/bin`:

```bash
make install
```

Website: `website/index.html`
