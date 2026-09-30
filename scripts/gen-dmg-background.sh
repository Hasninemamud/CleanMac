#!/usr/bin/env bash
# Regenerate packaging/dmg-background.png
# Window = 660×400 → Retina background 1320×800.
# Finder icon centers (create-dmg --icon x y): (180, 200) and (480, 200)
# → @2x centers: (360, 400) and (960, 400). Arrow sits between them.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CLEANMAC_ROOT="$ROOT"
python3 <<'PY'
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import os

ROOT = Path(os.environ["CLEANMAC_ROOT"])
W, H = 1320, 800
# Icon layout (must match scripts/package.sh)
CX_APP, CX_APPS, CY = 360, 960, 400

img = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(img)
top, mid, bot = (28, 22, 14), (38, 28, 18), (12, 10, 7)
for y in range(H):
    t = y / (H - 1)
    if t < 0.35:
        u = t / 0.35
        c = tuple(int(top[i] + (mid[i] - top[i]) * u) for i in range(3))
    else:
        u = (t - 0.35) / 0.65
        c = tuple(int(mid[i] + (bot[i] - mid[i]) * u) for i in range(3))
    draw.line([(0, y), (W, y)], fill=c)

glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for i, a in enumerate(range(22, 0, -2)):
    r = 120 + i * 24
    gd.ellipse([W // 2 - r, CY - r, W // 2 + r, CY + r], fill=(213, 155, 63, a))
img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(36))).convert("RGB")
draw = ImageDraw.Draw(img)
draw.rectangle([0, 0, W, 3], fill=(213, 155, 63))

# Arrow between icons only — leave clear gap so tip isn't under Applications.
# Icon radius @2x ≈ 128; keep ≥40px clear of each icon edge.
layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ld = ImageDraw.Draw(layer)
ax0, tip = CX_APP + 170, CX_APPS - 170
ld.rounded_rectangle([ax0, CY - 10, tip - 48, CY + 10], radius=10, fill=(213, 155, 63, 220))
ld.polygon(
    [(tip - 56, CY - 34), (tip, CY), (tip - 56, CY + 34)],
    fill=(213, 155, 63, 235),
)
img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")

# Soft wells under icons only (no label plates — Finder draws its own names).
wells = Image.new("RGBA", (W, H), (0, 0, 0, 0))
wd = ImageDraw.Draw(wells)
for cx in (CX_APP, CX_APPS):
    wd.ellipse([cx - 100, CY + 70, cx + 100, CY + 108], fill=(0, 0, 0, 45))
img = Image.alpha_composite(img.convert("RGBA"), wells).convert("RGB")

# Lift the label band so Finder's dark icon names stay readable.
band = Image.new("RGBA", (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(band)
for i, a in enumerate(range(0, 55, 5)):
    y0 = CY + 95 + i * 4
    bd.rectangle([0, y0, W, H], fill=(236, 220, 190, a))
img = Image.alpha_composite(img.convert("RGBA"), band.filter(ImageFilter.GaussianBlur(12))).convert("RGB")
draw = ImageDraw.Draw(img)

def font(size):
    for p in (
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()

tf, sf = font(48), font(24)
title, sub = "Install CleanMac", "Drag the app onto Applications"
tw, sw = tf.getlength(title), sf.getlength(sub)
draw.text(((W - tw) / 2, 48), title, fill=(250, 243, 230), font=tf)
draw.text(((W - sw) / 2, 112), sub, fill=(186, 166, 136), font=sf)

out = ROOT / "packaging/dmg-background.png"
out.parent.mkdir(parents=True, exist_ok=True)
# 144 DPI marks this as @2x so Finder scales 1320×800 into the 660×400 window.
img.save(out, "PNG", optimize=True, dpi=(144, 144))
print("wrote", out, img.size, "dpi=144")
PY
# Belt-and-suspenders: sips also stamps Retina DPI (create-dmg copies this file as-is).
sips -s dpiWidth 144 -s dpiHeight 144 "$ROOT/packaging/dmg-background.png" >/dev/null
