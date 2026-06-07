from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 1024
TERRA_TOP = (217, 102, 61)   # D9663D
TERRA_BOT = (184, 81, 44)    # B8512C
CREAM = (242, 237, 225)      # F2EDE1
DARK = (14, 19, 17)          # 0E1311

os.makedirs('assets/icon', exist_ok=True)


def gradient(size, top, bot):
    img = Image.new('RGB', (size, size), top)
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=(
            int(top[0] + (bot[0] - top[0]) * t),
            int(top[1] + (bot[1] - top[1]) * t),
            int(top[2] + (bot[2] - top[2]) * t),
        ))
    return img


def draw_check(d, cx, cy, scale, color, width):
    p1 = (cx - 0.42 * scale, cy + 0.02 * scale)
    p2 = (cx - 0.12 * scale, cy + 0.34 * scale)
    p3 = (cx + 0.46 * scale, cy - 0.34 * scale)
    d.line([p1, p2, p3], fill=color, width=width, joint='curve')
    r = width // 2
    for p in (p1, p2, p3):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def serif_font(size):
    for path in [r'C:\Windows\Fonts\georgiab.ttf', r'C:\Windows\Fonts\timesbd.ttf',
                 r'C:\Windows\Fonts\georgia.ttf', r'C:\Windows\Fonts\times.ttf']:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


# Legacy icon: full-bleed gradient + check + serif "2"
legacy = gradient(SIZE, TERRA_TOP, TERRA_BOT)
d = ImageDraw.Draw(legacy)
draw_check(d, SIZE * 0.5, SIZE * 0.46, SIZE * 0.5, CREAM, int(SIZE * 0.09))
font = serif_font(int(SIZE * 0.22))
bbox = d.textbbox((0, 0), '2', font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
d.text((SIZE * 0.72 - tw / 2, SIZE * 0.78 - th / 2), '2', font=font, fill=DARK)
legacy.save('assets/icon/reminders2.png')

# Adaptive foreground: transparent, check centered in safe zone, no "2"
fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
d2 = ImageDraw.Draw(fg)
draw_check(d2, SIZE * 0.5, SIZE * 0.5, SIZE * 0.42, CREAM, int(SIZE * 0.085))
fg.save('assets/icon/reminders2_fg.png')

print('icons written to assets/icon/')
