# Ride or Die - the lobby: "Central Station", a big cartoon subway hall (workspace.Lobby, around z~355).
# North: platform + a parked train with 4 open doors (one per boarding pad). Middle: concourse with the
# two shops, fare gates, central tree + clock. South: spawn, leaderboards and the exit stairs.
import importlib, math, sys
sys.path.insert(0, r"C:\Users\Shesn\OneDrive\Documents\Survive the Train\blender")
import rod_lib as L
importlib.reload(L)
from rod_lib import box, cyl, ball, rprism, ring, lathe, torus, pipe, prism, extrude_x, cutter, cut, frame, rot_frame, flat, side, sym, copy_at

L.CUTTERS = "_Cutters_Lobby"
for c in ("Lobby", L.CUTTERS):
    L.clear_coll(c)
ROOT = L.coll("Lobby")


def sub(name, path="Lobby.Visual"):
    c = L.coll("L_" + name, ROOT)
    L.target(c, path)
    return c


def tag(ob, **props):
    for k, v in props.items():
        ob[k] = v
    return ob


XW = 48.0                  # side walls at x = +-48
ZN, ZS = 294.0, 414.0      # north / south wall faces
WALL_TOP, CROWN = 26.0, 36.0
EDGE = 314.5               # platform edge
PIT = -3.5                 # track bed height
PADS = [-27.0, -9.0, 9.0, 27.0]
PAD_Z = 321.0
GATE_Z = 336.0
PILLARS = [(x, z) for x in (-24, 24) for z in (346, 366, 386)]
RIBS = [301 + 15 * i for i in range(8)]

# ------------------------------------------------------------------ floor + platform + pit
sub("Floor")
tag(box("Floor", (0, 0.5, (EDGE + ZS) / 2), (2 * XW, 1.0, ZS - EDGE), "Marble", bevel=0.05, rbx_name="Floor"), collide=True)
rprism("Inlay", (0, 1.01, 366), 60, 50, 0.04, 6, "TileTrim", rot=flat((0, 1.01, 366)), bevel=0, rbx_name="FloorInlay")
rprism("InlayIn", (0, 1.03, 366), 57.6, 47.6, 0.04, 4.8, "Stone", rot=flat((0, 1.03, 366)), bevel=0, rbx_name="FloorInlayIn")
for i in range(8):
    a = math.radians(45 * i)
    pts = [(0, 0), (1.3 * math.cos(a + 0.5), 1.3 * math.sin(a + 0.5)), (8.0 * math.cos(a), 8.0 * math.sin(a)), (1.3 * math.cos(a - 0.5), 1.3 * math.sin(a - 0.5))]
    prism("Star", pts, 0.04, "TileAccent" if i % 2 == 0 else "TileTrim", rot=flat((0, 1.05, 366)), bevel=0, rbx_name="FloorStar")
box("PlatformCoping", (0, 0.85, EDGE + 0.6), (2 * XW, 0.35, 1.3), "StoneDark", bevel=0.15, rbx_name="Coping")
box("Tactile", (0, 1.02, EDGE + 2.0), (2 * XW, 0.06, 1.4), "Yellow", bevel=0.02, rbx_name="Tactile")
x = -XW + 0.5
while x < XW:
    for dz in (-0.35, 0.35):
        cyl("Bump", (x, 1.04, EDGE + 2.0 + dz), (x, 1.1, EDGE + 2.0 + dz), 0.13, "Yellow", segs=8, rbx_name="Tactile")
    x += 0.8
box("PitWall", (0, (PIT + 0.7) / 2, EDGE - 0.4), (2 * XW, 0.7 - PIT, 0.8), "Concrete", bevel=0.1, rbx_name="PitWall")
box("PitFloor", (0, PIT - 0.5, (ZN + EDGE) / 2), (2 * XW + 30, 1.0, EDGE - ZN), "Gravel", bevel=0.05, rbx_name="PitFloor")
TZ = 305.6  # track centre
for s in (-1, 1):
    box("Rail", (0, PIT + 0.45, TZ + 2.5 * s), (2 * XW + 30, 0.35, 0.3), "Rail", bevel=0.06, rbx_name="Rails")
x = -XW - 14
while x < XW + 14:
    box("Sleeper", (x, PIT + 0.12, TZ), (1.2, 0.3, 7.6), "Sleeper", bevel=0.08, rbx_name="Sleepers")
    x += 2.4

# ------------------------------------------------------------------ walls
sub("Walls")
def side_wall(s):
    xw = XW * s
    w = box("SideWall", (xw + 0.5 * s, 13.0 - 2.25, (ZN + ZS) / 2), (1.0, WALL_TOP + 4.5, ZS - ZN), "Tile", bevel=0.08, rbx_name="SideWall" + ("E" if s > 0 else "W"))
    tag(w, collide=True)
    cut(w, [cutter("portal", rprism, (xw, 6.0, TZ - 0.2), 18.4, 19.0, 4, 5.0, "Black", bevel=0, rot=side((xw, 6.0, TZ - 0.2)))])
    # wainscot, trims, frieze
    box("Wainscot", (xw - 0.1 * s, 3.9, (EDGE + ZS) / 2), (0.25, 4.2, ZS - EDGE), "TileTrim", bevel=0.05, rbx_name="Wainscot")
    box("Skirting", (xw - 0.2 * s, 1.4, (EDGE + ZS) / 2), (0.4, 0.8, ZS - EDGE), "Charcoal", bevel=0.08, rbx_name="Skirting")
    box("Cap", (xw - 0.22 * s, 6.15, (EDGE + ZS) / 2), (0.45, 0.4, ZS - EDGE), "TileAccent", bevel=0.12, rbx_name="TrimGold")
    box("Frieze", (xw - 0.1 * s, 22.0, (ZN + ZS) / 2), (0.25, 2.0, ZS - ZN), "TileTrim", bevel=0.05, rbx_name="Wainscot")
    box("FriezeLine", (xw - 0.2 * s, 20.8, (ZN + ZS) / 2), (0.3, 0.3, ZS - ZN), "TileAccent", bevel=0.1, rbx_name="TrimGold")
    box("Cornice", (xw - 0.45 * s, WALL_TOP - 0.3, (ZN + ZS) / 2), (0.9, 0.6, ZS - ZN), "Stone", bevel=0.2, rbx_name="Cornice")
    z = ZN + 2.0
    while z < ZS - 1:
        c = (xw - 0.25 * s, 22.0, z)
        rprism("Diamond", c, 0.9, 0.9, 0.12, 0.15, "TileAccent", rot=frame(c, (0, 0.7071, 0.7071), (0, 0.7071, -0.7071)), bevel=0.03, rbx_name="TrimGold")
        z += 3.0
    # pilasters at every rib
    for rz in RIBS:
        box("Pilaster", (xw - 0.6 * s, 12.5, rz), (1.2, 23.0, 2.6), "Stone", bevel=0.15, rbx_name="Pilasters")
        box("PilasterBase", (xw - 0.75 * s, 1.9, rz), (1.5, 1.8, 3.1), "StoneDark", bevel=0.15, rbx_name="Pilasters2")
        box("Capital", (xw - 0.8 * s, 23.7, rz), (1.6, 1.0, 3.2), "StoneDark", bevel=0.2, rbx_name="Pilasters2")
    # station name plaques between pilasters (text added in Studio)
    for pz in (338.5, 383.5, 398.5):
        ring("Plaque", (xw - 0.3 * s, 14.5, pz), 9.0, 2.6, 0.5, 0.35, 0.2, "TileTrim", rot=side((xw - 0.3 * s, 14.5, pz)), rbx_name="Plaques")


for s in (-1, 1):
    side_wall(s)

nw = box("NorthWall", (0, 11.0, ZN - 0.5), (2 * XW + 2, 30.0, 1.0), "Tile", bevel=0.08, rbx_name="NorthWall")
tag(nw, collide=True)
box("NorthWainscot", (0, 3.0 + PIT / 2, ZN + 0.12), (2 * XW, 6.5 - PIT, 0.25), "TileTrim", bevel=0.05, rbx_name="Wainscot")
box("NorthFrieze", (0, 22.0, ZN + 0.12), (2 * XW, 2.0, 0.25), "TileTrim", bevel=0.05, rbx_name="Wainscot")
box("NorthCornice", (0, WALL_TOP - 0.3, ZN + 0.45), (2 * XW, 0.6, 0.9), "Stone", bevel=0.2, rbx_name="Cornice")
ring("TitleFrame", (0, 19.0, ZN + 0.35), 33.0, 8.0, 1.2, 0.7, 0.4, "TileAccent", rbx_name="TrimGold")
rprism("TitleBack", (0, 19.0, ZN + 0.2), 31.8, 6.8, 0.2, 0.8, "Navy", bevel=0.04, rbx_name="TitleBack")

# south wall with the exit arch
for s in (-1, 1):
    sw = box("SouthWall", (s * 29.5, 13.0, ZS + 0.5), (37.0, 26.0, 1.0), "Tile", bevel=0.08, rbx_name="SouthWall" + ("E" if s > 0 else "W"))
    tag(sw, collide=True)
    box("SouthWainscot", (s * 29.5, 3.9, ZS - 0.12), (37.0, 4.2, 0.25), "TileTrim", bevel=0.05, rbx_name="Wainscot")
    box("SouthCap", (s * 29.5, 6.15, ZS - 0.22), (37.0, 0.4, 0.45), "TileAccent", bevel=0.12, rbx_name="TrimGold")
    box("SouthFrieze", (s * 29.5, 22.0, ZS - 0.12), (37.0, 2.0, 0.25), "TileTrim", bevel=0.05, rbx_name="Wainscot")
st = box("SouthTop", (0, 22.0, ZS + 0.5), (22.0, 8.0, 1.0), "Tile", bevel=0.08, rbx_name="SouthTop")
tag(st, collide=True)
arch = ring("ExitArch", (0, 9.0, ZS - 0.3), 23.0, 18.5, 4.5, 1.4, 0.8, "Stone", bevel=0.15, rbx_name="ExitArch")
box("SouthCornice", (0, WALL_TOP - 0.3, ZS - 0.45), (2 * XW, 0.6, 0.9), "Stone", bevel=0.2, rbx_name="Cornice")

# ------------------------------------------------------------------ vaulted ceiling + ribs + lamps
sub("Ceiling")
R = (XW ** 2 + (CROWN - WALL_TOP) ** 2) / (2 * (CROWN - WALL_TOP))
CY = CROWN - R


def arc_pts(r, n=24, x0=-XW - 1, x1=XW + 1):
    pts = []
    for i in range(n + 1):
        xx = x0 + (x1 - x0) * i / n
        pts.append((xx, CY + math.sqrt(max(0.0, r * r - xx * xx))))
    return pts


inner = arc_pts(R)
outer = arc_pts(R + 1.0)
vault = prism("Vault", inner[::-1] + outer, ZS - ZN + 2, "Ceiling", pos=(0, 0, (ZN + ZS) / 2), bevel=0, rbx_name="Vault")
for rz in RIBS:
    rib_in = arc_pts(R - 0.9, n=24, x0=-XW, x1=XW)
    rib_out = arc_pts(R + 0.2, n=24, x0=-XW, x1=XW)
    prism("Rib", rib_in[::-1] + rib_out, 2.2, "TileTrim", pos=(0, 0, rz), bevel=0.15, rbx_name="Ribs")
    for lx in (-18.0, 0.0, 18.0):
        top = CY + math.sqrt(R * R - lx * lx) - 0.9
        cyl("LampCable", (lx, 23.4, rz), (lx, top, rz), 0.06, "Black", segs=8, rbx_name="Cables")
        lathe("LampShade", [(0.25, 0.9), (0.45, 0.85), (1.5, 0.05), (1.65, -0.1), (1.5, -0.12), (0.4, 0.65), (0.25, 0.7)], "TileAccent", pos=(lx, 22.5, rz), segs=20, rbx_name="LampShades")
        ball("Bulb", (lx, 22.55, rz), 0.55, "Light", segs=12, rings=8, rbx_name="Bulbs")
# cornice along the vault spring line is on the walls; add a light cove strip along each side
for s in (-1, 1):
    box("Cove", (s * (XW - 1.4), WALL_TOP + 0.15, (ZN + ZS) / 2), (0.6, 0.3, ZS - ZN - 2), "LightBlue", bevel=0.1, rbx_name="CoveLight")

# ------------------------------------------------------------------ the parked train (exterior + simple lit interior)
sub("Train")
OY, OZ = -8.8, TZ
X0, X1 = -62.0, 62.0
DOORS = PADS
WINS = [-41.5, -35.5, -18.0, -2.75, 2.75, 18.0, 35.5, 41.5]


def P(x, y, z):
    return (x, y + OY, z + OZ)


OUT_R = [(7.75, 9.3), (7.95, 9.6), (8.08, 10.2), (8.15, 11.0), (8.15, 19.6), (8.12, 20.2), (7.95, 20.8),
         (7.6, 21.35), (7.0, 21.8), (6.2, 22.15), (5.0, 22.4), (3.0, 22.55), (0, 22.6)]


def prof(pts):
    return [(z + OZ, y + OY) for z, y in pts]


def car_openings(s, zc, depth=3.0, doors=True):
    cs = [cutter("lw", rprism, P(wx, 15.75, zc), 4.3, 4.3, depth, 0.9, "Black", bevel=0) for wx in WINS]
    if doors:
        cs += [cutter("ld", rprism, P(dx, 14.0, zc), 6.0, 11.0, depth, 0.55, "Black", bevel=0) for dx in DOORS]
    return cs


for s in (1, -1):
    skin = [(7.0, 9.3), (7.75, 9.3), (7.95, 9.6), (8.08, 10.2), (8.15, 11.0), (8.15, 19.6), (7.0, 19.6)]
    skin[0], skin[-1] = (7.9, 9.3), (7.9, 19.6)
    sk = extrude_x("TrainSide", prof([(z * s, y) for z, y in skin]), X0, X1, "Body", bevel=0.06, rbx_name="TrainBody")
    cut(sk, car_openings(s, 7.6 * s, doors=(s > 0)))
    st = box("TrainStripe", P(0, 13.0, 8.2 * s), (X1 - X0, 0.8, 0.12), "Purple", bevel=0.04, rbx_name="TrainStripe")
    if s > 0:
        cut(st, [cutter("lds", rprism, P(dx, 14.0, 8.2), 6.0, 11.0, 2, 0.55, "Black", bevel=0) for dx in DOORS])
    for wx in WINS:
        ring("TGasket", P(wx, 15.75, 8.17 * s), 4.75, 4.75, 1.05, 0.3, 0.1, "Rubber", rbx_name="TrainGaskets")
        rprism("TGlass", P(wx, 15.75, 7.5 * s), 4.45, 4.45, 0.15, 0.98, "Glass", bevel=0.04, rbx_name="TrainGlass")
roof_in = [(7.85, 19.6), (7.82, 20.2), (7.66, 20.75), (7.33, 21.25), (6.8, 21.6), (6.05, 21.9), (4.9, 22.1), (3.0, 22.25), (0, 22.3)]
extrude_x("TrainRoof", prof(sym(OUT_R[4:])) + list(reversed(prof(sym(roof_in)))), X0, X1, "Body", bevel=0.05, rbx_name="TrainBody")
for rx in (-40, -12, 16, 44):
    box("TRoofUnit", P(rx, 22.85, 0), (9, 0.8, 4.6), "WallShade", bevel=0.35, segs=3, rbx_name="TrainRoofUnits")
box("TChassis", P(0, 8.6, 0), (X1 - X0, 1.4, 13.2), "Charcoal", bevel=0.3, rbx_name="TrainChassis")
for bx in (-48, -34, 34, 48):
    box("Bogie", P(bx, 7.6, 0), (7.5, 1.4, 9.0), "BodyDark", bevel=0.3, rbx_name="Bogies")
    for wx in (bx - 2.2, bx + 2.2):
        for s in (-1, 1):
            cyl("Wheel", P(wx, 7.08, 2.5 * s + 0.35 * s), P(wx, 7.08, 2.5 * s - 0.25 * s), 1.15, "SteelDark", segs=20, bevel=0.08, rbx_name="Wheels")
for dx in DOORS:
    ring("TDoorFrame", P(dx, 14.5, 8.19), 6.5, 10.6, 0.75, 0.3, 0.1, "BodyDark", rbx_name="TrainDoorFrames")
    for ex in (-2.9, 2.9):
        box("TDoorEdge", P(dx + ex, 14.75, 7.35), (0.22, 9.5, 0.5), "Yellow", bevel=0.08, rbx_name="TrainDoorEdges")
    box("TThreshold", P(dx, 10.02, 7.4), (6.0, 0.06, 1.3), "Yellow", bevel=0.02, rbx_name="TrainTrim")
# interior (what you see through the open doors and windows)
box("TFloor", P(0, 9.875, 0), (X1 - X0, 0.25, 15.0), "Floor", bevel=0.03, rbx_name="TrainFloor")
for s in (1, -1):
    wl = box("TWall", P(0, 14.5, 7.45 * s), (X1 - X0, 10.2, 0.9), "Wall", bevel=0.1, rbx_name="TrainInWall")
    cut(wl, car_openings(s, 7.45 * s, doors=(s > 0)))
    wlow = box("TWallLow", P(0, 11.55, 6.93 * s), (X1 - X0, 3.1, 0.14), "Lower", bevel=0.05, rbx_name="TrainLower")
    tl = box("TWallStripe", P(0, 13.3, 6.9 * s), (X1 - X0, 0.4, 0.2), "Purple", bevel=0.07, rbx_name="TrainStripe")
    if s > 0:
        for ob in (wlow, tl):
            cut(ob, [cutter("ldi", rprism, P(dx, 14.0, 6.9), 6.0, 11.0, 2, 0.55, "Black", bevel=0) for dx in DOORS])
lin_bot = [(7.0, 19.6), (6.95, 19.68), (6.8, 19.8), (5.3, 20.92), (5.1, 21.0), (0, 21.0)]
lin_top = [(7.3, 19.6), (7.3, 19.9), (6.95, 20.05), (5.45, 21.2), (5.2, 21.3), (0, 21.3)]
extrude_x("TCeiling", prof(sym(lin_bot)) + list(reversed(prof(sym(lin_top)))), X0, X1, "Ceiling", bevel=0.04, rbx_name="TrainInCeiling")
for lx in range(-54, 60, 9):
    for s in (1, -1):
        rprism("TStrip", P(lx, 20.95, 2.2 * s), 8.0, 0.9, 0.15, 0.45, "Light", rot=flat(P(lx, 20.95, 2.2 * s)), bevel=0.04, rbx_name="TrainLights")
# seats on the far (north) wall, between the doors
for a, b in ((-56, -31), (-23, -13), (-5, 5), (13, 23), (31, 56)):
    n = int((b - a) // 2.6)
    for k in range(n):
        sx = a + 1.3 + 2.6 * k + ((b - a) - 2.6 * n) / 2
        box("TCushion", P(sx, 11.74, -5.92), (2.46, 0.52, 2.2), "Seat", bevel=0.2, segs=3, rbx_name="TrainSeats")
        box("TBack", P(sx, 12.82, -6.72), (2.46, 1.7, 0.42), "Seat", bevel=0.18, segs=3, rot=(0, -8, 0), rbx_name="TrainSeats")
    box("TBench", P((a + b) / 2, 10.72, -6.0), (b - a, 1.45, 1.95), "Charcoal", bevel=0.16, rbx_name="TrainBench")
for dx in DOORS:
    for px in (dx - 3.6, dx + 3.6):
        cyl("TPole", P(px, 10.0, 4.6), P(px, 21.0, 4.6), 0.17, "Steel", segs=14, rbx_name="TrainPoles")
        cyl("TPole2", P(px, 10.0, -4.6), P(px, 21.0, -4.6), 0.17, "Steel", segs=14, rbx_name="TrainPoles")
for s in (1, -1):
    pipe("TRail", [P(-60, 19.3, 3.8 * s), P(60, 19.3, 3.8 * s)], 0.12, "Steel", rbx_name="TrainPoles")

# tunnel portals: dark tubes the train disappears into
for s in (-1, 1):
    xw = XW * s
    ring("PortalArch", (xw - 0.6 * s, 6.0, TZ - 0.2), 21.4, 20.4, 6.0, 1.6, 1.2, "Stone", rot=side((xw - 0.6 * s, 6.0, TZ - 0.2)), bevel=0.15, rbx_name="Portals")
    box("TunnelDark", (xw + 9 * s, 5.5, TZ), (16, 22, 24), "Black", bevel=0, rbx_name="TunnelDark")

# ------------------------------------------------------------------ platform: pads, boards, edge barrier posts
sub("Platform")
pad = tag(rprism("Pad", (PADS[0], 1.35, PAD_Z), 11.0, 11.0, 0.3, 1.6, "Purple", rot=flat((PADS[0], 1.35, PAD_Z)), bevel=0.08, rbx_name="Pad"), template=True)
for px in PADS:
    if px != PADS[0]:
        copy_at(pad, flat((px, 1.35, PAD_Z)))
    ring("PadRing", (px, 1.2, PAD_Z), 12.2, 12.2, 2.1, 0.6, 0.35, "TileAccent", rot=flat((px, 1.2, PAD_Z)), bevel=0.1, rbx_name="PadRings")
    # board housing, hung from the vault on two cables
    bz = 328.6
    ring("BoardFrame", (px, 13.8, bz), 13.8, 6.4, 0.9, 0.45, 0.9, "Charcoal", bevel=0.15, rbx_name="BoardFrames")
    ring("BoardTrim", (px, 13.8, bz + 0.47), 13.0, 5.6, 0.6, 0.18, 0.06, "TileAccent", bevel=0.03, rbx_name="TrimGold")
    for cx in (px - 5.5, px + 5.5):
        top = CY + math.sqrt(R * R - cx * cx)
        cyl("BoardCable", (cx, 16.9, bz), (cx, top, bz), 0.07, "Black", segs=8, rbx_name="Cables")
board = tag(rprism("Board", (PADS[0], 13.8, 328.6), 13.0, 5.6, 0.6, 0.5, "Screen", bevel=0.06, rbx_name="Board"), template=True)
for px in PADS[1:]:
    copy_at(board, frame((px, 13.8, 328.6)))

# fare gates
sub("Gates")
gx = -36.0
while gx <= 36.01:
    box("GateBody", (gx, 2.8, GATE_Z), (1.3, 3.6, 3.0), "Charcoal", bevel=0.3, segs=3, rbx_name="GateBodies")
    box("GateTop", (gx, 4.75, GATE_Z), (1.5, 0.3, 3.2), "Steel", bevel=0.12, rbx_name="GateTops")
    box("GateLight", (gx, 4.95, GATE_Z - 0.9), (0.6, 0.12, 0.6), "Green", bevel=0.05, rbx_name="GateLights")
    for fx in (gx - 0.72, gx + 0.72):  # flaps folded open beside the cabinet
        rprism("Flap", (fx, 3.0, GATE_Z + 0.2), 2.2, 2.0, 0.1, 0.5, "Glass", rot=side((fx, 3.0, GATE_Z + 0.2)), bevel=0.03, rbx_name="GateFlaps")
    gx += 6.0
for s in (-1, 1):
    for gx in (39.0, 42.0, 45.0):
        cyl("RailPost", (s * gx, 1.0, GATE_Z), (s * gx, 4.2, GATE_Z), 0.18, "Steel", segs=12, rbx_name="Railing")
    pipe("Railing", [(s * 36.7, 4.2, GATE_Z), (s * 47.8, 4.2, GATE_Z)], 0.14, "Steel", rbx_name="Railing")
    rprism("RailGlass", (s * 42.2, 2.6, GATE_Z), 10.8, 2.6, 0.1, 0.3, "Glass", bevel=0.02, rbx_name="GateFlaps")

# ------------------------------------------------------------------ shops (storefronts on the side walls)
sub("Shops")


def storefront(s, pal, name):
    xw = XW * s
    zc = 363.0
    # back wall panel, side columns, fascia, striped awning
    box(name + "Back", (xw - 0.4 * s, 7.0, zc), (0.3, 12.0, 24.0), "WoodDark", bevel=0.05, rbx_name=name + "Back")
    for cz in (zc - 12.5, zc + 12.5):
        box(name + "Column", (xw - 2.0 * s, 8.0, cz), (4.0, 14.0, 1.4), pal, bevel=0.3, segs=3, rbx_name=name + "Frame")
    box(name + "Fascia", (xw - 2.6 * s, 14.2, zc), (2.6, 3.2, 26.4), pal, bevel=0.35, segs=3, rbx_name=name + "Frame")
    for i in range(10):
        stripe_pal = "White" if i % 2 == 0 else pal
        z0 = zc - 12 + 2.4 * i + 1.2
        box(name + "Awning", (xw - 5.0 * s, 11.6, z0), (4.2, 0.35, 2.4), stripe_pal, bevel=0.05, rot=(0, 0, 16 * s), rbx_name=name + "Awning")
        box(name + "Valance", (xw - 7.05 * s, 10.75, z0), (0.22, 0.7, 2.4), stripe_pal, bevel=0.08, rbx_name=name + "Awning")
    # shelves with merchandise
    for sy in (4.0, 7.0, 10.0):
        box(name + "Shelf", (xw - 1.1 * s, sy, zc), (1.6, 0.25, 22.0), "Wood", bevel=0.08, rbx_name=name + "Shelves")
    # counter (the Counter part with the ShopPrompt is moved here in Studio)
    tag(box(name + "Counter", (xw - 10.0 * s, 2.5, zc), (3.0, 3.0, 10.0), pal, bevel=0.35, segs=3, rbx_name=name + "Counter"), collide=True)
    box(name + "CounterTop", (xw - 10.0 * s, 4.15, zc), (3.6, 0.35, 10.6), "Marble", bevel=0.15, rbx_name=name + "CounterTop")
    box(name + "CounterBase", (xw - 10.0 * s, 1.15, zc), (3.2, 0.3, 10.2), "Charcoal", bevel=0.1, rbx_name=name + "CounterTop")
    box(name + "Register", (xw - 10.3 * s, 4.75, zc + 3.5), (1.4, 0.9, 1.6), "Charcoal", bevel=0.2, rbx_name=name + "Register")
    box(name + "RegScreen", (xw - 10.9 * s, 5.5, zc + 3.5), (0.15, 0.7, 1.2), "LightBlue", bevel=0.05, rot=(0, 0, 20 * s), rbx_name=name + "RegScreen")


storefront(-1, "Orange", "TrainYard")
storefront(1, "Green", "PerkShop")

# toy trains on the Train Yard shelves (one per livery colour)
LIVERY = ["Purple", "Blue", "Teal", "Red", "Green"]
for row, sy in enumerate((4.0, 7.0, 10.0)):
    for k in range(3):
        zc = 363.0 - 7 + 7 * k
        pal = LIVERY[(row * 3 + k) % len(LIVERY)]
        x = -XW + 1.1
        box("ToyBody", (x, sy + 0.75, zc), (1.1, 1.2, 4.4), "Body", bevel=0.4, segs=3, rbx_name="ToyTrains")
        box("ToyStripe", (x, sy + 0.62, zc), (1.16, 0.25, 4.3), pal, bevel=0.1, rbx_name="ToyStripes" + pal)
        box("ToyWindow", (x, sy + 0.98, zc), (1.16, 0.32, 3.6), "GlassDark", bevel=0.1, rbx_name="ToyWindows")
# perk goodies on the Perk Shop shelves: sneakers, backpacks, speech bubbles, gloves
for row, sy in enumerate((4.0, 7.0, 10.0)):
    for k in range(4):
        zc = 363.0 - 8.4 + 5.6 * k
        x = XW - 1.2
        kind = (row + k) % 4
        if kind == 0:  # sneaker
            box("Shoe", (x, sy + 0.4, zc), (0.9, 0.55, 1.6), "Red", bevel=0.25, segs=3, rbx_name="Goodies")
            box("Sole", (x, sy + 0.2, zc + 0.05), (0.95, 0.18, 1.7), "White", bevel=0.08, rbx_name="GoodiesWhite")
        elif kind == 1:  # backpack
            box("Pack", (x, sy + 0.85, zc), (0.9, 1.5, 1.3), "Blue", bevel=0.4, segs=3, rbx_name="GoodiesBlue")
            box("Pocket", (x - 0.45, sy + 0.6, zc), (0.3, 0.6, 0.9), "Yellow", bevel=0.14, rbx_name="GoodiesYellow")
        elif kind == 2:  # speech bubble
            cyl("Bubble", (x - 0.15, sy + 1.1, zc), (x + 0.15, sy + 1.1, zc), 0.75, "White", segs=20, bevel=0.1, rbx_name="GoodiesWhite")
            for d in (-0.3, 0.0, 0.3):
                ball("Dot", (x - 0.18, sy + 1.1, zc + d), 0.1, "Charcoal", segs=8, rings=6, rbx_name="GoodiesDark")
        else:  # glove
            box("Glove", (x, sy + 0.8, zc), (0.5, 1.2, 1.0), "Yellow", bevel=0.22, segs=3, rbx_name="GoodiesYellow")
            box("Thumb", (x, sy + 0.7, zc + 0.6), (0.45, 0.6, 0.35), "Yellow", bevel=0.15, rot=(0, 30, 0), rbx_name="GoodiesYellow")

# ------------------------------------------------------------------ concourse dressing
sub("Concourse")
for px, pz in PILLARS:
    lathe("Pillar", [(0, 0), (2.2, 0), (2.2, 0.6), (1.9, 1.0), (1.6, 1.4), (1.5, 1.6), (1.5, 29.4), (1.8, 29.9), (2.2, 30.8), (2.5, 32.8), (0, 32.8)],
          "Stone", pos=(px, 1.0, pz), segs=24, rbx_name="Pillars")
    lathe("PillarBand", [(1.45, 5.0), (1.62, 5.0), (1.62, 5.6), (1.45, 5.6)], "TileTrim", pos=(px, 1.0, pz), segs=24, rbx_name="PillarBands")
    lathe("PillarGold", [(1.45, 5.75), (1.6, 5.75), (1.6, 5.95), (1.45, 5.95)], "TileAccent", pos=(px, 1.0, pz), segs=24, rbx_name="TrimGold")
    # wrap-around bench + planter at the pillar foot
    lathe("Planter", [(2.3, 0), (3.6, 0), (3.8, 0.4), (3.8, 1.9), (3.5, 2.1), (2.3, 2.1)], "TileTrim", pos=(px, 1.0, pz), segs=28, bevel=0.0, rbx_name="Planters")
    lathe("PlanterTop", [(2.25, 2.05), (3.95, 2.05), (3.95, 2.35), (2.25, 2.35)], "Wood", pos=(px, 1.0, pz), segs=28, rbx_name="PlanterTops")
    for i in range(7):
        a = 2 * math.pi * i / 7
        ball("Bush", (px + 2.9 * math.cos(a), 3.6, pz + 2.9 * math.sin(a)), 0.95, "Plant" if i % 2 else "PlantDark", segs=12, rings=8, rbx_name="Bushes" + ("A" if i % 2 else "B"))

# central tree with a round bench, and a four-faced clock hanging above it
TX, TZC = 0.0, 366.0
lathe("TreeBench", [(5.0, 0), (6.6, 0), (6.6, 1.6), (6.9, 1.7), (6.9, 2.0), (4.7, 2.0), (4.7, 1.7), (5.0, 1.6)], "Wood", pos=(TX, 1.0, TZC), segs=36, rbx_name="TreeBench")
lathe("TreePlanter", [(0, 0), (4.8, 0), (4.8, 3.0), (4.4, 3.3), (0, 3.3)], "TileTrim", pos=(TX, 1.0, TZC), segs=36, rbx_name="TreePlanter")
lathe("TreeSoil", [(0, 3.25), (4.3, 3.25), (4.3, 3.4), (0, 3.4)], "WoodDark", pos=(TX, 1.0, TZC), segs=36, rbx_name="TreeSoil")
lathe("Trunk", [(0, 0), (1.3, 0), (1.0, 2.0), (0.85, 6.0), (0.7, 9.0), (0, 9.0)], "Wood", pos=(TX, 4.3, TZC), segs=14, rbx_name="Trunk")
for (bx, by, bz, br) in ((0, 15.0, 0, 4.2), (2.8, 13.2, 1.5, 3.0), (-2.9, 13.4, -1.0, 3.1), (0.8, 13.0, -3.0, 2.9), (-1.2, 12.8, 3.0, 2.8), (0, 17.6, 0.4, 2.6)):
    ball("Canopy", (TX + bx, by, TZC + bz), br, "Plant" if br > 2.95 else "PlantDark", segs=16, rings=10, rbx_name="Canopy" + ("A" if br > 2.95 else "B"))
CLK = 24.5
box("ClockBox", (TX, CLK, TZC), (4.6, 4.6, 4.6), "TileTrim", bevel=0.5, segs=3, rbx_name="ClockBox")
for fx, fz in ((0, 2.33), (0, -2.33), (2.33, 0), (-2.33, 0)):
    c = (TX + fx, CLK, TZC + fz)
    cyl("ClockFace", c, (c[0] + fx * 0.05, c[1], c[2] + fz * 0.05), 1.85, "White", segs=28, bevel=0.05, rbx_name="ClockFaces")
    rc = (c[0] + fx * 0.02, c[1], c[2] + fz * 0.02)
    torus("ClockRim", rc, 1.9, 0.14, "TileAccent", rot=rot_frame(rc, rx=90) if fx == 0 else rot_frame(rc, rz=-90), segs=28, tsegs=8, rbx_name="TrimGold")
    for hand, ang, ln in (("H", 60, 0.9), ("M", -30, 1.4)):
        a = math.radians(ang)
        ux = (fz != 0) * math.cos(a) * (1 if fz > 0 else -1)
        uz = (fx != 0) * math.cos(a) * (-1 if fx > 0 else 1)
        e = (c[0] + fx * 0.08 + ux * ln, c[1] + math.sin(a) * ln, c[2] + fz * 0.08 + uz * ln)
        pipe("Hand" + hand, [(c[0] + fx * 0.08, c[1], c[2] + fz * 0.08), e], 0.07, "Black", rbx_name="ClockHands")
cyl("ClockRod", (TX, CLK + 2.3, TZC), (TX, CROWN - 0.3, TZC), 0.18, "TileAccent", segs=10, rbx_name="TrimGold")
box("ClockCap", (TX, CLK + 2.5, TZC), (2.4, 0.5, 2.4), "TileAccent", bevel=0.2, rbx_name="TrimGold")
box("ClockFoot", (TX, CLK - 2.5, TZC), (2.4, 0.5, 2.4), "TileAccent", bevel=0.2, rbx_name="TrimGold")

# benches (wood slats on steel legs) and bins
def bench(x, z, along_z=True):
    for i in range(4):
        dz = -0.9 + 0.6 * i
        if along_z:
            box("Slat", (x + dz, 2.4, z), (0.45, 0.22, 7.0), "Wood", bevel=0.08, rbx_name="BenchSlats")
        else:
            box("Slat", (x, 2.4, z + dz), (7.0, 0.22, 0.45), "Wood", bevel=0.08, rbx_name="BenchSlats")
    for d in (-2.8, 2.8):
        p = (x, 1.6, z + d) if along_z else (x + d, 1.6, z)
        box("Leg", p, (2.2, 1.3, 0.3) if along_z else (0.3, 1.3, 2.2), "Charcoal", bevel=0.1, rbx_name="BenchLegs")


for bx_, bz_ in ((-24, 356), (-24, 376), (24, 356), (24, 376)):
    bench(bx_, bz_)
for s in (-1, 1):
    bench(s * 40.5, 397, along_z=True)
    bench(s * 40.5, 340.5, along_z=True)
    lathe("Bin", [(0, 0), (0.9, 0), (1.0, 0.2), (1.0, 2.6), (1.1, 2.7), (1.1, 2.9), (0, 2.9)], "TileTrim", pos=(s * 40.5, 1.0, 392.5), segs=18, rbx_name="Bins")
    lathe("BinLid", [(0, 2.9), (1.12, 2.9), (1.12, 3.1), (0.5, 3.35), (0, 3.35)], "Steel", pos=(s * 40.5, 1.0, 392.5), segs=18, rbx_name="BinLids")
    # vending machines in the south corners
    vm = box("Vending", (s * 44.0, 5.0, 409.5), (5.0, 8.0, 3.0), "Red" if s < 0 else "Blue", bevel=0.4, segs=3, rbx_name="Vending" + ("Red" if s < 0 else "Blue"))
    tag(vm, collide=True)
    rprism("VendGlass", (s * 44.4, 5.8, 407.4), 3.2, 5.6, 0.1, 0.4, "Glass", bevel=0.03, rbx_name="VendGlass")
    ring("VendFrame", (s * 44.4, 5.8, 407.7), 3.7, 6.1, 0.5, 0.28, 0.7, "Charcoal", rbx_name="VendPanels")
    for iy in range(4):
        for ix in range(3):
            pal = ("Can", "Cap", "Yellow")[(ix + iy) % 3]
            cyl("VendItem", (s * 44.4 - 1.0 + ix * 1.0, 3.6 + iy * 1.4, 407.8), (s * 44.4 - 1.0 + ix * 1.0, 4.3 + iy * 1.4, 407.8), 0.2, pal, segs=10, rbx_name="VendItems" + pal)
    box("VendPanel", (s * (44.0 - 2.0), 6.0, 407.95), (0.9, 3.0, 0.1), "Charcoal", bevel=0.03, rbx_name="VendPanels")
    box("VendSlot", (s * 44.4, 1.9, 407.95), (3.2, 0.8, 0.12), "Black", bevel=0.05, rbx_name="VendPanels")
    # ticket machines by the gates
    tm = box("TicketBody", (s * 44.5, 3.4, 345.0), (2.4, 4.8, 3.0), "TileAccent", bevel=0.35, segs=3, rbx_name="TicketMachines")
    tag(tm, collide=True)
    box("TicketScreen", (s * 43.25, 4.4, 345.0), (0.12, 1.4, 2.0), "LightBlue", bevel=0.05, rbx_name="TicketScreens")
    box("TicketSlot", (s * 43.25, 2.9, 345.0), (0.12, 0.3, 1.2), "Black", bevel=0.05, rbx_name="VendPanels")

# spawn medallion + leaderboard frames + exit stairs
sub("Entrance")
lathe("Medallion", [(0, 0), (7.0, 0), (7.0, 0.06), (0, 0.06)], "TileTrim", pos=(0, 1.0, 400.0), segs=40, rbx_name="Medallion")
lathe("MedallionRing", [(5.6, 0.06), (6.4, 0.06), (6.4, 0.1), (5.6, 0.1)], "TileAccent", pos=(0, 1.0, 400.0), segs=40, rbx_name="TrimGold")
lathe("MedallionIn", [(0, 0.06), (5.2, 0.06), (5.2, 0.09), (0, 0.09)], "Purple", pos=(0, 1.0, 400.0), segs=40, rbx_name="MedallionIn")
for s in (-1, 1):
    ring("BoardRim", (s * 26.0, 12.0, ZS - 0.35), 16.6, 14.6, 1.2, 0.8, 0.5, "TileAccent", bevel=0.12, rbx_name="TrimGold")
    rprism("BoardBack", (s * 26.0, 12.0, ZS - 0.15), 15.4, 13.4, 0.2, 0.6, "Navy", bevel=0.03, rbx_name="TitleBack")
ring("DepFrame", (0, 21.6, ZS - 0.3), 19.4, 6.4, 0.8, 0.7, 0.4, "TileAccent", bevel=0.1, rbx_name="TrimGold")
# stairs up to the street exit (z 404 -> 414+, rising 10 studs)
for i in range(20):
    top = 1.0 + 0.5 * (i + 1)
    z0 = 404.0 + 0.5 * i
    box("Step", (0, (1.0 + top) / 2, z0 + 0.25), (18.0, top - 1.0, 0.5), "Stone", bevel=0.05, rbx_name="Stairs")
    box("Nose", (0, top - 0.03, z0 + 0.05), (18.0, 0.08, 0.12), "TileAccent", bevel=0.02, rbx_name="StairNose")
box("Landing", (0, 6.0, 420.0), (22.0, 10.0, 12.0), "Stone", bevel=0.1, rbx_name="Stairs")
for s in (-1, 1):
    prism("Balustrade", [(404.0, 1.0), (414.0, 11.0), (426.0, 11.0), (426.0, 14.0), (414.0, 14.0), (404.0, 4.0)], 1.0, "StoneDark", pos=(s * 9.5, 0, 0),
          rot=frame((s * 9.5, 0, 0), (0, 0, 1), (0, 1, 0)), bevel=0.15, rbx_name="Balustrades")
    pipe("Handrail", [(s * 9.5, 4.6, 403.6), (s * 9.5, 14.6, 413.6), (s * 9.5, 14.6, 425.0)], 0.16, "TileAccent", bend=1.0, rbx_name="TrimGold")
box("ExitGlow", (0, 16.0, 426.5), (22.0, 12.0, 1.0), "Light", bevel=0, rbx_name="ExitGlow")
box("ExitWallW", (-11.5, 14.5, 420.0), (1.0, 8.0, 13.0), "Tile", bevel=0.05, rbx_name="ExitWalls")
box("ExitWallE", (11.5, 14.5, 420.0), (1.0, 8.0, 13.0), "Tile", bevel=0.05, rbx_name="ExitWalls")
box("ExitRoof", (0, 18.5, 420.0), (24.0, 1.0, 13.0), "Ceiling", bevel=0.05, rbx_name="ExitWalls")
box("ExitSign", (0, 15.6, ZS - 1.0), (6.0, 1.6, 0.3), "Green", bevel=0.12, rbx_name="ExitSign")

L.target(ROOT, "Lobby.Visual")
result = {"objects": len(L.all_objects("Lobby"))}
