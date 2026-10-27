# Ride or Die - hand-held items (ServerStorage.Items). Each tool keeps the old Handle's axes:
#   Wrench: long along Z, jaw at -Z     DuctTape: roll axis X      Extinguisher: body along X, top at +X
#   Pretzel / Sandwich: flat in XZ      Water / Soda: upright along Y
# The mesh named "Handle" becomes the Tool's Handle; the other meshes are welded to it.
import importlib, json, math, os, sys
sys.path.insert(0, r"C:\Users\Shesn\OneDrive\Documents\Survive the Train\blender")
import rod_lib as L
importlib.reload(L)
from rod_lib import box, cyl, ball, rprism, ring, lathe, torus, pipe, prism, cutter, cut, frame, flat, side, round_poly, transform_objs

L.CUTTERS = "_Cutters_Tools"
for c in ("Tools", L.CUTTERS):
    L.clear_coll(c)
ROOT = L.coll("Tools")
Y = 60.0
GRIPS = {}  # tool -> grip point (Roblox coords) used to set Tool.Grip


def tool(name, x):
    c = L.coll("I_" + name, ROOT)
    L.target(c, "Items." + name)
    return c, (x, Y, 0.0)


# ------------------------------------------------------------------ wrench
c, (x, y, z) = tool("Wrench", 0)
head = cyl("Head", (x - 0.09, y, z - 1.0), (x + 0.09, y, z - 1.0), 0.46, "Steel", segs=24, bevel=0.05, rbx_name="Handle")
cut(head, [cutter("jaw", box, (x, y, z - 1.42), (0.6, 0.38, 0.62), "Black", bevel=0),
           cutter("jaw2", cyl, (x - 0.3, y, z - 1.08), (x + 0.3, y, z - 1.08), 0.19, "Black", segs=16)])
box("Shaft", (x, y, z + 0.05), (0.16, 0.34, 1.7), "Steel", bevel=0.07, rbx_name="Handle")
ringend = cyl("RingEnd", (x - 0.09, y, z + 1.12), (x + 0.09, y, z + 1.12), 0.28, "Steel", segs=20, bevel=0.05, rbx_name="Handle")
cut(ringend, [cutter("ringhole", cyl, (x - 0.3, y, z + 1.12), (x + 0.3, y, z + 1.12), 0.13, "Black", segs=12)])
box("GripSleeve", (x, y, z + 0.42), (0.26, 0.44, 0.95), "Red", bevel=0.12, segs=3, rbx_name="Grip")
for k in range(4):
    box("GripRidge", (x, y, z + 0.06 + 0.24 * k), (0.28, 0.46, 0.06), "RedDark", bevel=0.025, rbx_name="Ridges")
GRIPS["Wrench"] = (x, y, z + 0.42)

# ------------------------------------------------------------------ duct tape (roll axis X)
c, (x, y, z) = tool("DuctTape", 4)
roll_frame = frame((x, y, z), (0, 0, 1), (1, 0, 0))  # local y -> world X
lathe("Roll", [(0.3, -0.23), (0.56, -0.23), (0.56, 0.23), (0.3, 0.23), (0.3, -0.23)], "Tape", rot=roll_frame, segs=28, bevel=0.04, rbx_name="Handle")
lathe("Core", [(0.22, -0.245), (0.31, -0.245), (0.31, 0.245), (0.22, 0.245), (0.22, -0.245)], "Wood", rot=roll_frame, segs=24, bevel=0.02, rbx_name="Core")
box("Tail", (x, y - 0.66, z + 0.12), (0.44, 0.03, 0.32), "Tape", bevel=0.012, rot=(0, -62, 0), rbx_name="Tail")
GRIPS["DuctTape"] = (x, y, z)

# ------------------------------------------------------------------ extinguisher (built upright, then laid along +X)
c, (x, y, z) = tool("Extinguisher", 8)
objs = []
objs.append(lathe("Body", [(0, -0.9), (0.36, -0.9), (0.41, -0.84), (0.41, 0.48), (0.37, 0.64), (0.27, 0.76), (0.14, 0.83), (0, 0.85)],
                  "Red", pos=(x, y, z), segs=28, rbx_name="Handle"))
objs.append(lathe("Band", [(0.4, -0.35), (0.418, -0.35), (0.418, 0.15), (0.4, 0.15), (0.4, -0.35)], "White", pos=(x, y, z), segs=28, rbx_name="Label"))
objs.append(cyl("Neck", (x, y + 0.8, z), (x, y + 1.0, z), 0.12, "Steel", segs=14, bevel=0.03, rbx_name="Valve"))
objs.append(box("Valve", (x, y + 1.04, z - 0.05), (0.22, 0.16, 0.36), "Steel", bevel=0.05, rbx_name="Valve"))
objs.append(box("LeverTop", (x, y + 1.2, z + 0.15), (0.14, 0.06, 0.6), "SteelDark", bevel=0.025, rot=(0, -12, 0), rbx_name="Lever"))
objs.append(box("LeverLow", (x, y + 1.1, z + 0.2), (0.14, 0.06, 0.55), "SteelDark", bevel=0.025, rbx_name="Lever"))
objs.append(cyl("Gauge", (x, y + 0.98, z - 0.24), (x, y + 0.98, z - 0.3), 0.1, "White", segs=14, bevel=0.02, rbx_name="Gauge"))
objs.append(torus("GaugeRim", (x, y + 0.98, z - 0.27), 0.1, 0.025, "Black", rot=(0, 90, 0), segs=14, tsegs=6, rbx_name="Hose"))
objs.append(pipe("Hose", [(x, y + 1.0, z - 0.2), (x, y + 0.95, z - 0.5), (x, y + 0.4, z - 0.52), (x, y - 0.3, z - 0.5)], 0.06, "Black", bend=0.18, rbx_name="Hose"))
objs.append(cyl("Nozzle", (x, y - 0.3, z - 0.5), (x, y - 0.62, z - 0.5), 0.09, "Black", r2=0.06, segs=12, rbx_name="Hose"))
transform_objs(objs, (x, y, z), rz=-90)
GRIPS["Extinguisher"] = (x, y, z)

# ------------------------------------------------------------------ pretzel (flat in XZ)
c, (x, y, z) = tool("Pretzel", 12)
path2d = [(-0.38, -0.2), (-0.12, -0.04), (0.12, 0.14), (0.3, 0.36), (0.47, 0.18), (0.45, -0.12), (0.28, -0.34), (0.0, -0.4),
          (-0.28, -0.34), (-0.45, -0.12), (-0.47, 0.18), (-0.3, 0.36), (-0.12, 0.14), (0.12, -0.04), (0.38, -0.2)]
pts = []
for i, (u, v) in enumerate(path2d):
    lift = 0.06 if i in (1, 2) else (-0.06 if i in (12, 13) else 0.0)
    pts.append((x + u, y + lift, z - v))
pipe("Dough", pts, 0.105, "Pretzel", bend=0.12, segs=14, arc_steps=5, rbx_name="Handle")
salt = [(-0.36, 0.1), (0.36, 0.08), (0.0, -0.36), (-0.2, -0.33), (0.22, -0.3), (0.42, -0.2), (-0.42, -0.22), (0.24, 0.3), (-0.24, 0.3), (0.05, 0.05)]
for u, v in salt:
    box("Salt", (x + u, y + 0.1, z - v), (0.05, 0.04, 0.05), "Salt", bevel=0.012, rot=(37 * u * 10, 0, 0), rbx_name="Salt")
GRIPS["Pretzel"] = (x, y, z)

# ------------------------------------------------------------------ water bottle (upright Y)
c, (x, y, z) = tool("Water", 15)
lathe("Bottle", [(0, -0.55), (0.19, -0.55), (0.22, -0.5), (0.22, 0.12), (0.19, 0.27), (0.11, 0.37), (0.1, 0.41), (0, 0.41)],
      "Water", pos=(x, y, z), segs=24, rbx_name="Handle")
lathe("Label", [(0.21, -0.3), (0.226, -0.3), (0.226, 0.04), (0.21, 0.04), (0.21, -0.3)], "White", pos=(x, y, z), segs=24, rbx_name="Label")
lathe("LabelBand", [(0.21, -0.18), (0.229, -0.18), (0.229, -0.08), (0.21, -0.08), (0.21, -0.18)], "Blue", pos=(x, y, z), segs=24, rbx_name="LabelBand")
cyl("Cap", (x, y + 0.41, z), (x, y + 0.55, z), 0.12, "Cap", segs=16, bevel=0.03, rbx_name="Cap")
GRIPS["Water"] = (x, y, z)

# ------------------------------------------------------------------ soda can (upright Y)
c, (x, y, z) = tool("Soda", 17.5)
lathe("Can", [(0, -0.475), (0.2, -0.475), (0.25, -0.43), (0.25, 0.37), (0.21, 0.455), (0, 0.455)], "Can", pos=(x, y, z), segs=24, rbx_name="Handle")
lathe("Lid", [(0, 0.475), (0.21, 0.475), (0.215, 0.45), (0, 0.45)], "CanTop", pos=(x, y, z), segs=24, rbx_name="Lid")
lathe("Wave", [(0.24, -0.08), (0.254, -0.08), (0.254, 0.06), (0.24, 0.06), (0.24, -0.08)], "White", pos=(x, y, z), segs=24, rbx_name="Wave")
box("Tab", (x + 0.06, y + 0.48, z), (0.16, 0.02, 0.08), "CanTop", bevel=0.008, rbx_name="Lid")
GRIPS["Soda"] = (x, y, z)

# ------------------------------------------------------------------ sandwich (flat in XZ, thickness Y)
c, (x, y, z) = tool("Sandwich", 20.5)
tri = round_poly([(-0.5, -0.45), (0.5, -0.45), (-0.5, 0.5)], 0.12, n=4)
flatf = lambda yy: flat((x, y + yy, z))
prism("BreadLow", tri, 0.15, "Bread", rot=flatf(-0.17), bevel=0.05, rbx_name="Handle")
prism("BreadTop", tri, 0.15, "Bread", rot=flatf(0.17), bevel=0.05, rbx_name="Handle")
prism("Lettuce", round_poly([(-0.56, -0.51), (0.6, -0.51), (-0.56, 0.6)], 0.1, n=3), 0.05, "Lettuce", rot=flatf(-0.07), bevel=0.02, rbx_name="Lettuce")
prism("Cheese", [(-0.47, -0.42), (0.5, -0.42), (-0.47, 0.5)], 0.035, "Cheese", rot=flatf(-0.02), bevel=0.012, rbx_name="Cheese")
prism("Ham", round_poly([(-0.52, -0.47), (0.52, -0.47), (-0.52, 0.52)], 0.12, n=3), 0.05, "Ham", rot=flatf(0.03), bevel=0.02, rbx_name="Ham")
for tx, tz in ((-0.2, 0.2), (0.15, -0.2), (-0.25, -0.22)):
    cyl("Tomato", (x + tx, y + 0.06, z - tz), (x + tx, y + 0.1, z - tz), 0.16, "Tomato", segs=16, rbx_name="Tomato")
GRIPS["Sandwich"] = (x, y, z)

S = r"C:\Users\Shesn\AppData\Local\Temp\claude\C--Users-Shesn--claude-spares-spare-g8PuvN\169de9d2-0e4b-471b-a6aa-6824742abc66\scratchpad\meshes"
os.makedirs(S, exist_ok=True)
with open(os.path.join(S, "tools_grips.json"), "w") as f:
    json.dump(GRIPS, f)
result = {"objects": len(L.all_objects("Tools"))}
