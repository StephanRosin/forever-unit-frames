#!/usr/bin/env python3
"""Writes the minimap button's icon, Media/MinimapIcon.tga, from the
project logo (docs/curseforge/logo-512.png): the logo's unit frame
graphic without the lettering (unreadable at icon size), centred on the
logo's dark background so it fits inside a circle, scaled to 64 x 64 and
cut to that circle (anti-aliased), since a minimap button's icon sits in
a round border. Uncompressed 32-bit TGA, rows bottom to top, like the other files
in Media/.

Needs Pillow (python3 -m pip install pillow). Run from the repository
root:  python3 tools/make_minimap_icon.py
"""
import os
import struct

from PIL import Image

SIZE = 64
SUB = 4  # sub-samples per axis for the circle's edge
# The circle's radius in texels: a texel of margin so the edge is soft.
RADIUS = SIZE / 2 - 1
# The unit frame graphic in the 512 px logo (left, top, right, bottom),
# the badge included, and its width on the 512 px canvas: its diagonal
# then stays inside the circle.
GRAPHIC = (52, 62, 478, 332)
GRAPHIC_WIDTH = 400
# The logo's background colour between graphic and lettering.
BACKGROUND_AT = (20, 20)


def circle_coverage(x, y):
    """Share of texel (x, y) inside the icon's circle."""
    inside = 0
    for i in range(SUB):
        for j in range(SUB):
            dx = x + (i + 0.5) / SUB - SIZE / 2
            dy = y + (j + 0.5) / SUB - SIZE / 2
            if dx * dx + dy * dy <= RADIUS * RADIUS:
                inside += 1
    return inside / (SUB * SUB)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    logo = Image.open(os.path.join(here, "..", "docs", "curseforge", "logo-512.png")).convert("RGBA")
    canvas = Image.new("RGBA", logo.size, logo.getpixel(BACKGROUND_AT))
    graphic = logo.crop(GRAPHIC)
    height = round(graphic.height * GRAPHIC_WIDTH / graphic.width)
    graphic = graphic.resize((GRAPHIC_WIDTH, height), Image.LANCZOS)
    canvas.paste(graphic, ((logo.width - GRAPHIC_WIDTH) // 2, (logo.height - height) // 2), graphic)
    icon = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    rows = []
    for y in range(SIZE - 1, -1, -1):  # bottom row first
        row = bytearray()
        for x in range(SIZE):
            r, g, b, a = icon.getpixel((x, y))
            alpha = int(round(a * circle_coverage(x, y)))
            row += bytes((b, g, r, alpha))
        rows.append(bytes(row))
    with open(os.path.join(here, "..", "Media", "MinimapIcon.tga"), "wb") as fh:
        fh.write(header)
        fh.write(b"".join(rows))


if __name__ == "__main__":
    main()
