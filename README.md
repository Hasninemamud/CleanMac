<p align="center">
  <img src="build/icon.png" alt="CleanMac" width="120">
</p>

<h1 align="center">CleanMac</h1>

<p align="center">
  A review-first Mac space cleaner.<br>
  <b>Go kernel</b> · <b>shell scripts</b> · <b>SwiftUI app</b>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

<p align="center">
  <a href="https://github.com/Hasninemamud/CleanMac/releases/latest">Download</a> ·
  <a href="#cli-usage">CLI</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="#safety">Safety</a> ·
  <a href="#license">License</a>
</p>

---

## Overview

CleanMac helps you reclaim disk space from caches, build artifacts, old installers, large files, duplicates, and leftovers from uninstalled apps. Nothing is deleted behind your back: every scan is shown for review first, and selected items are moved to the **Trash**, never permanently removed.

It deliberately skips RAM-booster gimmicks. Optimize and Status offer light maintenance and a health snapshot, nothing more.

## Features

The app has five sections plus Settings and a menu-bar HUD:

| Section | Tabs | What it does |
| --- | --- | --- |
| **Clean** | Junk · Installers · Purge | Caches, logs, Trash (review), installers, project artifacts |
| **Software** | Caches · Leftovers · Orphans · Uninstall · Updates · Startup | App leftovers, uninstall to Trash, Homebrew/MAS updates, LaunchAgents |
| **Analyze** | Overview · Map · Large · Dupes | Disk breakdown, folder treemap drill-down, large files, duplicates |
| **Optimize** | | Maintenance catalog with dry-run and skip reasons (DNS needs admin) |
| **Status** | | Live meters, top processes (Quit), Keep awake / Clean screen |

Settings: Whitelist, Doctor, History. Menu bar shows health score + CPU.

## Architecture

```
SwiftUI (macos/CleanMac)  →  CLIExecutor (argv)  →  bin/cleanmac --json
                                    ↘ FileManager.trashItem  (Trash-only deletes)
```

| Layer | Path | Role |
| --- | --- | --- |
| Go kernel | `cmd/cleanmac`, `internal/*` | Scanners, analysis, optimize, status. Emits JSON on stdout and progress on stderr. Scans only; never deletes. |
| Shell | `scripts/` | Install, launch, self-check, build the `.app`, package the DMG |
| SwiftUI app | `macos/CleanMac` | Review UI. Moves selected items to Trash via `FileManager`. |
| Website | `website/` | Static marketing site (no Node) |

## Requirements

- macOS 14 or later (for the app)
- Go toolchain (version in `go.mod`)
- Xcode command line tools / Swift 5.9+ (to build the app)
- [`create-dmg`](https://github.com/create-dmg/create-dmg) (only for `make package`)

## Install

### Download

Grab the latest `.dmg` or `.zip` from the [Releases page](https://github.com/Hasninemamud/CleanMac/releases/latest), then drag **CleanMac.app** into Applications.

> **"CleanMac is damaged"?** Browsers set the quarantine flag on downloaded apps, and the build is not yet notarized. Clear it:
>
> ```bash
> xattr -cr ~/Downloads/CleanMac.app
> # or
> bash scripts/unquarantine.sh ~/Downloads/CleanMac.app
> ```

### Build from source

```bash
git clone https://github.com/Hasninemamud/CleanMac.git
cd CleanMac

make build          # → bin/cleanmac
./bin/cleanmac version

make app            # builds the SwiftUI app → macos/CleanMac.app
bash scripts/launch.sh
```

Install the CLI to `~/bin` (override with `CLEANMAC_BIN`):

```bash
make install
```

## CLI usage

Every command prints JSON.

```bash
cleanmac junk --json                  # cache scan
cleanmac installer --json             # installer files
cleanmac purge --json                 # project build artifacts
cleanmac apps --json                  # app leftovers / orphans
cleanmac analyze overview --json      # disk overview
cleanmac analyze large --json         # large files (--min-mb 50, --root <dir>)
cleanmac analyze dupes --json         # duplicate files
cleanmac optimize --dry-run --json    # preview maintenance actions
cleanmac optimize --id dns,finder     # run selected actions
cleanmac status --json                # disk + system status
cleanmac version
```

Optimize action IDs: `dns`, `mdutil`, `finder`, `quarantine`. The `dns` action needs admin rights and is skipped when run without them.

## Safety

- **Trash only.** Files are moved to Trash from the Swift UI; the Go kernel only scans.
- **Review first.** Nothing is removed until you select it.
- **Blocked paths.** System locations (`/System`, `/usr`, `/bin`, `/sbin`, …) and sensitive user data (Keychains, Mail, Messages, Calendars, Photos library, Music library, `.ssh`, `.gnupg`, credential-holding caches like CloudKit) are never offered for removal.
- **Mirrored rules.** The same rules exist in Go (`internal/safety`) and Swift (`Safety.swift`).

## Development

```bash
make test         # go test ./internal/...
make selfcheck    # safety tests + CLI JSON contract + blocked-path check
make test-website # ab load test + Playwright browser smoke
make clean        # remove build output
```

## Distribute

```bash
make package      # → dist/CleanMac-<version>-<arch>.dmg (+ .zip)
```

Publish a GitHub release:

```bash
gh release create v2.2.8 \
  dist/CleanMac-2.2.8-arm64.dmg dist/CleanMac-2.2.8-arm64.zip \
  dist/CleanMac-arm64.dmg dist/CleanMac-arm64.zip \
  --title "CleanMac 2.2.8" --notes "Distinct page colors and animations for Clean, Apps, Analyze, Optimize, and Status."
```

The app is ad-hoc signed. Developer ID signing and notarization would remove the quarantine workaround above.

## Project layout

```
cmd/cleanmac/       CLI entrypoint
internal/           scanners, safety, disk, duplicates, optimize, status
macos/CleanMac/     SwiftUI app (Swift Package)
scripts/            install, launch, selfcheck, build-app, package
packaging/          DMG background art
build/              app icon
website/            static marketing site
memory-bank/        project notes and context
```

## Roadmap

- Developer ID signing and notarization
- Full Disk Access guidance when Library scans have gaps

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Released under the [MIT License](LICENSE). © 2026 A.K.M Hasnine Mamud
