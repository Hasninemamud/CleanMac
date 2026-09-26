# Tech Context

- **Go** 1.22+ (`go.mod`), binary `bin/cleanmac`
- **SwiftUI** macOS 14+, SPM package `macos/CleanMac`
- **Shell** scripts in `scripts/`
- Makefile: `build`, `selfcheck`, `install`, `app`
- Legacy: Electron ^37 under `electron/` (deprecated)
- Trash: Swift `FileManager.trashItem`; scans never delete
- Disk: `df -k`; bundle id: `defaults read`; status: `sysctl` / `vm_stat`
