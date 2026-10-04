#!/usr/bin/env python3
"""Compose the README hero banner and rounded screenshot tiles.

Run from the repo root after capturing fresh screenshots:

    xcrun simctl io booted screenshot docs/images/raw/today-top.png
    ...
    python3 scripts/make-readme-assets.py

Screenshots come from the LuckRingDemo target, so they need no ring in range.
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "docs", "images", "raw")
OUT = os.path.join(ROOT, "docs", "images")

# Palette mirrored from ios/Sources/Shared/DesignSystem.swift
BG_TOP = (11, 11, 15)
BG_BOTTOM = (18, 18, 26)
SLEEP = (0x6C, 0x7B, 0xFF)
READINESS = (0x2E, 0xD3, 0xB7)
ACTIVITY = (0xFF, 0x8A, 0x4C)
TEXT = (0xF2, 0xF2, 0xF5)
TEXT_DIM = (0x9A, 0x9A, 0xA6)
TEXT_FAINT = (0x6B, 0x6B, 0x78)

FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_DISPLAY = "/System/Library/Fonts/SFNSRounded.ttf"
FONT_MONO = "/System/Library/Fonts/SFNSMono.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


# ---------------------------------------------------------------- primitives


def vertical_gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img.resize((w, h), Image.BILINEAR)


def radial_glow(size, center, radius, color, strength):
    """Additive soft radial light, drawn on its own layer then screened in."""
    w, h = size
    layer = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(layer)
    steps = 46
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        alpha = int(255 * strength * (1 - t) ** 2.1)
        d.ellipse(
            [center[0] - r, center[1] - r, center[0] + r, center[1] + r],
            fill=alpha,
        )
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.09))
    solid = Image.new("RGB", (w, h), color)
    return solid, layer


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, image.size[0] - 1, image.size[1] - 1], radius=radius, fill=255
    )
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def drop_shadow(image, blur=34, offset=(0, 16), opacity=150, spread=6):
    """Return an RGBA canvas the size of `image` with the shape's shadow behind it."""
    pad = blur * 2
    canvas = Image.new("RGBA", (image.size[0] + pad * 2, image.size[1] + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow.putalpha(image.getchannel("A").point(lambda a: int(a * opacity / 255)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur / 2.2))
    shadow = ImageChops_offset(shadow, offset[0], offset[1])
    canvas.alpha_composite(shadow, (pad + spread, pad + spread))
    return canvas, pad


def ImageChops_offset(im, dx, dy):
    from PIL import ImageChops

    return ImageChops.offset(im, dx, dy)


# ------------------------------------------------------------------- screens


def load_screen(name, width):
    path = os.path.join(RAW, name + ".png")
    if not os.path.exists(path):
        raise SystemExit("missing screenshot: %s" % path)
    im = Image.open(path).convert("RGB")
    h = int(width * im.size[1] / im.size[0])
    return rounded(im.resize((width, h), Image.LANCZOS), radius=int(width * 0.115))


# -------------------------------------------------------------------- banner


def build_banner(screens=("today-top", "vitals", "health")):
    W, H = 2400, 1000
    base = vertical_gradient((W, H), BG_TOP, BG_BOTTOM).convert("RGB")

    for color, center, radius, strength in [
        (SLEEP, (250, 120), 1150, 0.30),
        (READINESS, (2150, 880), 1000, 0.22),
        (ACTIVITY, (1500, 60), 800, 0.13),
    ]:
        solid, mask = radial_glow((W, H), center, radius, color, strength)
        base = Image.composite(
            Image.blend(base, solid, 0.9), base, mask.point(lambda a: a)
        )

    # A trace of grain to stop the large flat gradient from banding. Kept very
    # low on purpose: noise is the enemy of PNG compression and this is a
    # 2400px-wide gradient, so even 3.5% grain nearly tripled the file size.
    noise = Image.effect_noise((W, H), 7).convert("L").point(lambda v: 5)
    base = Image.blend(base, Image.merge("RGB", (noise, noise, noise)), 0.012)

    banner = base.convert("RGBA")

    # --- phones, fanned on the right
    phone_w = 372
    layers = []
    for i, key in enumerate(list(screens)):
        shot = load_screen(key, phone_w)
        angle = [-8, 0, 8][i]
        shot = shot.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
        layers.append((shot, key))

    strip_w = sum(l[0].size[0] for l in layers) + 2 * 34
    strip_h = max(l[0].size[1] for l in layers)
    strip = Image.new("RGBA", (strip_w, strip_h + 40), (0, 0, 0, 0))

    x = 34
    for shot, _ in layers:
        holder, pad = drop_shadow(shot, blur=30, opacity=170, spread=4)
        strip.alpha_composite(holder, (x, 0))
        strip.alpha_composite(shot, (x + pad, pad))
        x += shot.size[0] + 34 - pad * 2

    banner.alpha_composite(strip, (W - strip_w - 90, (H - strip_h) // 2 + 30))

    # Text and translucent chrome go on their own overlay. Drawing alpha directly
    # onto the banner and then flattening to RGB discards the alpha channel
    # instead of compositing it, which turns faint chips into solid blobs.
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    # --- eyebrow pill
    eyebrow_font = font(FONT_DISPLAY, 25)
    label = "OPEN SOURCE  ·  iOS  ·  SWIFTUI"
    tw = d.textlength(label, font=eyebrow_font)
    px, py = 130, 250
    d.rounded_rectangle(
        [px, py, px + tw + 52, py + 54], radius=27, fill=(255, 255, 255, 20),
        outline=(255, 255, 255, 55), width=2,
    )
    d.ellipse([px + 25, py + 23, px + 37, py + 35], fill=READINESS + (255,))
    d.text((px + 50, py + 15), label, font=eyebrow_font, fill=TEXT_DIM + (255,))

    # --- title
    title_font = font(FONT_DISPLAY, 168)
    d.text((126, 330), "Luck Ring", font=title_font, fill=TEXT + (255,))

    # accent underline
    d.rounded_rectangle([132, 528, 132 + 470, 534], radius=3, fill=SLEEP + (255,))

    # --- subtitle
    sub_font = font(FONT_REGULAR, 37)
    d.text(
        (130, 578),
        "A native iOS companion for a Bluetooth smart ring —",
        font=sub_font, fill=TEXT_DIM + (255,),
    )
    d.text(
        (130, 630),
        "reverse-engineered BLE protocol, own scoring model.",
        font=sub_font, fill=TEXT_DIM + (255,),
    )

    # --- three colour-keyed chips
    chip_font = font(FONT_DISPLAY, 26)
    chips = [("Sleep", SLEEP), ("Readiness", READINESS), ("Activity", ACTIVITY)]
    cx = 132
    for name, color in chips:
        w = d.textlength(name, font=chip_font)
        d.rounded_rectangle(
            [cx, 716, cx + w + 42, 768], radius=26, fill=color + (30,),
            outline=color + (120,), width=2,
        )
        d.ellipse([cx + 19, 734, cx + 31, 746], fill=color + (255,))
        d.text((cx + 42, 726), name, font=chip_font, fill=color + (255,))
        cx += w + 42 + 16

    banner.alpha_composite(overlay)

    # --- hairline top highlight
    hl = Image.new("RGBA", (W, 3), (0, 0, 0, 0))
    ImageDraw.Draw(hl).rectangle(
        [0, 0, W, 2], fill=(255, 255, 255, 30)
    )
    banner.alpha_composite(hl)

    # JPEG, not PNG. The banner is a photographic-style gradient, where PNG's
    # filters do badly: q92 JPEG measured visually identical at 232K against
    # 644K for the same pixels.
    banner.convert("RGB").save(
        os.path.join(OUT, "banner.jpg"), quality=92, optimize=True, progressive=True
    )
    print("wrote docs/images/banner.jpg")


# ------------------------------------------------------------------- tiles

# Single source of truth for the screenshot set. The README grid is checked
# against this list, so adding a screen here and forgetting the README fails loudly
# instead of leaving a ragged row behind.
TILES = [
    "today-top",
    "today-detail",
    "sleep-detail",
    "vitals",
    "health",
    "data",
    "period",
    "period-calendar",
]

READMES = ["README.md", "README.zh-CN.md"]


def build_tiles():
    for name in TILES:
        shot = load_screen(name, 420)
        shot.save(os.path.join(OUT, name + ".png"), optimize=True)
        print("wrote docs/images/%s.png" % name)


def referenced_images(text):
    """Every docs/images/... path a README points at."""
    import re

    return set(re.findall(r'src="(docs/images/[^"]+)"', text))


def verify_readme_images():
    """Fail if a README points at a missing file, or a generated tile goes unused.

    Both halves matter. A broken src renders as a gap in the grid, and a tile
    nobody references means a screen was captured and then quietly dropped from
    the README - which is exactly how the last row ended up holding one image.
    """
    import re

    problems = []
    referenced = {}

    for readme in READMES:
        path = os.path.join(ROOT, readme)
        if not os.path.exists(path):
            problems.append("missing README: %s" % readme)
            continue
        with open(path, encoding="utf-8") as handle:
            refs = referenced_images(handle.read())
        referenced[readme] = refs

        for ref in sorted(refs):
            # The hero banner is generated separately below.
            if not os.path.exists(os.path.join(ROOT, ref)):
                problems.append("%s references a missing image: %s" % (readme, ref))

    generated = {"docs/images/%s.png" % name for name in TILES}
    for readme, refs in referenced.items():
        for unused in sorted(generated - refs):
            problems.append(
                "%s never shows the generated tile %s" % (readme, os.path.basename(unused))
            )

    if not os.path.exists(os.path.join(OUT, "banner.jpg")):
        problems.append("README hero banner docs/images/banner.jpg is missing")

    if problems:
        raise SystemExit(
            "README image check failed:\n  - " + "\n  - ".join(problems)
        )
    print("README images: %d tiles referenced by all %d READMEs" % (len(TILES), len(READMES)))


if __name__ == "__main__":
    build_banner()
    build_tiles()
    verify_readme_images()