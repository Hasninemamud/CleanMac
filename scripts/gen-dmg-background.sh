#!/usr/bin/env bash
# Regenerate packaging/dmg-background.png (Retina 1320×840 for a 660×420 DMG window).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 <<PY
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path

ROOT = Path("$ROOT")
W, H = 1320, 840
img = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(img)
top, mid, bot = (26, 21, 14), (40, 30, 20), (10, 8, 6)
for y in range(H):
    t = y / (H - 1)
    if t < 0.4:
        u = t / 0.4
        c = tuple(int(top[i] + (mid[i] - top[i]) * u) for i in range(3))
    else:
        u = (t - 0.4) / 0.6
        c = tuple(int(mid[i] + (bot[i] - mid[i]) * u) for i in range(3))
    draw.line([(0, y), (W, y)], fill=c)

glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for i, a in enumerate(range(36, 0, -3)):
    r = 220 + i * 28
    gd.ellipse([W // 2 - r, 300 - r, W // 2 + r, 300 + r], fill=(213, 155, 63, a))
img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(50))).convert("RGB")
draw = ImageDraw.Draw(img)
draw.rectangle([0, 0, W, 4], fill=(213, 155, 63))

layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ld = ImageDraw.Draw(layer)
ld.rounded_rectangle([505, 348, 770, 372], radius=12, fill=(213, 155, 63, 210))
ld.polygon([(755, 318), (825, 360), (755, 402)], fill=(213, 155, 63, 230))
img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")

wells = Image.new("RGBA", (W, H), (0, 0, 0, 0))
wd = ImageDraw.Draw(wells)
for cx in (360, 960):
    wd.ellipse([cx - 140, 500, cx + 140, 548], fill=(0, 0, 0, 55))
    wd.ellipse([cx - 120, 505, cx + 120, 540], fill=(255, 255, 255, 14))
img = Image.alpha_composite(img.convert("RGBA"), wells).convert("RGB")
draw = ImageDraw.Draw(img)

def font(size):
    for p in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()

tf, sf = font(54), font(26)
title, sub = "CleanMac", "Drag to Applications to install"
draw.text(((W - tf.getlength(title)) / 2, 64), title, fill=(250, 243, 230), font=tf)
draw.text(((W - sf.getlength(sub)) / 2, 138), sub, fill=(186, 166, 136), font=sf)

logo = Image.open(ROOT / "macos/CleanMac/Sources/Resources/logo.png").convert("RGBA").resize((88, 88), Image.Resampling.LANCZOS)
img = img.convert("RGBA")
img.paste(logo, (44, 44), logo)
img = img.convert("RGB")

out = ROOT / "packaging/dmg-background.png"
out.parent.mkdir(parents=True, exist_ok=True)
img.save(out, "PNG", optimize=True)
print("wrote", out, img.size)
PY
