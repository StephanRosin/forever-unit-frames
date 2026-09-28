# Two swords clashing, rendered as a transparent PNG sequence.
# blender -b --python swords.py -- <outdir> <frames> <size>
import bpy, math, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/swords"
FRAMES = int(argv[1]) if len(argv) > 1 else 16
SIZE = int(argv[2]) if len(argv) > 2 else 256
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def material(name, color, metallic=0.0, roughness=0.5, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = roughness
    if emission:
        b.inputs["Emission Color"].default_value = (*emission, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m

STEEL = material("steel", (0.85, 0.87, 0.92), 1.0, 0.18)
EDGE = material("edge", (1.0, 1.0, 1.0), 1.0, 0.08)
GOLD = material("gold", (1.0, 0.72, 0.18), 1.0, 0.25)
GRIP = material("grip", (0.28, 0.12, 0.05), 0.0, 0.7)
SPARK = material("spark", (1, 0.62, 0.05), 0, 0.5, (1.0, 0.55, 0.0), 1.6)

def blade_mesh():
    # A flat, diamond-section blade with a point, along +Y from 0 to 2.6.
    L, W, T, TIP = 2.2, 0.27, 0.08, 0.5
    verts = [(-W, 0, 0), (W, 0, 0), (0, 0, T), (0, 0, -T),
             (-W, L - TIP, 0), (W, L - TIP, 0), (0, L - TIP, T), (0, L - TIP, -T),
             (0, L, 0)]
    faces = [(0, 2, 6, 4), (2, 1, 5, 6), (1, 3, 7, 5), (3, 0, 4, 7),
             (4, 6, 8), (6, 5, 8), (5, 7, 8), (7, 4, 8), (0, 3, 1, 2)]
    me = bpy.data.meshes.new("blade")
    me.from_pydata(verts, [], faces)
    me.update()
    return me

def sword(name):
    root = bpy.data.objects.new(name, None)
    scene.collection.objects.link(root)
    blade = bpy.data.objects.new(name + "_blade", blade_mesh())
    blade.data.materials.append(STEEL)
    scene.collection.objects.link(blade)
    blade.parent = root
    blade.location = (0, 0.95, 0)
    parts = []
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.9, 0))
    guard = bpy.context.object
    guard.scale = (1.0, 0.17, 0.16)
    guard.data.materials.append(GOLD)
    parts.append(guard)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.11, depth=0.75, location=(0, 0.47, 0),
                                        rotation=(math.pi / 2, 0, 0))
    grip = bpy.context.object
    grip.data.materials.append(GRIP)
    parts.append(grip)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2, location=(0, 0.05, 0))
    pommel = bpy.context.object
    pommel.data.materials.append(GOLD)
    parts.append(pommel)
    for p in parts:
        bpy.ops.object.shade_smooth()
        p.parent = root
    return root

left, right = sword("left"), sword("right")
left.location = (-1.05, -1.35, 0)
right.location = (1.05, -1.35, 0)
right.scale = (-1, 1, 1)  # mirrored

# Swing: both rise from wide apart, meet in an X at the middle frame, bounce
# back. Angle 0 = upright; positive = leaning inwards.
REST, BACK, HIT = 38, 27, 45
def pose(f):
    t = f / FRAMES  # 0..1, looping; the strike lands at t = 0.5
    if t < 0.35:                      # rest -> wind up (ease in-out)
        u = t / 0.35
        a = REST + (BACK - REST) * (0.5 - 0.5 * math.cos(math.pi * u))
    elif t < 0.5:                     # the strike: fast
        u = (t - 0.35) / 0.15
        a = BACK + (HIT - BACK) * (u ** 1.8)
    else:                             # recoil and settle, a damped wobble
        u = (t - 0.5) / 0.5
        a = REST + (HIT - REST) * math.exp(-5 * u) * math.cos(3 * math.pi * u)
    return math.radians(a)

for f in range(FRAMES + 1):
    scene.frame_set(f)
    a = pose(f)
    left.rotation_euler = (0, 0, -a)
    right.rotation_euler = (0, 0, a)
    left.keyframe_insert("rotation_euler", frame=f)
    right.keyframe_insert("rotation_euler", frame=f)

# The spark where the blades cross at the strike: a star of thin rays
# and a small core, all emissive, flashing for a few frames.
hit = math.radians(HIT)
cross_y = -1.35 + 1.05 / math.tan(hit)
rays = []
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.3, location=(0, cross_y, 0.4))
core = bpy.context.object
core.data.materials.append(SPARK)
rays.append((core, (1, 1, 1)))
for i in range(8):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, cross_y, 0.4))
    ray = bpy.context.object
    ray.data.materials.append(SPARK)
    long = 1.8 if i % 2 == 0 else 1.1
    ray.rotation_euler = (0, 0, math.radians(22.5 + 45 * i))
    rays.append((ray, (0.1, long, 0.1)))
sparks = bpy.data.collections.new("sparks")
scene.collection.children.link(sparks)
for obj, _ in rays:
    for c in obj.users_collection: c.objects.unlink(obj)
    sparks.objects.link(obj)
mid = FRAMES // 2
for f in range(FRAMES + 1):
    d = f - mid
    s = {0: 1.0, 1: 0.7, 2: 0.35}.get(d, 0.0)
    for obj, base in rays:
        obj.scale = tuple(max(b * s, 0.001) for b in base)
        obj.hide_render = s == 0
        obj.keyframe_insert("scale", frame=f)
        obj.keyframe_insert("hide_render", frame=f)

# Camera, light, render.
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 3.5
cam = bpy.data.objects.new("cam", cam_data)
cam.location = (0, 0.35, 10)
scene.collection.objects.link(cam)
scene.camera = cam
for loc, energy in (((3, 4, 6), 2.6), ((-4, -2, 5), 1.2)):
    ld = bpy.data.lights.new("sun", "SUN")
    ld.energy = energy
    lo = bpy.data.objects.new("sun", ld)
    lo.location = loc
    lo.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(lo)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.4, 0.42, 0.5, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
scene.world = world

scene.render.engine = "BLENDER_EEVEE"
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
# A dark outline, so the swords read at icon size.
scene.render.use_freestyle = True
scene.render.line_thickness_mode = "ABSOLUTE"
scene.render.line_thickness = SIZE / 64
vl = scene.view_layers[0]
vl.use_freestyle = True
ls = vl.freestyle_settings.linesets.new("outline")
ls.select_by_visibility = True
ls.select_silhouette = ls.select_border = True
ls.select_crease = False
ls.select_by_collection = True
ls.collection = bpy.data.collections["sparks"]
ls.collection_negation = "EXCLUSIVE"
ls.linestyle.color = (0.05, 0.04, 0.03)
ls.linestyle.thickness = SIZE / 110
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.frame_start, scene.frame_end = 0, FRAMES - 1
scene.render.filepath = os.path.join(OUT, "f_")
for obj in bpy.data.objects:
    ad = obj.animation_data
    if ad and ad.action:
        for fc in getattr(ad.action, "fcurves", []):
            for k in fc.keyframe_points: k.interpolation = "LINEAR"
bpy.ops.render.render(animation=True)
