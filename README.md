# CleanMac

Mac space cleaner — **Go kernel + shell scripts + SwiftUI app**.

## Architecture

```
Go (cmd/cleanmac)     scanners, analyze, optimize, status — JSON CLI
Shell (scripts/)      install / launch / selfcheck / build-app / package
SwiftUI (macos/)      review-first UI; Trash via FileManager
```

| Module | CLI |
| --- | --- |
| Junk / Installers / Purge | `cleanmac junk\|installer\|purge --json` |
| Apps leftovers | `cleanmac apps --json` |
| Disk / Large / Dupes | `cleanmac analyze overview\|large\|dupes --json` |
| Optimize | `cleanmac optimize [--dry-run] --json` |
| Status | `cleanmac status --json` |

Junk scan targets **caches only** (app/browser/dev caches, DerivedData). Installers and project purge are separate tabs. Files go to **Trash** only (Swift UI). System / Keychain / Photos paths stay blocked.

## Develop

```bash
cd ~/cleanmac
make build
./bin/cleanmac version
make selfcheck

make app
bash scripts/launch.sh
```

Install CLI to `~/bin`:

```bash
make install
```

## Distribute

```bash
make package   # → dist/CleanMac-2.1.1.zip
```

If a **downloaded** app says it is “damaged”, Brave/Chrome set the quarantine flag. Clear it:

```bash
xattr -cr ~/Downloads/CleanMac.app
# or: bash scripts/unquarantine.sh ~/Downloads/CleanMac.app
```

Developer ID + notarization removes that permanently.

Website: `website/index.html`
