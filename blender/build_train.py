# Ride or Die - the subway car (workspace.Train), rebuilt as smooth cartoon meshes.
# Layout matches the place exactly (doors, windows, seats, vents, cab) so the scripts keep working.
# Run inside Blender:  exec(open(r".../blender/build_train.py").read())
import importlib, math, sys
sys.path.insert(0, r"C:\Users\Shesn\OneDrive\Documents\Survive the Train\blender")
import rod_lib as L
importlib.reload(L)
from rod_lib import box, cyl, ball, rprism, ring, lathe, torus, pipe, prism, extrude_x, cutter, cut, frame, rot_frame, flat, side, sym, copy_at

L.CUTTERS = "_Cutters_Train"
for c in ("Train", L.CUTTERS):
    L.clear_coll(c)
ROOT = L.coll("Train")


def sub(name, path):
    c = L.coll("T_" + name, ROOT)
    L.target(c, path)
    return c


def tag(ob, **props):
    for k, v in props.items():
        ob[k] = v
    return ob


DOORS = [-20.0, 14.0]
WINDOWS = [-35.08, -27.92, -12.75, -6.25, 0.25, 6.75, 21.92, 29.08]
SIDES = [1, -1]
WIN_Y = 15.75

# car outline (z, y), right half from the bottom up to the roof centre
OUT_R = [(7.75, 9.3), (7.95, 9.6), (8.08, 10.2), (8.15, 11.0), (8.15, 19.6), (8.12, 20.2), (7.95, 20.8),
         (7.6, 21.35), (7.0, 21.8), (6.2, 22.15), (5.0, 22.4), (3.0, 22.55), (0, 22.6)]
OUTLINE = sym(OUT_R)


def openings(s, zc, depth=3.0, doors=True, windows=True, cab=True):
    cs = []
    if windows:
        for wx in WINDOWS:
            cs.append(cutter("cw", rprism, (wx, WIN_Y, zc), 4.3, 4.3, depth, 0.9, "Black", bevel=0))
    if doors:
        for dx in DOORS:
            cs.append(cutter("cd", rprism, (dx, 14.0, zc), 6.0, 11.0, depth, 0.55, "Black", bevel=0))
    if cab:
        cs.append(cutter("cc", rprism, (42.0, 16.5, zc), 8.0, 4.0, depth, 0.9, "Black", bevel=0))
    return cs


# ------------------------------------------------------------------ shell
sub("Shell", "Train.Visual")
for s in SIDES:
    w = box("SideWall", (0, 14.5, 7.45 * s), (96, 10.2, 0.9), "Wall", bevel=0.12, rbx_name="SideWall" + ("R" if s > 0 else "L"))
    tag(w, collide=True)
    cut(w, openings(s, 7.45 * s))

    skin = [(7.9, 9.3), (7.75, 9.3), (7.95, 9.6), (8.08, 10.2), (8.15, 11.0), (8.15, 19.6), (7.9, 19.6)]
    sk = extrude_x("Skin", [(z * s, y) for z, y in skin], -48.0, 48.0, "Body", bevel=0.05, rbx_name="Body")
    cut(sk, openings(s, 7.9 * s))

roof_in = [(7.85, 19.6), (7.82, 20.2), (7.66, 20.75), (7.33, 21.25), (6.8, 21.6), (6.05, 21.9), (4.9, 22.1), (3.0, 22.25), (0, 22.3)]
extrude_x("Roof", sym(OUT_R[4:]) + list(reversed(sym(roof_in))), -48.0, 48.0, "Body", bevel=0.05, rbx_name="Body")

lin_bot = [(7.0, 19.6), (6.95, 19.68), (6.8, 19.8), (5.3, 20.92), (5.1, 21.0), (0, 21.0)]
lin_top = [(7.3, 19.6), (7.3, 19.9), (6.95, 20.05), (5.45, 21.2), (5.2, 21.3), (0, 21.3)]
cl = extrude_x("Lining", sym(lin_bot) + list(reversed(sym(lin_top))), -48.0, 48.0, "Ceiling", bevel=0.04, rbx_name="CeilingLining")
tag(cl, collide=True)

rw = extrude_x("RearWall", OUTLINE, -49.0, -48.0, "Wall", bevel=0.12, rbx_name="RearWall")
tag(rw, collide=True)
cut(rw, [cutter("cg", rprism, (-48.5, 14.6, 0), 3.8, 9.8, 3, 0.5, "Black", bevel=0, rot=side((-48.5, 14.6, 0)))])

fw = extrude_x("FrontWall", OUTLINE, 48.0, 49.0, "BodyDark", bevel=0.12, rbx_name="FrontWall")
tag(fw, collide=True)
cut(fw, [cutter("cws", rprism, (48.5, 16.75, 0), 10.0, 4.5, 3, 1.0, "Black", bevel=0, rot=side((48.5, 16.75, 0)))])

# cab partition (visual; the old blocks stay as invisible colliders)
part_pts = [(7, 10), (7, 21.2), (-7, 21.2), (-7, 10), (-2, 10), (-2, 17.9)]
for i in range(1, 6):
    a = math.radians(180 - 90 * i / 6)
    part_pts.append((-1.4 + 0.6 * math.cos(a), 17.9 + 0.6 * math.sin(a)))
part_pts += [(-1.4, 18.5), (1.4, 18.5)]
for i in range(1, 6):
    a = math.radians(90 - 90 * i / 6)
    part_pts.append((1.4 + 0.6 * math.cos(a), 17.9 + 0.6 * math.sin(a)))
part_pts += [(2, 17.9), (2, 10)]
extrude_x("Partition", part_pts, 33.7, 34.3, "WallShade", bevel=0.08, rbx_name="Partition")

# floor
sub("Floor", "Train.Visual")
box("Floor", (0, 9.875, 0), (96, 0.25, 15.9), "Floor", bevel=0.03, rbx_name="FloorTop")
rprism("Aisle", (-6.0, 10.01, 0), 78, 2.2, 0.04, 1.1, "FloorDot", rot=flat((-6.0, 10.01, 0)), bevel=0, rbx_name="FloorTrim")
for dx in DOORS:
    for s in SIDES:
        box("Threshold", (dx, 10.02, 7.2 * s), (6.0, 0.06, 1.5), "Yellow", bevel=0.02, rbx_name="FloorTrim")
rprism("CabMat", (41.2, 10.02, 0), 12.6, 13.0, 0.05, 1.0, "Charcoal", rot=flat((41.2, 10.02, 0)), bevel=0, rbx_name="FloorTrim")

# livery: lower wall panels + accent stripe (Train.SetModel recolours these by name)
sub("Livery", "Train.Shell")
SEGS = [(-48.0, -23.3), (-16.7, 10.7), (17.3, 33.7)]
for s in SIDES:
    for a, b in SEGS:
        box("WallLow", ((a + b) / 2, 11.55, 6.93 * s), (b - a, 3.1, 0.14), "Lower", bevel=0.05, rbx_name="WallLow")
        box("Stripe", ((a + b) / 2, 13.3, 6.9 * s), (b - a, 0.4, 0.2), "Stripe", bevel=0.07, rbx_name="Stripe")
    st = box("StripeOut", (0, 13.0, 8.2 * s), (97.9, 0.8, 0.12), "Stripe", bevel=0.04, rbx_name="Stripe")
    cut(st, openings(s, 8.2 * s, windows=False, cab=False))
box("StripeFront", (49.03, 13.0, 0), (0.08, 0.8, 16.2), "Stripe", bevel=0.03, rbx_name="Stripe")
box("StripeRear", (-49.03, 13.0, 0), (0.08, 0.8, 16.2), "Stripe", bevel=0.03, rbx_name="Stripe")

# ------------------------------------------------------------------ windows, doors
sub("Windows", "Train.Visual")
for s in SIDES:
    for wx in WINDOWS:
        ring("Gasket", (wx, WIN_Y, 6.97 * s), 4.75, 4.75, 1.05, 0.32, 0.14, "Rubber", rbx_name="Gaskets")
        ring("GasketOut", (wx, WIN_Y, 8.17 * s), 4.75, 4.75, 1.05, 0.3, 0.1, "Rubber", rbx_name="Gaskets")
    ring("CabGasket", (42, 16.5, 6.97 * s), 8.45, 4.45, 1.05, 0.32, 0.14, "Rubber", rbx_name="Gaskets")
    ring("CabGasketOut", (42, 16.5, 8.17 * s), 8.45, 4.45, 1.05, 0.3, 0.1, "Rubber", rbx_name="Gaskets")
    for dx in DOORS:
        ring("DoorFrame", (dx, 14.5, 6.94 * s), 6.5, 10.6, 0.75, 0.3, 0.12, "Steel", rbx_name="DoorFrames")
        ring("DoorFrameOut", (dx, 14.5, 8.19 * s), 6.5, 10.6, 0.75, 0.28, 0.1, "BodyDark", rbx_name="DoorFrames")
ring("WindshieldFrame", (48.95, 16.75, 0), 10.5, 5.0, 1.2, 0.3, 0.14, "Black", rot=side((48.95, 16.75, 0)), rbx_name="Gaskets")
ring("GangwayFrame", (-47.95, 14.5, 0), 4.3, 10.4, 0.7, 0.3, 0.12, "Steel", rot=side((-47.95, 14.5, 0)), rbx_name="DoorFrames")

# templates swapped in for the functional parts (same names, same CFrames)
sub("Templates", "Templates")
win = tag(rprism("Window", (WINDOWS[0], WIN_Y, 7.5), 4.45, 4.45, 0.2, 0.98, "Glass", bevel=0.05, rbx_name="Window"), template=True)
for s in SIDES:
    for wx in WINDOWS:
        if not (s == 1 and wx == WINDOWS[0]):
            copy_at(win, frame((wx, WIN_Y, 7.5 * s)))
cw = tag(rprism("CabWindow", (42, 16.5, 7.5), 8.45, 4.45, 0.2, 0.98, "Glass", bevel=0.05, rbx_name="CabWindow"), template=True)
copy_at(cw, frame((42, 16.5, -7.5)))
tag(rprism("Windshield", (48.5, 16.75, 0), 10.4, 4.9, 0.25, 1.15, "Glass", rot=side((48.5, 16.75, 0)), bevel=0.05, rbx_name="Windshield"), template=True)

# door leaf: 3 x 9.5 x 0.4 with a tall rounded window; glass + rubber edge are separate parts
def door_leaf(x, z, keep):
    p = rprism("DoorPanel", (x, 14.75, z), 3.0, 9.5, 0.36, 0.32, "Steel", bevel=0.06, rbx_name="DoorPanel")
    cut(p, [cutter("cdw", rprism, (x, 16.2, z), 1.95, 3.45, 2, 0.6, "Black", bevel=0)])
    g = rprism("DoorGlass", (x, 16.2, z), 2.05, 3.55, 0.3, 0.62, "GlassDark", bevel=0.04, rbx_name="DoorGlass")
    if keep:
        tag(p, template=True)
        tag(g, template=True)
    else:
        p["noexport"] = True
        g["noexport"] = True
    return p, g


first = True
for dx in DOORS:
    for s in SIDES:
        for lx in (-1.5, 1.5):
            door_leaf(dx + lx, 7.3 * s, first)
            first = False
        for ex in (-0.1, 0.1):
            e = box("DoorEdge", (dx + ex, 14.75, 7.3 * s), (0.2, 9.5, 0.45), "Yellow", bevel=0.08, rbx_name="DoorEdge")
            if dx == DOORS[0] and s == 1 and ex < 0:
                tag(e, template=True)
            else:
                e["noexport"] = True

# ------------------------------------------------------------------ seats
sub("Seats", "Train.Interior")
BENCHES = [(-39.5, -24.0, -38.21, 2.583, 6), (-16.0, 10.0, -14.7, 2.6, 10), (18.0, 33.0, 19.25, 2.5, 6)]
for bi, (a, b, x0, pitch, n) in enumerate(BENCHES):
    for s in SIDES:
        grp = "%d%s" % (bi, "R" if s > 0 else "L")
        pal = "Seat" if bi == 1 else "SeatEnd"
        for k in range(n):
            sx = x0 + pitch * k
            tag(box("Cushion", (sx, 11.74, 5.92 * s), (pitch - 0.14, 0.52, 2.2), pal, bevel=0.2, segs=3, rbx_name="Cushion"), group=grp)
            tag(box("Backrest", (sx, 12.82, 6.72 * s), (pitch - 0.14, 1.7, 0.42), pal, bevel=0.18, segs=3, rot=(0, 8 * s, 0), rbx_name="Cushion"), group=grp)
        base = box("BenchBase", ((a + b) / 2, 10.72, 6.0 * s), (b - a, 1.45, 1.95), "Charcoal", bevel=0.16, rbx_name="BenchBase")
        cyl("BenchTrim", (a + 0.2, 11.38, 5.03 * s), (b - 0.2, 11.38, 5.03 * s), 0.07, "Steel", segs=10, rbx_name="Rails")

# glass windscreens at the bench ends + vertical poles beside the doors
sub("Poles", "Train.Interior")
POLES = [-23.6, -16.4, 10.4, 17.6]
for px in POLES:
    for s in SIDES:
        cyl("Pole", (px, 10.0, 4.6 * s), (px, 21.0, 4.6 * s), 0.17, "Steel", segs=16, rbx_name="Rails")
        cyl("Flange", (px, 10.0, 4.6 * s), (px, 10.16, 4.6 * s), 0.34, "Steel", segs=16, bevel=0.05, rbx_name="Rails")
        cyl("Flange", (px, 20.84, 4.6 * s), (px, 21.0, 4.6 * s), 0.34, "Steel", segs=16, bevel=0.05, rbx_name="Rails")
        rprism("Screen", (px, 14.6, 5.82 * s), 2.25, 5.0, 0.1, 0.45, "Glass", rot=side((px, 14.6, 5.82 * s)), bevel=0.03, rbx_name="Screens")
        pipe("ScreenBar", [(px, 17.35, 7.0 * s), (px, 17.35, 4.6 * s)], 0.1, "Steel", rbx_name="Rails")
        pipe("ScreenBarLow", [(px, 11.95, 7.0 * s), (px, 11.95, 4.6 * s)], 0.1, "Steel", rbx_name="Rails")

# overhead grab rails, hangers, straps
for s in SIDES:
    z = 3.8 * s
    pipe("GrabRail", [(-46, 21.0, z), (-46, 19.3, z), (33, 19.3, z), (33, 21.0, z)], 0.12, "Steel", bend=0.7, rbx_name="Rails")
    for hx in (-33, -20, -7, 6, 19):
        cyl("Hanger", (hx, 19.3, z), (hx, 21.0, z), 0.07, "Steel", segs=10, rbx_name="Rails")
        cyl("HangerMount", (hx, 20.9, z), (hx, 21.0, z), 0.26, "Steel", segs=14, bevel=0.03, rbx_name="Rails")
    x = -44.0
    while x <= 31.5:
        if all(abs(x - hx) > 0.8 for hx in (-33, -20, -7, 6, 19)):
            box("Strap", (x, 18.86, z), (0.07, 0.8, 0.24), "Black", bevel=0.03, rbx_name="Straps")
            torus("Handle", (x, 18.18, z), 0.3, 0.085, "Yellow", rot=(0, 90, 0), segs=16, tsegs=8, rbx_name="Handles")
        x += 3.0

# ------------------------------------------------------------------ ceiling: lights, vents, ad frames
sub("Ceiling", "Train.Visual")
STRIPS = [-42, -33, -24, -15, -6, 3, 12, 21, 30]
strip = tag(rprism("Strip", (STRIPS[0], 20.95, 2.2), 8.0, 0.9, 0.15, 0.45, "Light", rot=flat((STRIPS[0], 20.95, 2.2)), bevel=0.04, rbx_name="Strip"), template=True)
for sx in STRIPS:
    for s in SIDES:
        if not (sx == STRIPS[0] and s == 1):
            copy_at(strip, flat((sx, 20.95, 2.2 * s)))
        ring("LightFrame", (sx, 20.97, 2.2 * s), 8.45, 1.35, 0.67, 0.24, 0.1, "Steel", rot=flat((sx, 20.97, 2.2 * s)), rbx_name="LightFrames")
copy_at(strip, flat((40, 20.95, 0)))

LEAKS, FIRES = [24, -32, -5], [10, -42, -14]
leak = tag(rprism("LeakVent", (24, 20.95, 0), 2.6, 1.6, 0.12, 0.35, "SteelDark", rot=flat((24, 20.95, 0)), bevel=0.03, rbx_name="LeakVent"), template=True)
fire = tag(rprism("FireVent", (10, 20.95, 0), 2.4, 2.4, 0.12, 1.2, "SteelDark", rot=flat((10, 20.95, 0)), n=8, bevel=0.03, rbx_name="FireVent"), template=True)
for i in range(4):
    tag(torus("FireRing", (10, 20.88, 0), 0.25 + 0.24 * i, 0.05, "SteelDark", segs=24, tsegs=6, rbx_name="FireVent"), template=True)
for lx in LEAKS:
    if lx != 24:
        copy_at(leak, flat((lx, 20.95, 0)))
    for i in range(5):
        box("LeakSlot", (lx - 0.9 + 0.45 * i, 20.87, 0), (0.18, 0.05, 1.1), "Black", bevel=0.02, rbx_name="VentSlots")
for fx in FIRES:
    if fx != 10:
        copy_at(fire, flat((fx, 20.95, 0)))
    cyl("FireHub", (fx, 20.86, 0), (fx, 20.9, 0), 0.2, "Black", segs=12, rbx_name="VentSlots")

# ad frames on the sloped cove (ad posters themselves are Parts with SurfaceGuis, made in Studio)
AD_X = WINDOWS + [-43.0]
for s in SIDES:
    t = (0, 0.598, -0.801 * s)     # up the slope
    n_in = (0, -0.801, -0.598 * s)  # into the car
    for ax in AD_X:
        c = (ax + n_in[0] * 0.07, 20.36 + n_in[1] * 0.07, 6.05 * s + n_in[2] * 0.07)
        ring("AdFrame", c, 5.4, 1.75, 0.28, 0.18, 0.1, "Steel", rot=frame(c, (1, 0, 0), t), rbx_name="AdFrames")

# ------------------------------------------------------------------ cab
sub("Cab", "Train.Visual")
for s in SIDES:
    cab = box("CabLining", (41.15, 14.8, 6.93 * s), (13.7, 9.6, 0.14), "BodyDark", bevel=0.05, rbx_name="CabLining")
    cut(cab, [cutter("ccl", rprism, (42.0, 16.5, 6.93 * s), 8.0, 4.0, 2, 0.9, "Black", bevel=0)])
console = prism("Console", [(44.75, 10.0), (48.0, 10.0), (48.0, 14.45), (47.7, 14.55), (44.85, 13.62), (44.62, 13.4)], 8.0, "Charcoal", pos=(0, 0, -2.8), bevel=0.14, rbx_name="Console")
tag(console, collide=True)
box("Bezel", (47.66, 14.52, -3.2), (0.25, 1.95, 4.05), "Black", bevel=0.12, rot=(0, 0, -15), rbx_name="ConsoleTrim")
slope_n = (-math.sin(math.radians(18)), math.cos(math.radians(18)), 0)
for bz, pal in ((-6.2, "Red"), (-5.5, "Green"), (-4.8, "Blue"), (-1.6, "Yellow")):
    p = (46.1, 13.45 + 0.328 * (46.1 - 44.75) + 0.02, bz)
    q = (p[0] + slope_n[0] * 0.14, p[1] + slope_n[1] * 0.14, bz)
    cyl("Button", p, q, 0.22, pal, segs=14, bevel=0.05, rbx_name="Buttons")
cyl("HornRing", (45.2, 13.55, -6.2), (45.2, 13.72, -6.2), 0.55, "Steel", segs=18, bevel=0.05, rbx_name="ConsoleTrim")

# driver's chair (the Seat part stays, invisible)
box("ChairSeat", (43.4, 11.6, -3.2), (2.1, 0.55, 2.1), "Navy", bevel=0.22, segs=3, rbx_name="Chair")
box("ChairBack", (42.25, 13.25, -3.2), (0.5, 2.9, 2.0), "Navy", bevel=0.22, segs=3, rot=(0, 0, 10), rbx_name="Chair")
box("ChairHead", (41.95, 15.15, -3.2), (0.45, 0.8, 1.3), "Navy", bevel=0.2, segs=3, rot=(0, 0, 10), rbx_name="Chair")
for az in (-1.2, 1.2):
    box("Armrest", (43.2, 12.45, -3.2 + az), (1.6, 0.26, 0.3), "Charcoal", bevel=0.1, rbx_name="ChairFrame")
cyl("ChairPost", (43.4, 10.0, -3.2), (43.4, 11.35, -3.2), 0.22, "SteelDark", segs=14, rbx_name="ChairFrame")
cyl("ChairFoot", (43.4, 10.0, -3.2), (43.4, 10.18, -3.2), 0.95, "Charcoal", segs=20, bevel=0.06, rbx_name="ChairFrame")

# lever / switch bases (templates, same size as the old ones)
tag(box("LeverBase", (44.9, 13.5, -0.6), (1.4, 0.5, 0.9), "Black", bevel=0.16, segs=3, rbx_name="LeverBase"), template=True)
tag(box("SwitchBase", (44.6, 13.5, 1.3), (1.0, 0.5, 1.4), "Black", bevel=0.16, segs=3, rbx_name="SwitchBase"), template=True)

# exterior front
sub("Front", "Train.Visual")
box("Bumper", (49.3, 10.0, 0), (0.9, 1.3, 14.4), "Charcoal", bevel=0.35, segs=3, rbx_name="Bumper")
for s in SIDES:
    ring("LampRing", (49.05, 12.0, 4.8 * s), 2.1, 1.5, 0.65, 0.28, 0.2, "Black", rot=side((49.05, 12.0, 4.8 * s)), rbx_name="Gaskets")
lamp = tag(rprism("Headlight", (49.1, 12.0, 4.8), 1.6, 1.0, 0.3, 0.45, "Light", rot=side((49.1, 12.0, 4.8)), bevel=0.05, rbx_name="Headlight"), template=True)
copy_at(lamp, side((49.1, 12.0, -4.8)))
box("DestSign", (49.02, 20.15, 0), (0.15, 1.0, 6.0), "Screen", bevel=0.08, rbx_name="DestSign")
for wz in (-2.0, 2.4):
    pipe("Wiper", [(49.1, 14.75, wz), (49.1, 17.6, wz + 1.6)], 0.07, "Black", rbx_name="Wipers")
box("RoofUnit", (-20, 22.85, 0), (9, 0.8, 4.6), "WallShade", bevel=0.35, segs=3, rbx_name="RoofUnits")
box("RoofUnit", (18, 22.85, 0), (9, 0.8, 4.6), "WallShade", bevel=0.35, segs=3, rbx_name="RoofUnits")
box("Chassis", (0, 8.75, 0), (94, 1.2, 13.2), "Charcoal", bevel=0.3, rbx_name="Chassis")

# ------------------------------------------------------------------ rear: gangway door, snack machine, tool rack, extinguisher
sub("Rear", "Train.Visual")
gd = rprism("GangwayDoor", (-47.95, 14.5, 0), 3.6, 9.0, 0.25, 0.4, "SteelDark", rot=side((-47.95, 14.5, 0)), bevel=0.05, rbx_name="GangwayDoor")
cut(gd, [cutter("cgw", rprism, (-47.95, 16.4, 0), 1.7, 3.0, 2, 0.55, "Black", bevel=0, rot=side((-47.95, 16.4, 0)))])
rprism("GangwayGlass", (-47.95, 16.4, 0), 1.8, 3.1, 0.15, 0.58, "GlassDark", rot=side((-47.95, 16.4, 0)), bevel=0.03, rbx_name="GangwayGlass")
pipe("GangwayHandle", [(-47.8, 13.6, -1.2), (-47.55, 13.6, -1.2), (-47.55, 14.8, -1.2), (-47.8, 14.8, -1.2)], 0.08, "Steel", bend=0.15, rbx_name="Rails")

sm = box("SnackBody", (-46.6, 14.25, -4.4), (2.8, 8.5, 4.6), "Red", bevel=0.38, segs=3, rbx_name="SnackBody")
tag(sm, collide=True)
ring("SnackTrim", (-45.17, 14.25, -4.4), 4.45, 8.2, 0.4, 0.22, 0.1, "Steel", rot=side((-45.17, 14.25, -4.4)), rbx_name="SnackTrim")
box("SnackCap", (-46.6, 18.62, -4.4), (3.0, 0.3, 4.8), "RedDark", bevel=0.14, rbx_name="SnackCap")
for fz in (-6.3, -2.5):
    box("SnackFoot", (-46.6, 10.08, fz), (2.4, 0.16, 0.5), "Charcoal", bevel=0.06, rbx_name="SnackCap")

board = rprism("Pegboard", (-47.85, 15.0, 4.3), 4.4, 5.5, 0.25, 0.35, "Wood", rot=side((-47.85, 15.0, 4.3)), bevel=0.06, rbx_name="Pegboard")
for iy in range(6):
    for iz in range(5):
        py, pz = 12.9 + 0.84 * iy, 2.7 + 0.8 * iz
        if not (13.0 < py < 13.4):
            cyl("Peg", (-47.73, py, pz), (-47.7, py, pz), 0.07, "WoodDark", segs=8, rbx_name="PegHoles")
for hz in (3.2, 5.4):
    pipe("Hook", [(-47.75, 17.0, hz), (-47.25, 17.0, hz), (-47.25, 17.25, hz)], 0.06, "Steel", bend=0.12, rbx_name="Rails")

cab_x = -44.0
box("ExtBox", (cab_x, 15.0, 6.78), (2.6, 4.0, 0.44), "Red", bevel=0.2, segs=3, rbx_name="ExtCabinet")
ring("ExtFrame", (cab_x, 15.0, 6.52), 2.6, 4.0, 0.32, 0.22, 0.12, "RedDark", rbx_name="ExtCabinet")
rprism("ExtGlassNew", (cab_x, 15.0, 6.5), 2.2, 3.6, 0.06, 0.2, "Glass", bevel=0.02, rbx_name="ExtGlass")

# breaker box on the partition (template, same size as the old Box) + lever
bb = tag(rprism("BreakerBody", (33.35, 15.0, -4.6), 2.6, 3.2, 0.7, 0.3, "SteelDark", rot=side((33.35, 15.0, -4.6)), bevel=0.08, rbx_name="BreakerBox"), template=True)
for i in range(5):
    box("Hazard", (32.98, 16.35, -5.45 + 0.42 * i), (0.06, 0.32, 0.2), "Yellow" if i % 2 == 0 else "Black", bevel=0.01, rot=(0, 30, 0), rbx_name="BreakerDecor")
tag(box("BreakerLever", (32.8, 15.3, -4.6), (0.5, 1.3, 0.35), "Green", bevel=0.14, segs=3, rbx_name="BreakerLever"), template=True)
box("LeverSlot", (32.98, 15.0, -4.6), (0.06, 1.9, 0.5), "Black", bevel=0.02, rbx_name="BreakerSlot")

L.target(ROOT, "Train.Visual")
import bpy
result = {"objects": len(L.all_objects("Train")), "cutters": len(L.all_objects("_Cutters"))}
