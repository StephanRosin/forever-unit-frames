#!/usr/bin/env python3
"""Draw the ForeverUnitFrames icon set with PhotoCraft headless.

Each icon is a 256x256 transparent document built from PhotoCraft vector shape
layers (shape.create: live shapes and bezier paths, gradient fills, outside
strokes). Saved as <name>.pcraft, then image.imageSize to 64x64 -> <name>.png.
Python only computes path coordinates; all drawing happens in PhotoCraft.
"""
import json
import math
import os
import subprocess
import sys

CLI = os.path.expanduser("~/.local/opt/photocraft/bin/photocraft-cli")
OUT = os.path.dirname(os.path.abspath(__file__))
INK = "#0b0d12"   # outline colour
OL = 12           # outline width at 256 px (~1 px at 24 px)
K = 0.5522847498  # bezier circle constant


def grad(stops, angle=-90, style="linear"):
    return {"gradient": {"stops": [[t, c] for t, c in stops], "angle": angle, "style": style}}


GOLD = grad([(0, "#fff1b0"), (0.45, "#f2c041"), (1, "#a8670f")])
SILVER = grad([(0, "#ffffff"), (0.5, "#cfd6e0"), (1, "#7b8594")])
STEEL = grad([(0, "#f4f7fb"), (1, "#9aa4b2")], angle=0)


def stroke(w=OL, color=INK):
    return {"width": w, "color": color, "align": "outside", "join": "round", "cap": "round"}


def poly(pts, op="combine"):
    return {"closed": True, "op": op, "knots": [[round(x, 2), round(y, 2)] for x, y in pts]}


def ellipse(cx, cy, rx, ry, op="combine"):
    kx, ky = rx * K, ry * K
    knots = [
        {"anchor": [cx, cy - ry], "in": [cx - kx, cy - ry], "out": [cx + kx, cy - ry], "smooth": True},
        {"anchor": [cx + rx, cy], "in": [cx + rx, cy - ky], "out": [cx + rx, cy + ky], "smooth": True},
        {"anchor": [cx, cy + ry], "in": [cx + kx, cy + ry], "out": [cx - kx, cy + ry], "smooth": True},
        {"anchor": [cx - rx, cy], "in": [cx - rx, cy + ky], "out": [cx - rx, cy - ky], "smooth": True},
    ]
    return {"closed": True, "op": op, "knots": knots}


def rot(pts, deg, cx=128, cy=128):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def path_shape(name, subpaths, fill, strk=None):
    return {"kind": "path", "name": name, "path": {"subpaths": subpaths, "fillRule": "nonzero"},
            "fill": fill, "stroke": strk}


def live(kind, name, rect, fill, strk=None, **kw):
    return dict(kind=kind, name=name, rect=rect, fill=fill, stroke=strk, **kw)


# ---------------------------------------------------------------- icons
def skull():
    return [
        path_shape("Skull", [ellipse(128, 104, 90, 82), poly([(78, 150), (178, 150), (170, 214), (86, 214)])],
                   grad([(0, "#fff1b0"), (0.5, "#f0bd3c"), (1, "#a8670f")]), stroke()),
        path_shape("Eyes", [ellipse(92, 116, 27, 25), ellipse(164, 116, 27, 25)], "#1a0f04"),
        path_shape("Nose", [poly([(128, 140), (142, 168), (114, 168)])], "#1a0f04"),
        path_shape("Teeth", [poly([(106, 184), (114, 184), (114, 214), (106, 214)]),
                             poly([(124, 184), (132, 184), (132, 214), (124, 214)]),
                             poly([(142, 184), (150, 184), (150, 214), (142, 214)])], "#1a0f04"),
    ]


def rare_star():
    return [live("star", "Star", [16, 18, 224, 224], SILVER, stroke(), sides=5, starRatio=0.5, cornerRadius=6),
            live("star", "Shine", [76, 80, 104, 104], grad([(0, "#ffffff"), (1, "#dfe5ee")]), None,
                 sides=5, starRatio=0.5)]


def sword_parts(deg, blade_len=146):
    """One sword pointing up along x=128, rotated by deg about the centre."""
    tip, guard = 14, 14 + blade_len
    blade = [(128, tip), (148, tip + 30), (148, guard), (108, guard), (108, tip + 30)]
    cross = [(84, guard), (172, guard), (172, guard + 22), (84, guard + 22)]
    grip = [(118, guard + 22), (138, guard + 22), (138, guard + 54), (118, guard + 54)]
    return rot(blade, deg), rot(cross, deg), rot(grip, deg), rot([(128, guard + 66)], deg)[0]


def crossed_swords():
    out = []
    for d in (-42, 42):
        blade, cross, grip, (px, py) = sword_parts(d)
        out.append(path_shape(f"Blade {d}", [poly(blade)], STEEL, stroke()))
        out.append(path_shape(f"Hilt {d}", [poly(cross), poly(grip), ellipse(px, py, 16, 16)],
                              GOLD, stroke()))
    return out


def crown():
    body = [(34, 196), (34, 84), (82, 134), (128, 52), (174, 134), (222, 84), (222, 196)]
    return [
        path_shape("Crown", [poly(body)], GOLD, stroke()),
        path_shape("Tips", [ellipse(34, 76, 16, 16), ellipse(128, 44, 18, 18), ellipse(222, 76, 16, 16)],
                   GOLD, stroke()),
        path_shape("Band", [poly([(34, 170), (222, 170), (222, 214), (34, 214)])],
                   grad([(0, "#f7d36a"), (1, "#9a5d0c")]), stroke()),
        path_shape("Gem", [ellipse(128, 192, 14, 14)], grad([(0, "#ff6a5a"), (1, "#9b0f0f")]),
                   stroke(6)),
    ]


def assistant():
    # low silver diadem: one peak, two side bumps -- clearly lower and greyer than the leader crown
    body = [(30, 200), (30, 112), (76, 146), (128, 48), (180, 146), (226, 112), (226, 200)]
    return [
        path_shape("Diadem", [poly(body)], SILVER, stroke()),
        path_shape("Tip", [ellipse(128, 40, 18, 18)], SILVER, stroke()),
        path_shape("Band", [poly([(30, 172), (226, 172), (226, 220), (30, 220)])],
                   grad([(0, "#e8edf3"), (1, "#6e7886")]), stroke()),
        path_shape("Gem", [ellipse(128, 196, 15, 15)], grad([(0, "#8fd0ff"), (1, "#1d5fa8")]), stroke(6)),
    ]


def guide():
    flag = {"closed": True, "op": "combine", "knots": [
        {"anchor": [66, 40], "in": [66, 40], "out": [124, 16], "smooth": False},
        {"anchor": [236, 56], "in": [178, 78], "out": [236, 56], "smooth": False},
        {"anchor": [236, 160], "in": [236, 160], "out": [178, 182], "smooth": False},
        {"anchor": [66, 144], "in": [124, 120], "out": [66, 144], "smooth": False},
    ]}
    return [
        path_shape("Pole", [poly([(40, 30), (66, 30), (66, 236), (40, 236)])],
                   grad([(0, "#f7d36a"), (1, "#8a5410")], angle=0), stroke()),
        path_shape("Knob", [ellipse(53, 28, 20, 20)], GOLD, stroke()),
        path_shape("Flag", [flag], grad([(0, "#7fe08a"), (1, "#1f8a3a")]), stroke()),
        live("star", "Emblem", [114, 62, 76, 76], "#fff6cf", stroke(5), sides=5, starRatio=0.5),
    ]


def badge(name, c_light, c_dark):
    return path_shape(name, [ellipse(128, 128, 112, 112)],
                      grad([(0, c_light), (1, c_dark)], style="linear"), stroke())


SYMBOL = grad([(0, "#ffffff"), (1, "#d8dde6")])


def tank():
    shield = {"closed": True, "op": "combine", "knots": [
        [72, 58], {"anchor": [128, 42], "in": [100, 56], "out": [156, 56], "smooth": False},
        [184, 58],
        {"anchor": [184, 120], "in": [184, 120], "out": [184, 168], "smooth": True},
        {"anchor": [128, 214], "in": [164, 196], "out": [92, 196], "smooth": False},
        {"anchor": [72, 120], "in": [72, 168], "out": [72, 120], "smooth": True},
    ]}
    return [badge("Badge", "#5aa8ff", "#123e86"),
            path_shape("Shield", [shield], SYMBOL, stroke(10)),
            path_shape("Boss", [poly([(122, 70), (134, 70), (134, 190), (122, 190)]),
                                poly([(84, 104), (172, 104), (172, 116), (84, 116)])], "#3a6fb8")]


def healer():
    a, b = 98, 158  # arm edges
    plus = [(a, 44), (b, 44), (b, a), (212, a), (212, b), (b, b), (b, 212), (a, 212), (a, b), (44, b), (44, a), (a, a)]
    return [badge("Badge", "#6fe07a", "#146b2a"),
            path_shape("Cross", [poly(plus)], SYMBOL, stroke(10))]


def damage():
    blade, cross, grip, (px, py) = (rot(p, 45) if isinstance(p, list) else p for p in
                                    _sword_upright(scale=0.82))
    return [badge("Badge", "#ff6b5e", "#8a1010"),
            path_shape("Blade", [poly(blade)], SYMBOL, stroke(10)),
            path_shape("Hilt", [poly(cross), poly(grip), ellipse(*rot([(px, py)], 45)[0], 12, 12)],
                       grad([(0, "#ffe08a"), (1, "#b07414")]), stroke(10))]


def _sword_upright(scale):
    s = lambda pts: [(128 + (x - 128) * scale, 128 + (y - 128) * scale) for x, y in pts]
    tip, guard = 22, 172
    blade = s([(128, tip), (146, tip + 30), (146, guard), (110, guard), (110, tip + 30)])
    cross = s([(86, guard), (170, guard), (170, guard + 18), (86, guard + 18)])
    grip = s([(120, guard + 18), (136, guard + 18), (136, guard + 46), (120, guard + 46)])
    (px, py), = s([(128, guard + 56)])
    return blade, cross, grip, (px, py)


def mail():
    return [
        path_shape("Envelope", [poly([(22, 64), (234, 64), (234, 196), (22, 196)])],
                   grad([(0, "#fff8e4"), (1, "#d9c49a")]), stroke()),
        path_shape("Flap", [{"closed": False, "op": "combine", "knots": [[30, 72], [128, 142], [226, 72]]}],
                   None, {"width": 10, "color": INK, "align": "center", "join": "round", "cap": "round"}),
        path_shape("Seal", [ellipse(128, 142, 24, 24)], grad([(0, "#ff6a5a"), (1, "#8f0d0d")]), stroke(8)),
    ]


def arrow():
    return [
        path_shape("Arrow", [poly([(128, 22), (210, 218), (128, 176), (46, 218)])],
                   grad([(0, "#fff1b0"), (1, "#f0b52e")]), stroke()),
        path_shape("Shade", [poly([(128, 22), (210, 218), (128, 176)])],
                   grad([(0, "#e8a524"), (1, "#9a5d0c")])),
    ]


ICONS = {
    "boss_skull": skull, "rare_star": rare_star, "combat": crossed_swords, "leader": crown,
    "guide": guide, "assistant": assistant, "role_tank": tank, "role_healer": healer,
    "role_damage": damage, "minimap_mail": mail, "minimap_arrow": arrow,
}


def run(args):
    r = subprocess.run([CLI, "run", *args], capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"photocraft failed: {r.stderr}\n{r.stdout[-2000:]}")


def build(name):
    src, png = os.path.join(OUT, f"{name}.pcraft"), os.path.join(OUT, f"{name}.png")
    args = ["--new", json.dumps({"width": 256, "height": 256, "background": "transparent", "name": name})]
    for shape in ICONS[name]():
        args += ["--cmd", "shape.create", "--params", json.dumps(shape)]
    run(args + ["--out", src])
    run([src, "--cmd", "image.imageSize", "--params", json.dumps({"width": 64, "height": 64}), "--out", png])


if __name__ == "__main__":
    for n in sys.argv[1:] or ICONS:
        build(n)
        print("built", n)
