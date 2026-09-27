# Active Context

- **Stack:** Go CLI + shell + SwiftUI only (Electron removed)
- Nav: Clean · Apps · Analyze · Optimize · Status
- Trash-only deletes in Swift; Go scans only
- Version **2.1.1**
- Disk Status uses APFS **container** totals + **decimal GB** (matches System Settings; was 228 GiB mislabeled)
- App packaging: ad-hoc codesign + AppIcon.icns; `xattr -cr` clears download quarantine (“damaged”)
- Junk scan is **cache-only** (no Trash/logs/archives)
