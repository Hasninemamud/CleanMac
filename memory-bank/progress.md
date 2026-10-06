# Progress

## Done

- Go kernel `cmd/cleanmac`: junk (10-cat taxonomy), installers, purge, apps, software, analyze (+treemap), optimize (expanded catalog), status (process paths), whitelist, history, doctor, **ai detect|scan**
- SwiftUI app: Clean (+ Moon AI Cleanup) · Software · Analyze · Optimize (results sheet) · Status (pin/sort/force-quit/copy); Settings (cacheRemovalMode, showAICleanup); Menu Bar HUD
- Shell: install / launch / build-app / package / selfcheck / test-website
- Release **2.2.12** — Fix Analyze/Optimize endless Scanning (timed sizing, segment-only loads)
- Release **2.2.11** — Mole feature parity (AI Cleanup, Clean categories, Optimize/Status, Analyze/Apps segments)
- Release **2.2.10** — Mole planet themes (Earth/Mars/Mercury/Jupiter/Sun) on every page
- Mole parity push: junk classify + AI paths, optimize tasks, AI page, status actions, settings toggles, richer menu bar

## In progress / recent

- Menu bar left-click → NSPopover SwiftUI HUD (not flat NSMenu); metrics CPU/GPU/health recalibrated vs Activity Monitor / Mole
- Status Mem/process-name mismatch fixed: AM memory buckets + ps path parsing (Chrome etc.)
- Modern theme pass: shared tokens (`PlanetCanvas`, `glassPanel`, Motion/Typeface/Radius), section transitions, meter numericText animations; Clean/Apps/Optimize recalculate on appear; Status live refresh loop kept

## Next

- Apple Developer signing + notarization for `.app`
- Full Disk Access guidance if Library scan gaps appear
- Privileged helper for sudo optimize actions
- Analyze: 24h scan cache + permission-denied retry polish
- Software Updates: Sparkle detection beyond brew/MAS
- Skip running-app caches is heuristic (ps name match) — refine if false positives
