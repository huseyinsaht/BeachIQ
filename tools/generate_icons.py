#!/usr/bin/env python3
"""Generate BeachIQ's launcher icons and Play Store graphics.

    py -3 tools/generate_icons.py        (needs Pillow)

Writes the legacy and adaptive Android launcher icons under
android/app/src/main/res/ and the Play Store listing graphics under
docs/assets/play-store/. Art is drawn procedurally so the icon can be
regenerated or tweaked (colors below) without a design tool.
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "docs", "assets", "play-store")

SEA_TOP = (14, 116, 144)
SEA_BOTTOM = (6, 62, 92)
SUN = (255, 196, 61)
FOAM = (255, 255, 255)
SS = 4  # supersampling factor
BASE = 1024


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def background(size):
    img = Image.new("RGB", (size, size))
    px = ImageDraw.Draw(img)
    for y in range(size):
        px.line([(0, y), (size, y)], fill=lerp(SEA_TOP, SEA_BOTTOM, y / (size - 1)))
    return img.convert("RGBA")


def wave_layer(size, y0, amp, phase, alpha):
    """A filled sine wave from y0 down to the bottom edge."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    pts = [(0, size)]
    for x in range(0, size + 1, 4):
        y = y0 + amp * math.sin(2 * math.pi * (x / size) * 1.5 + phase)
        pts.append((x, y))
    pts.append((size, size))
    draw.polygon(pts, fill=FOAM + (alpha,))
    return layer


def art(size):
    """The icon art (sun + waves) on a transparent square, in a 66% safe zone."""
    s = size * SS
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    # Everything lives inside the central 66% so adaptive-icon masks never clip it.
    margin = s * 0.17
    inner = int(s - 2 * margin)
    layer = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Three stacked waves, front-most fully opaque.
    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, inner - 1, inner - 1], fill=255)
    for y0, amp, phase, alpha in (
        (0.56, 0.045, 0.0, 120),
        (0.68, 0.05, 1.6, 190),
        (0.80, 0.05, 3.2, 255),
    ):
        layer.alpha_composite(
            wave_layer(inner, inner * y0, inner * amp, phase, alpha)
        )
    # Clip the waves' bottom to a circle so nothing leaves the safe zone.
    clipped = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    clipped.paste(layer, (0, 0), mask)
    # Sun with a soft glow, drawn last and unclipped so the glow keeps its shape.
    sun = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    cx, cy, r = inner * 0.66, inner * 0.30, inner * 0.20
    glow = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [cx - r * 1.5, cy - r * 1.5, cx + r * 1.5, cy + r * 1.5], fill=SUN + (90,)
    )
    sun.alpha_composite(glow.filter(ImageFilter.GaussianBlur(inner * 0.05)))
    ImageDraw.Draw(sun).ellipse([cx - r, cy - r, cx + r, cy + r], fill=SUN + (255,))
    clipped.alpha_composite(sun)
    canvas.alpha_composite(clipped, (int(margin), int(margin)))
    return canvas.resize((size, size), Image.LANCZOS)


def rounded(img, radius_ratio=0.22):
    size = img.size[0]
    mask = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size * SS - 1, size * SS - 1], radius=int(size * SS * radius_ratio), fill=255
    )
    mask = mask.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def font_path():
    for p in (
        "C:/Windows/Fonts/segoeuib.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ):
        if os.path.exists(p):
            return p
    raise SystemExit("No bold TrueType font found; edit font_path() in this script.")


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    full = background(BASE)
    full.alpha_composite(art(BASE))
    # Legacy launcher icons (pre-API 26): rounded square.
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in legacy.items():
        save(
            rounded(full.resize((px, px), Image.LANCZOS)),
            os.path.join(RES, f"mipmap-{density}", "ic_launcher.png"),
        )
    # Adaptive icon foreground (108dp canvas): same art, transparent.
    fg = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for density, px in fg.items():
        save(art(px), os.path.join(RES, f"mipmap-{density}", "ic_launcher_foreground.png"))
    # Play Store icon: full-bleed 512 square (Play applies its own mask).
    save(full.resize((512, 512), Image.LANCZOS).convert("RGB"), os.path.join(STORE, "icon-512.png"))
    # Feature graphic 1024x500: sea gradient, icon art left, wordmark space right.
    fg_img = Image.new("RGBA", (1024, 500))
    bg = background(1024).crop((0, 262, 1024, 762))
    fg_img.paste(bg, (0, 0))
    emblem = art(420)
    fg_img.alpha_composite(emblem, (70, 40))
    draw = ImageDraw.Draw(fg_img)
    title = ImageFont.truetype(font_path(), 96)
    sub = ImageFont.truetype(font_path(), 36)
    draw.text((520, 170), "BeachIQ", font=title, fill=FOAM + (255,))
    draw.text((524, 290), "Is it good to swim today?", font=sub, fill=SUN + (255,))
    save(fg_img.convert("RGB"), os.path.join(STORE, "feature-graphic-1024x500.png"))


if __name__ == "__main__":
    main()
