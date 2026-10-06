#!/usr/bin/env python3
"""Writes the master looter icon the raid cells show (Media/MasterLooter.tga):
the client has the loot method but no art for it anywhere in its UI.

A gold coin, 32 x 32: a dark rim, the gold face, a lighter raised centre
and a small shine at its top left, anti-aliased against transparency.
Uncompressed 32-bit TGA, rows stored bottom to top, like the other files
in Media/. No dependencies beyond the standard library.

Run from the repository root:  python3 tools/make_master_looter.py
The output is deterministic; re-running it must not change the file.
A new texture file only loads after a full restart of the game client
(a /reload is not enough).
"""
import os
import struct

SIZE = 32
SUB = 4  # sub-samples per axis for the anti-aliased edges
CENTRE = SIZE / 2
OUTER = 14.5  # the coin's radius
RIM = 2.5  # the dark rim's width
FACE = 8.5  # the raised centre's radius
SHINE = (12.0, 11.0, 3.0)  # centre x, centre y (from the top) and radius

RIM_COLOR = (0.45, 0.29, 0.05)
FACE_COLOR = (0.93, 0.70, 0.16)
RAISED_COLOR = (1.0, 0.84, 0.35)
SHINE_COLOR = (1.0, 0.97, 0.80)


def colour_at(px, py):
    """The colour at point (px, py) (x right, y down), or None outside."""
    dx, dy = px - CENTRE, py - CENTRE
    r = (dx * dx + dy * dy) ** 0.5
    if r > OUTER:
        return None
    if r > OUTER - RIM:
        return RIM_COLOR
    sx, sy = px - SHINE[0], py - SHINE[1]
    if sx * sx + sy * sy <= SHINE[2] * SHINE[2]:
        return SHINE_COLOR
    if r <= FACE:
        return RAISED_COLOR
    return FACE_COLOR


def texel(x, y):
    """Averaged colour and coverage of texel (x, y)."""
    total, rgb = 0, [0.0, 0.0, 0.0]
    for i in range(SUB):
        for j in range(SUB):
            c = colour_at(x + (i + 0.5) / SUB, y + (j + 0.5) / SUB)
            if c is not None:
                total += 1
                for k in range(3):
                    rgb[k] += c[k]
    if total == 0:
        return (0.0, 0.0, 0.0), 0.0
    return tuple(v / total for v in rgb), total / (SUB * SUB)


def write_tga(path):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    rows = []
    for y in range(SIZE - 1, -1, -1):  # bottom row first
        row = bytearray()
        for x in range(SIZE):
            (r, g, b), a = texel(x, y)
            row += bytes((int(round(b * 255)), int(round(g * 255)), int(round(r * 255)), int(round(a * 255))))
        rows.append(bytes(row))
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(b"".join(rows))


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media")
    os.makedirs(root, exist_ok=True)
    write_tga(os.path.join(root, "MasterLooter.tga"))


if __name__ == "__main__":
    main()
