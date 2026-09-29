#!/usr/bin/env bash
# Regenerate packaging/dmg-background.png (Retina 1320×840 for a 660×420 DMG window).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 <<PY
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path

W, H = 1320, 840
img = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(img)

top, mid, bot = (26, 21, 14), (36, 28, 20), (12, 10, 7)
for y in range(H):
    t = y / (H - 1)
    if t < 0.45:
        u = t / 0.45
        c = tuple(int(top[i] + (mid[i] - top[i]) * u) for i in range(3))
    else:
        u = (t - 0.45) / 0.55
        c = tuple(int(mid[i] + (bot[i] - mid[i]) * u) for i in range(3))
    draw.line([(0, y), (W, y)], fill=c)

glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
cx, cy = W // 2, int(H * 0.42)
for i, a in enumerate(range(28, 0, -2)):
    r = 180 + i * 22
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(213, 155, 63, a))
glow = glow.filter(ImageFilter.GaussianBlur(40))
img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
draw = ImageDraw.Draw(img)
draw.rectangle([0, 0, W, 3], fill=(213, 155, 63))

gold = (213, 155, 63)
ax0, ay, ax1 = 520, 360, 800
draw.rounded_rectangle([ax0, ay - 10, ax1 - 20, ay + 10], radius=10, fill=gold)
draw.polygon([(ax1 - 30, ay - 36), (ax1 + 28, ay), (ax1 - 30, ay + 36)], fill=gold)

for cx in (360, 960):
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(overlay).ellipse([cx - 130, 510, cx + 130, 545], fill=(255, 255, 255, 18))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
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

title_f, sub_f = font(52), font(28)
title, sub = "CleanMac", "Drag CleanMac to Applications to install"
tw = title_f.getlength(title)
sw = sub_f.getlength(sub)
draw.text(((W - tw) / 2, 72), title, fill=(243, 234, 216), font=title_f)
draw.text(((W - sw) / 2, 140), sub, fill=(184, 163, 133), font=sub_f)

logo_path = Path("$ROOT/macos/CleanMac/Sources/Resources/logo.png")
if logo_path.exists():
    logo = Image.open(logo_path).convert("RGBA").resize((96, 96), Image.Resampling.LANCZOS)
    img = img.convert("RGBA")
    img.paste(logo, (48, 48), logo)
    img = img.convert("RGB")

out = Path("$ROOT/packaging/dmg-background.png")
out.parent.mkdir(parents=True, exist_ok=True)
img.save(out, "PNG", optimize=True)
print("wrote", out, img.size)
PY
