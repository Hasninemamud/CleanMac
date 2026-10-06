# System Patterns

```
SwiftUI Models → CLIExecutor (argv) → bin/cleanmac --json
                         ↘ removeItem (junk) / trashItem (uninstall, Analyze)
```

- `internal/*` — Go scanners + safety
- `cmd/cleanmac` — CLI subcommands; progress JSON on stderr
- `macos/CleanMac` — `@Observable` AppState + views
- Safety mirrored in Go `internal/safety` and Swift `Safety.swift`
- Duplicates: size → partial SHA-256 → full SHA-256
