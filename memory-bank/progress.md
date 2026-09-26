# Progress

## Done

- Go kernel `cmd/cleanmac`: junk, installers, purge, apps, analyze (overview/large/dupes), optimize, status
- Safety port + tests; `make selfcheck`
- Shell: install / launch / build-app / selfcheck
- SwiftUI app under `macos/CleanMac` with CLIExecutor + Trash
- README points to native stack; Electron marked deprecated

## Deprecated

- Electron UI (`electron/`, `src/ui`, `src/core`) — keep until native verified, then remove

## Next

- Apple Developer signing + notarization for `.app`
- Optional: remove Electron tree after soak
- Full Disk Access guidance if Library scan gaps appear
