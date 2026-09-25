# System Patterns

- `src/core` — pure Node scanners/safety (no Electron import except trash callback)
- `electron/main.js` — BrowserWindow + IPC
- `electron/preload.js` — contextBridge API
- `src/ui` — renderer
- Safety: blocked prefixes; Trash via injected `trashFn` (`shell.trashItem`)
- Duplicates: size → partial SHA-256 → full SHA-256
