#!/usr/bin/env python3
"""Writes the two corner masks the addon ships (Media/Corner.tga and
Media/CornerInverse.tga). No dependencies beyond the standard library.

Both are 64 x 64, uncompressed 32-bit TGA, white, the shape in the alpha
channel, rows stored bottom to top (the TGA default).

Corner.tga: the top-left corner of a rounded rectangle. A quarter disc
of radius 64 centred on the texture's bottom-right corner is opaque,
the rest transparent. Every texel of the right column and the bottom row
is (nearly) opaque, so a mask of this texture with CLAMP wrapping lets
everything right of and below it through.

CornerInverse.tga: transparent inside a quarter disc of radius 63 around
the same corner, opaque outside. One texel smaller than the texture, so
the whole left column and top row stay opaque: a CLAMP mask of it lets
everything left of and above it through. Used for the inner edge of a
rounded border.

Run from the repository root:  python3 tools/make_corners.py
The output is deterministic; re-running it must not change the files.
"""
import os
import struct

SIZE = 64
SUB = 4  # sub-samples per axis for the anti-aliased edge


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


if __name__ == "__main__":
    main()
