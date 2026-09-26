# System Patterns

```
SwiftUI Models → CLIExecutor (argv, never shell strings) → bin/cleanmac --json
                                              ↘ FileManager.trashItem (destructive)
```

- `internal/*` — Go scanners + safety (no UI)
- `cmd/cleanmac` — CLI subcommands, progress on stderr JSON
- `macos/CleanMac` — `@Observable` AppState + views
- Safety: blocked prefixes mirrored in Go `internal/safety` and Swift `Safety.swift`
- Duplicates: size → partial SHA-256 → full SHA-256
