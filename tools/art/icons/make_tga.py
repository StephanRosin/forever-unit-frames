#!/usr/bin/env python3
"""Turn the icon PNGs (make_icons.py) into the addons' Media/Icon<Name>.tga.

The client loads TGA, not PNG: 64x64 RGBA, uncompressed, bottom-up like the
other Media textures. Each addon installs on its own, so each gets a copy of
the icons it draws; sibling repos are written when they sit next to this one.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPOS = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))

ROLES = {"role_tank": "RoleTank", "role_healer": "RoleHealer", "role_damage": "RoleDamage"}
TARGETS = {
    "ForeverUnitFrames": {"boss_skull": "BossSkull", "rare_star": "RareStar", "combat": "Combat",
                          "leader": "Leader", "guide": "Guide", "assistant": "Assistant", **ROLES},
    "ForeverSquareMinimap": {"minimap_mail": "MinimapMail", "minimap_arrow": "MinimapArrow"},
    "ForeverGroupFinder": ROLES,
}


def main():
    for repo, icons in TARGETS.items():
        media = os.path.join(REPOS, repo, "Media")
        if not os.path.isdir(media):
            print(f"skipped {repo}: no {media}")
            continue
        for src, name in icons.items():
            im = Image.open(os.path.join(HERE, f"{src}.png")).convert("RGBA")
            im.save(os.path.join(media, f"Icon{name}.tga"), orientation=-1, compression=None)
        print(f"{repo}: {len(icons)} icons")


if __name__ == "__main__":
    main()
