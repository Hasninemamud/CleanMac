# CleanMac

Mac space cleaner — distribute as a `.dmg`. Overview, Junk, Large Files, Duplicates.

## Develop

```bash
cd ~/cleanmac
npm install
npm start
```

## Build DMG

```bash
cd ~/cleanmac
npm install
npm run dist:unsigned
```

Output: `dist/CleanMac-1.0.0-*.dmg`

Open the DMG → drag **CleanMac** to **Applications**.

On first launch macOS may warn about an unsigned app: System Settings → Privacy & Security → Open Anyway.

## Safety

Trash only. System paths blocked.
