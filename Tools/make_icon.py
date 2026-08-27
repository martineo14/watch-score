#!/usr/bin/env python3
"""Draws the app icon: a tennis ball on a court-coloured ground.

Run it after changing a colour below; it overwrites the icon in place.

    python3 Tools/make_icon.py

watchOS masks the icon to a circle, so everything that matters stays well
inside the inscribed circle and the corners are left to the background.
"""
from PIL import Image, ImageDraw

OUT = "WatchScore/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SIZE = 1024
SS = 4                      # supersample, for clean curves
S = SIZE * SS

GROUND_TOP = (17, 78, 90)      # deep court teal
GROUND_BOTTOM = (5, 30, 37)
BALL_TOP = (222, 238, 66)      # the accent colour of the app, lit from above
BALL_BOTTOM = (163, 183, 24)
SEAM = (250, 253, 240)

cx = cy = S // 2
R = int(S * 0.322)             # ball radius: 64% of the icon width


def vertical_gradient(size, top, bottom):
    """A one pixel wide column stretched to the full square."""
    column = Image.new("RGB", (1, size))
    pixels = column.load()
    for y in range(size):
        t = y / (size - 1)
        pixels[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return column.resize((size, size), Image.BILINEAR)


icon = vertical_gradient(S, GROUND_TOP, GROUND_BOTTOM)

# --- the ball -------------------------------------------------------------
ball_box = (cx - R, cy - R, cx + R, cy + R)
ball_mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(ball_mask).ellipse(ball_box, fill=255)
icon.paste(vertical_gradient(S, BALL_TOP, BALL_BOTTOM), (0, 0), ball_mask)

# --- the two seams --------------------------------------------------------
# Each seam is the arc of a circle centred on the far side of the ball, so it
# bulges out towards its own edge. Drawing the whole circle and masking to the
# ball leaves just that arc. The radius has to clear sqrt(offset^2 + R^2), or
# the two arcs reach across the middle and cross into an X.
seams = Image.new("RGBA", (S, S), (0, 0, 0, 0))
pen = ImageDraw.Draw(seams)
offset, radius, width = int(0.80 * R), int(1.45 * R), max(1, int(0.085 * R))
for direction in (1, -1):
    ox = cx + direction * offset
    pen.ellipse((ox - radius, cy - radius, ox + radius, cy + radius),
                outline=SEAM + (255,), width=width)

seam_mask = Image.new("L", (S, S), 0)
# Pull the mask in by half the seam width so the seams stop short of the rim,
# the way they do on a ball rather than running off the edge.
inset = width // 2
ImageDraw.Draw(seam_mask).ellipse(
    (cx - R + inset, cy - R + inset, cx + R - inset, cy + R - inset), fill=255)
seams.putalpha(Image.composite(seams.getchannel("A"),
                               Image.new("L", (S, S), 0), seam_mask))
icon = Image.alpha_composite(icon.convert("RGBA"), seams)

# App icons must be fully opaque, so drop the alpha channel before saving.
icon.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(OUT)
print(f"wrote {OUT} ({SIZE}x{SIZE})")
