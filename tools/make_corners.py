#!/usr/bin/env python3
"""Writes the corner art and masks the addon ships (Media/Corner.tga,
Media/CornerInverse.tga and the three Media/Rounded*.tga). No
dependencies beyond the standard library.

All are 64 x 64, uncompressed 32-bit TGA, white, the shape in the alpha
channel, rows stored bottom to top (the TGA default).

Corner.tga: the top-left corner of a rounded rectangle. A quarter disc
of radius 64 centred on the texture's bottom-right corner is opaque,
the rest transparent. The outer corner piece of a rounded border ring
shows it (mirrored for the other corners).

CornerInverse.tga: transparent inside a quarter disc of radius 63 around
the same corner, opaque outside. One texel smaller than the texture, so
the whole left column and top row stay opaque: a CLAMP mask of it lets
everything left of and above it through. Used for the inner edge of a
rounded border.

Rounded.tga: a rounded rectangle, SLICE texels radius at every corner, for
a nine-slice mask (SetTextureSliceMargins with SLICE on each side): the
corners keep their shape at any box size, the edges and the middle
stretch. Every texel between the corner cells is opaque.
RoundedTop.tga / RoundedBottom.tga: the same with only the top or only
the bottom corners round, the other two square (a frame whose other side
continues into a docked castbar).

Run from the repository root:  python3 tools/make_corners.py
The output is deterministic; re-running it must not change the files.
"""
import os
import struct

SIZE = 64
SUB = 4  # sub-samples per axis for the anti-aliased edge
SLICE = 28  # corner radius of the Rounded masks; their nine-slice margin


def coverage(x, y, radius=SIZE):
    """Share of texel (x, y) (x to the right, y downwards) inside the disc
    of the given radius around the texture's bottom-right corner."""
    inside = 0
    for i in range(SUB):
        for j in range(SUB):
            px = x + (i + 0.5) / SUB
            py = y + (j + 0.5) / SUB
            dx, dy = SIZE - px, SIZE - py
            if dx * dx + dy * dy <= radius * radius:
                inside += 1
    return inside / (SUB * SUB)


def rounded(round_top, round_bottom):
    """Alpha of a rounded-rectangle mask whose top and/or bottom corners
    are round (radius SLICE), the others square."""
    def alpha_of(x, y):
        top, bottom = y < SLICE, y >= SIZE - SLICE
        left, right = x < SLICE, x >= SIZE - SLICE
        if not ((top and round_top) or (bottom and round_bottom)) or not (left or right):
            return 1
        # Mirror into the top-left cell: the arc's centre is (SLICE, SLICE).
        mx = x if left else SIZE - 1 - x
        my = y if top else SIZE - 1 - y
        inside = 0
        for i in range(SUB):
            for j in range(SUB):
                dx = SLICE - (mx + (i + 0.5) / SUB)
                dy = SLICE - (my + (j + 0.5) / SUB)
                if dx * dx + dy * dy <= SLICE * SLICE:
                    inside += 1
        return inside / (SUB * SUB)
    return alpha_of


def write_tga(path, alpha_of):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    rows = []
    for y in range(SIZE - 1, -1, -1):  # bottom row first
        row = bytearray()
        for x in range(SIZE):
            a = int(round(alpha_of(x, y) * 255))
            row += bytes((255, 255, 255, a))  # B, G, R, A
        rows.append(bytes(row))
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(b"".join(rows))


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media")
    os.makedirs(root, exist_ok=True)
    write_tga(os.path.join(root, "Corner.tga"), coverage)
    write_tga(os.path.join(root, "CornerInverse.tga"), lambda x, y: 1 - coverage(x, y, SIZE - 1))
    write_tga(os.path.join(root, "Rounded.tga"), rounded(True, True))
    write_tga(os.path.join(root, "RoundedTop.tga"), rounded(True, False))
    write_tga(os.path.join(root, "RoundedBottom.tga"), rounded(False, True))


if __name__ == "__main__":
    main()
