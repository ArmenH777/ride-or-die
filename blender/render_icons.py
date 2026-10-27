# Renders cartoon icons (transparent PNG, dark outline) of the tools/snacks and a gold star, for the UI.
# Runs headless on the saved scene:
#   blender.exe -b blender/RideOrDie.blend --python blender/render_icons.py -- blender/export/icons
import math, os, sys
import bpy
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rod_lib as L

out_dir = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out_dir, exist_ok=True)
SIZE = 256

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.display.render_aa = "16"
sc.view_settings.view_transform = "Standard"
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_cavity = True
sh.cavity_type = "BOTH"
sh.show_specular_highlight = True
sh.show_shadows = False
sh.show_backface_culling = True  # lets the flipped outline shell show only around the edges

black = bpy.data.materials.get("icon_outline") or bpy.data.materials.new("icon_outline")
black.diffuse_color = (0.02, 0.02, 0.04, 1)

# a chunky gold star for the results screen
star_coll = L.coll("I_Star")
L.target(star_coll, "Icons")
pts = []
for i in range(10):
    a = math.pi / 2 + i * math.pi / 5
    r = 1.0 if i % 2 == 0 else 0.45
    pts.append((r * math.cos(a), r * math.sin(a)))
L.prism("Star", pts, 0.32, "Yellow", pos=(0, 80, 0), bevel=0.09, segs=3)


def outline(objs, width):
    for ob in objs:
        if ob.type != "MESH" or ob.get("cutter"):
            continue
        ob.data.materials.append(black)
        m = ob.modifiers.new("Outline", "SOLIDIFY")
        m.thickness = width
        m.offset = 1
        m.use_flip_normals = True
        m.use_rim = False
        m.material_offset = len(ob.data.materials) - 1


def bounds(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for ob in objs:
        if ob.type != "MESH" or ob.get("cutter"):
            continue
        eo = ob.evaluated_get(dg)
        for c in eo.bound_box:
            w = eo.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


# view direction per icon (Blender axes), picked so each item reads well at a glance
VIEWS = {
    "Wrench": (1.0, -0.15, 0.25), "DuctTape": (1.0, -0.6, 0.45), "Extinguisher": (0.25, -1.0, 0.3),
    "Pretzel": (0.15, -0.55, 1.0), "Water": (0.3, -1.0, 0.25), "Soda": (0.3, -1.0, 0.3),
    "Sandwich": (0.4, -0.8, 0.7), "Star": (0.0, -1.0, 0.18),
}
for c in bpy.context.scene.collection.children_recursive:
    c.hide_render = True

cam_data = bpy.data.cameras.new("IconCam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("IconCam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam

for name, view in VIEWS.items():
    coll = bpy.data.collections["I_" + name]
    tools = bpy.data.collections.get("Tools")
    if tools:
        tools.hide_render = name == "Star"
    for c in bpy.context.scene.collection.children_recursive:
        if c.name.startswith("I_"):
            c.hide_render = c is not coll
    objs = [o for o in coll.all_objects if o.type == "MESH" and not o.get("noexport")]
    lo, hi = bounds(objs)
    size = max(hi - lo)
    outline(objs, size * 0.035)
    center = (lo + hi) / 2
    d = Vector(view).normalized()
    cam.location = center + d * size * 4
    q = (-d).to_track_quat("-Z", "X" if name == "Extinguisher" else "Z")
    if name == "Extinguisher":
        q = q @ Quaternion((0, 0, 1), math.pi)  # roll so the valve ends up on top
    cam.rotation_euler = q.to_euler()
    cam_data.ortho_scale = size * 1.22
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("icon", name)
