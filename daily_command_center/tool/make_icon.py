"""Ketchup app icon — a drizzle of ketchup, which happens to be a tilde (~).

One thick tomato squiggle, round caps, on flat char (dark roast). No gradient,
no check, no numeral, no tomato-the-fruit literalism (spec §4). The exact path
is the SVG from the spec, viewBox 0 0 100 56:
    M8 38 C 22 6, 40 6, 50 26 S 78 50, 92 18   stroke #D9543E width 15 round-cap

Outputs (assets/icon/):
  ketchup.png       full square — tomato squiggle on flat char (image_path)
  ketchup_fg.png    adaptive foreground — tomato squiggle on transparent
  ketchup_mono.png  Android 13+ themed layer — salt squiggle on transparent
Then run: flutter pub run flutter_launcher_icons
"""
from PIL import Image, ImageDraw
import os

SIZE = 1024
TOMATO = (217, 84, 62)    # D9543E
CHAR = (21, 17, 15)       # 15110F  flat dark roast
SALT = (240, 236, 230)    # F0ECE6  monochrome themed layer

os.makedirs('assets/icon', exist_ok=True)


SS = 3  # supersample factor for smooth, gap-free anti-aliased edges


def _bezier(p0, c1, c2, p3, n=240):
    out = []
    for i in range(n + 1):
        t = i / n
        m = 1 - t
        out.append((
            m**3 * p0[0] + 3 * m**2 * t * c1[0] + 3 * m * t**2 * c2[0] + t**3 * p3[0],
            m**3 * p0[1] + 3 * m**2 * t * c1[1] + 3 * m * t**2 * c2[1] + t**3 * p3[1],
        ))
    return out


def _squiggle_path():
    # Seg 1: cubic C 22,6 40,6 50,26 from M8,38
    seg1 = _bezier((8, 38), (22, 6), (40, 6), (50, 26))
    # Seg 2: smooth S 78,50 92,18 — first control is the reflection of (40,6)
    # about the join (50,26): 2*(50,26)-(40,6) = (60,46)
    seg2 = _bezier((50, 26), (60, 46), (78, 50), (92, 18))
    return seg1 + seg2[1:]


def draw_squiggle(img, color, box_w_frac):
    """Map the 100x56 viewBox into the canvas, centered, and stroke it.

    Stamps overlapping filled circles along a densely-sampled path on a
    supersampled canvas, then downsamples — this gives a continuous round-cap
    round-join stroke with no joint cracks (PIL's thick `line(joint=…)` leaves
    gaps) and clean anti-aliased edges.
    """
    big = SIZE * SS
    overlay = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    w = big * box_w_frac
    scale = w / 100.0
    ox = (big - w) / 2
    oy = big * 0.5 - (56 * scale) / 2
    r = (15 * scale) / 2  # stroke 15 in viewBox units → radius
    for x, y in _squiggle_path():
        cx, cy = ox + x * scale, oy + y * scale
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    overlay = overlay.resize((SIZE, SIZE), Image.LANCZOS)
    img.paste(overlay, (0, 0), overlay)


# Full square icon — tomato squiggle on flat char.
full = Image.new('RGB', (SIZE, SIZE), CHAR)
draw_squiggle(full, TOMATO, box_w_frac=0.72)
full.save('assets/icon/ketchup.png')

# Adaptive foreground — squiggle alone, sized to the inner ~60% safe zone.
fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw_squiggle(fg, TOMATO, box_w_frac=0.60)
fg.save('assets/icon/ketchup_fg.png')

# Monochrome themed layer (Android 13+) — single-tone squiggle on transparent.
mono = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw_squiggle(mono, SALT, box_w_frac=0.60)
mono.save('assets/icon/ketchup_mono.png')

print('icons written to assets/icon/  (ketchup.png, ketchup_fg.png, ketchup_mono.png)')
