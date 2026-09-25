# CleanMac

Mac space cleaner — Overview, Junk, Large Files, Duplicates.

## Website

Marketing site with live scan demo:

```bash
open website/index.html
# or
npx serve website
```

GitHub Pages: Settings → Pages → deploy from `/website` (or root `docs`).

## Develop

```bash
cd ~/cleanmac
npm install
npm start
```

## Build DMG

```bash
npm run dist:unsigned
```

Output: `dist/CleanMac-*-arm64.dmg`

Release: https://github.com/Hasninemamud/CleanMac/releases

## Safety

Trash only. System paths blocked.
