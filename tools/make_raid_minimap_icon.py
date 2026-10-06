#!/usr/bin/env python3
"""Writes the raid minimap button's icon, Media/RaidMinimapIcon.tga: the
project logo's look (its dark background, a gold frame, green health
bars) as a raid panel, two columns of three cells, one of them with a
dispel square in its corner. Drawn on a 512 px canvas, then scaled,
cut to a circle and written like the unit frames' icon
(tools/make_minimap_icon.py, whose write_round_tga it uses).

Needs Pillow (python3 -m pip install pillow). Run from the repository
root:  python3 tools/make_raid_minimap_icon.py
"""
import os

from PIL import Image, ImageDraw

from make_minimap_icon import write_round_tga

CANVAS = 512
BACKGROUND = (14, 18, 27, 255)
# The panel's frame: gold, darker at the bottom (the logo's bevel).
GOLD_LIGHT = (240, 200, 110, 255)
GOLD_DARK = (150, 105, 35, 255)
INSIDE = (22, 27, 39, 255)
# Cells: health green, the missing part dark, a magic-blue dispel square.
GREEN = (46, 185, 69, 255)
MISSING = (10, 12, 18, 255)
DISPEL = (79, 145, 243, 255)
# The panel inside the circle (left, top, right, bottom), its frame's
# thickness, the gap between cells, and each cell's share of health.
PANEL = (96, 106, 416, 406)
FRAME = 18
GAP = 12
HEALTH = ((1.0, 0.7), (0.45, 1.0), (0.85, 0.6))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    canvas = Image.new("RGBA", (CANVAS, CANVAS), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    left, top, right, bottom = PANEL
    height = bottom - top
    for y in range(top, bottom):  # the frame, light to dark
        share = (y - top) / height
        color = tuple(int(GOLD_LIGHT[i] + (GOLD_DARK[i] - GOLD_LIGHT[i]) * share) for i in range(4))
        draw.line([(left, y), (right, y)], fill=color)
    inner = (left + FRAME, top + FRAME, right - FRAME, bottom - FRAME)
    draw.rectangle(inner, fill=INSIDE)
    cell_w = (inner[2] - inner[0] - 3 * GAP) / 2
    cell_h = (inner[3] - inner[1] - 4 * GAP) / 3
    for row, shares in enumerate(HEALTH):
        for col, share in enumerate(shares):
            x0 = inner[0] + GAP + col * (cell_w + GAP)
            y0 = inner[1] + GAP + row * (cell_h + GAP)
            draw.rectangle((x0, y0, x0 + cell_w, y0 + cell_h), fill=MISSING)
            draw.rectangle((x0, y0, x0 + cell_w * share, y0 + cell_h), fill=GREEN)
            if (row, col) == (1, 1):
                square = cell_h * 0.4
                draw.rectangle((x0 + cell_w - square, y0, x0 + cell_w, y0 + square), fill=DISPEL)
    write_round_tga(canvas, os.path.join(here, "..", "Media", "RaidMinimapIcon.tga"))


if __name__ == "__main__":
    main()
