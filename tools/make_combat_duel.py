#!/usr/bin/env python3
"""Writes the animated combat icon (Media/CombatDuel.tga): two swords that
clash in an X, a spark at the strike, then settle.

Renders the Blender scene tools/combat_duel_scene.py (16 frames, 128 px,
transparent background) and packs the frames into a 4 x 4 flipbook sheet,
512 x 512, uncompressed 32-bit TGA, rows stored bottom to top (the TGA
default), frames left to right, top to bottom as the client's FlipBook
animation reads them (Elements/CombatAnimation.lua).

Needs Blender and Pillow. Run from the repository root:
    python3 tools/make_combat_duel.py
"""
import os
import struct
import subprocess
import tempfile

from PIL import Image

FRAMES, CELL, COLUMNS = 16, 128, 4
ROWS = FRAMES // COLUMNS
OUT = os.path.join("Media", "CombatDuel.tga")


def render(folder):
    # Rendered at twice the size and scaled down: smoother edges.
    subprocess.run(["blender", "-b", "--python", "tools/combat_duel_scene.py", "--", folder,
                    str(FRAMES), str(CELL * 2)], check=True, stdout=subprocess.DEVNULL)
    return [Image.open(os.path.join(folder, "f_%04d.png" % i)).convert("RGBA")
            .resize((CELL, CELL), Image.LANCZOS) for i in range(FRAMES)]


def write_tga(path, image):
    w, h = image.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    pixels = image.load()
    rows = []
    for y in range(h - 1, -1, -1):
        row = bytearray()
        for x in range(w):
            r, g, b, a = pixels[x, y]
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    with open(path, "wb") as f:
        f.write(header)
        f.write(b"".join(rows))


def main():
    with tempfile.TemporaryDirectory() as folder:
        frames = render(folder)
    sheet = Image.new("RGBA", (CELL * COLUMNS, CELL * ROWS), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % COLUMNS) * CELL, (i // COLUMNS) * CELL))
    write_tga(OUT, sheet)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
