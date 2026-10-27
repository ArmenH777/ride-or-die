# Ride or Die - shared Blender helpers.
# Everything is built in ROBLOX coordinates (studs, Y up) and converted here:
#   Roblox (x, y, z)  ->  Blender (x, -z, y)
# Objects carry custom props that the exporter turns into Roblox MeshParts:
#   ob["rbx_path"] = "Train.Visual"   (folder path inside workspace / ServerStorage)
#   ob["rbx_name"] = "Seats"          (MeshPart name; objects with the same path+name+palette merge)
#   ob["pal"]      = "Steel"          (palette entry -> Color / Material / Transparency)
import bpy, bmesh, math, json, os
from mathutils import Vector, Matrix

PROJECT = r"C:\Users\Shesn\OneDrive\Documents\Survive the Train"
BLEND_DIR = os.path.join(PROJECT, "blender")

C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox -> Blender rotation
CI = C.transposed()


def B(p):
    """Roblox point -> Blender point."""
    return C @ Vector(p)


def R(p):
    """Blender point -> Roblox point."""
    return CI @ Vector(p)


# ------------------------------------------------------------------ palette
# name: (hex, roblox material, transparency, reflectance)
PALETTE = {
    # train
    "Body": ("D5DAE2", "SmoothPlastic", 0, 0),
    "BodyDark": ("3A3F4B", "SmoothPlastic", 0, 0),
    "Wall": ("EEF0F3", "SmoothPlastic", 0, 0),
    "WallShade": ("C9CED8", "SmoothPlastic", 0, 0),
    "Ceiling": ("F7F8FA", "SmoothPlastic", 0, 0),
    "Floor": ("4A4E5C", "SmoothPlastic", 0, 0),
    "FloorDot": ("5A5F6E", "SmoothPlastic", 0, 0),
    "Rubber": ("2A2D36", "SmoothPlastic", 0, 0),
    "Steel": ("D9DEE6", "Metal", 0, 0.15),
    "SteelDark": ("8E96A3", "Metal", 0, 0.1),
    "Yellow": ("FFC928", "SmoothPlastic", 0, 0),
    "Orange": ("FF8A1F", "SmoothPlastic", 0, 0),
    "Red": ("E8343C", "SmoothPlastic", 0, 0),
    "RedDark": ("A61F2C", "SmoothPlastic", 0, 0),
    "Green": ("3CCB5A", "SmoothPlastic", 0, 0),
    "Teal": ("1FB5B0", "SmoothPlastic", 0, 0),
    "Blue": ("2F7BEA", "SmoothPlastic", 0, 0),
    "Navy": ("23345E", "SmoothPlastic", 0, 0),
    "Purple": ("8C46D2", "SmoothPlastic", 0, 0),
    "Pink": ("FF5FA2", "SmoothPlastic", 0, 0),
    "White": ("FFFFFF", "SmoothPlastic", 0, 0),
    "Black": ("1A1C22", "SmoothPlastic", 0, 0),
    "Charcoal": ("2C303A", "SmoothPlastic", 0, 0),
    "Wood": ("B97A47", "SmoothPlastic", 0, 0),
    "WoodDark": ("7D4E2C", "SmoothPlastic", 0, 0),
    "Glass": ("9CC8E8", "Glass", 0.55, 0),
    "GlassDark": ("1C2430", "Glass", 0.25, 0),
    "Screen": ("0E1620", "SmoothPlastic", 0, 0),
    "Light": ("FFF6E4", "Neon", 0, 0),
    "LightBlue": ("BFE6FF", "Neon", 0, 0),
    "Seat": ("249CA8", "SmoothPlastic", 0, 0),
    "SeatEnd": ("EC8426", "SmoothPlastic", 0, 0),
    "Stripe": ("8C46D2", "SmoothPlastic", 0, 0),
    "Lower": ("2E4270", "SmoothPlastic", 0, 0),
    # snacks / tools
    "Tape": ("A9B0B8", "SmoothPlastic", 0, 0),
    "Bread": ("F2C27B", "SmoothPlastic", 0, 0),
    "Crust": ("C98A3E", "SmoothPlastic", 0, 0),
    "Lettuce": ("6BD14A", "SmoothPlastic", 0, 0),
    "Tomato": ("F04848", "SmoothPlastic", 0, 0),
    "Cheese": ("FFD54A", "SmoothPlastic", 0, 0),
    "Ham": ("FF9AA8", "SmoothPlastic", 0, 0),
    "Pretzel": ("C2742F", "SmoothPlastic", 0, 0),
    "Salt": ("FFFFFF", "SmoothPlastic", 0, 0),
    "Water": ("7FD3FF", "Glass", 0.35, 0),
    "Cap": ("2F7BEA", "SmoothPlastic", 0, 0),
    "Can": ("E8343C", "SmoothPlastic", 0, 0),
    "CanTop": ("C9CED8", "Metal", 0, 0.2),
    # station
    "Tile": ("F4F1EA", "SmoothPlastic", 0, 0),
    "TileTrim": ("2C5BB8", "SmoothPlastic", 0, 0),
    "TileAccent": ("FFC928", "SmoothPlastic", 0, 0),
    "Stone": ("D8D2C6", "SmoothPlastic", 0, 0),
    "StoneDark": ("A69E90", "SmoothPlastic", 0, 0),
    "Marble": ("ECE7DE", "SmoothPlastic", 0, 0),
    "Concrete": ("7C808A", "SmoothPlastic", 0, 0),
    "Rail": ("B9BEC6", "Metal", 0, 0.1),
    "Sleeper": ("5B4636", "SmoothPlastic", 0, 0),
    "Gravel": ("55524F", "SmoothPlastic", 0, 0),
    "Plant": ("4CC456", "SmoothPlastic", 0, 0),
    "PlantDark": ("2E9A44", "SmoothPlastic", 0, 0),
    "Pot": ("E07A3A", "SmoothPlastic", 0, 0),
    "Gold": ("FFC94A", "SmoothPlastic", 0, 0.05),
}


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(pal):
    name = "pal_" + pal
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    h, rmat, tr, refl = PALETTE[pal]
    r, g, b = (srgb_to_lin(c) for c in hex_rgb(h))
    m.diffuse_color = (r, g, b, 1 - tr * 0.6)
    m.metallic = 0.4 if rmat == "Metal" else 0
    m.roughness = 0.35 if rmat in ("Metal", "Glass") else 0.6
    if m.use_nodes if hasattr(m, "use_nodes") else False:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (r, g, b, 1)
            if rmat == "Neon":
                bsdf.inputs["Emission Color"].default_value = (r, g, b, 1)
                bsdf.inputs["Emission Strength"].default_value = 3
    return m


# ------------------------------------------------------------------ collections
def coll(name, parent=None):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(c)
    return c


def clear_coll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        return
    for child in list(c.children):
        clear_coll(child.name)
    for ob in list(c.objects):
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if data is not None and data.users == 0:
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)
            elif isinstance(data, bpy.types.Curve):
                bpy.data.curves.remove(data)
    bpy.data.collections.remove(c)


class Ctx:
    """Current build target: collection + Roblox folder path."""
    coll = None
    path = "Model"


def target(collection, rbx_path):
    Ctx.coll = collection
    Ctx.path = rbx_path


# ------------------------------------------------------------------ object creation
def _finish(name, me, pal, bevel=0.0, segs=2, angle=32, rbx_name=None, path=None, matrix=None, smooth=True):
    if smooth:
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
        try:
            me.set_sharp_from_angle(angle=math.radians(angle))
        except Exception:
            pass
    else:
        me.polygons.foreach_set("use_smooth", [False] * len(me.polygons))
    me.materials.append(mat(pal))
    ob = bpy.data.objects.new(name, me)
    (Ctx.coll or bpy.context.scene.collection).objects.link(ob)
    if matrix is not None:
        ob.matrix_world = matrix
    ob["pal"] = pal
    ob["rbx_path"] = path or Ctx.path
    if rbx_name:
        ob["rbx_name"] = rbx_name
    if bevel > 0:
        add_bevel(ob, bevel, segs, angle)
    return ob


def add_bevel(ob, width, segs=2, angle=32):
    m = ob.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segs
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
    m.harden_normals = True
    m.use_clamp_overlap = True
    m.miter_outer = "MITER_ARC"
    return m


def frame(origin, xr=(1, 0, 0), yr=(0, 1, 0)):
    """Blender world matrix for a local frame given in Roblox coords."""
    x = Vector(xr).normalized()
    y = Vector(yr).normalized()
    z = x.cross(y).normalized()
    y = z.cross(x)
    bx, by, bz = C @ x, C @ y, C @ z
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2] = bx[i], by[i], bz[i]
    t = B(origin)
    m[0][3], m[1][3], m[2][3] = t
    return m


def rot_frame(origin, ry=0.0, rx=0.0, rz=0.0):
    """Frame rotated by Roblox-style angles (degrees) = CFrame.Angles(rx, ry, rz)."""
    mr = Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(ry), 3, "Y") @ Matrix.Rotation(math.radians(rz), 3, "Z")
    return frame(origin, mr.col[0], mr.col[1])


def _local_mesh(name, build):
    """build(bm) fills the bmesh in LOCAL Roblox-style axes (x, y up, z)."""
    # local coords stay Roblox-style (x, y up, z); frame() matrices map them into Blender
    bm = bmesh.new()
    build(bm)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def _local_matrix(pos, rot):
    if rot is None:
        return frame(pos)
    if isinstance(rot, Matrix):
        return rot
    return rot_frame(pos, *rot)


def box(name, pos, size, pal, bevel=0.08, segs=2, rot=None, **kw):
    """rot = (ry, rx, rz) degrees or a frame() matrix (then pos is ignored)."""
    sx, sy, sz = size

    def build(bm):
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    me = _local_mesh(name, build)
    return _finish(name, me, pal, bevel, segs, matrix=_local_matrix(pos, rot), **kw)


def cyl(name, p1, p2, r, pal, segs=16, bevel=0.0, bsegs=2, r2=None, caps=True, **kw):
    """Cylinder (or cone with r2) between two Roblox points."""
    a, b = Vector(p1), Vector(p2)
    d = b - a
    L = d.length
    r2 = r if r2 is None else r2

    def build(bm):
        bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segs, radius1=r, radius2=r2, depth=L)
        # create_cone builds along local Z; turn it to local Y (Roblox-style "up" of the frame)
        for v in bm.verts:
            v.co = Vector((v.co.x, v.co.z, -v.co.y))
    me = _local_mesh(name, build)
    up = d.normalized()
    side = Vector((1, 0, 0)) if abs(up.x) < 0.9 else Vector((0, 0, 1))
    xr = up.cross(side).normalized()
    m = frame((a + b) / 2, xr, up)
    return _finish(name, me, pal, bevel, bsegs, matrix=m, **kw)


def ball(name, pos, r, pal, segs=16, rings=10, scale=(1, 1, 1), rot=None, **kw):
    def build(bm):
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
        for v in bm.verts:
            v.co = Vector((v.co.x * scale[0], v.co.z * scale[1], -v.co.y * scale[2]))
    me = _local_mesh(name, build)
    return _finish(name, me, pal, 0, matrix=_local_matrix(pos, rot), **kw)


def rrect_pts(w, h, r, n=5):
    r = min(r, w / 2 - 1e-4, h / 2 - 1e-4)
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def prism(name, pts, depth, pal, pos=(0, 0, 0), rot=None, bevel=0.05, segs=2, **kw):
    """Extrude a 2D outline (local x, y) by depth along local z (centered)."""
    def build(bm):
        vs = [bm.verts.new((x, y, -depth / 2)) for x, y in pts]
        f = bm.faces.new(vs)
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        top = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=(0, 0, depth), verts=top)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = _local_mesh(name, build)
    return _finish(name, me, pal, bevel, segs, matrix=_local_matrix(pos, rot), **kw)


def rprism(name, pos, w, h, depth, radius, pal, rot=None, n=5, **kw):
    """Rounded-rectangle slab: w along local x, h along local y, depth along local z."""
    return prism(name, rrect_pts(w, h, radius, n), depth, pal, pos=pos, rot=rot, **kw)


def ring(name, pos, w, h, radius, thick, depth, pal, rot=None, n=5, bevel=0.04, **kw):
    """Rounded-rectangle frame (window gasket): outer w x h, border thickness `thick`."""
    outer = rrect_pts(w, h, radius, n)
    inner = rrect_pts(w - 2 * thick, h - 2 * thick, max(0.01, radius - thick), n)

    def build(bm):
        o0 =[bm.verts.new((x, y, -depth / 2)) for x, y in outer]
        o1 = [bm.verts.new((x, y, depth / 2)) for x, y in outer]
        i0 = [bm.verts.new((x, y, -depth / 2)) for x, y in inner]
        i1 = [bm.verts.new((x, y, depth / 2)) for x, y in inner]
        N = len(outer)
        for k in range(N):
            j = (k + 1) % N
            bm.faces.new((o0[k], o0[j], o1[j], o1[k]))      # outer side
            bm.faces.new((i0[j], i0[k], i1[k], i1[j]))      # inner side
            bm.faces.new((o1[k], o1[j], i1[j], i1[k]))      # front
            bm.faces.new((o0[j], o0[k], i0[k], i0[j]))      # back
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = _local_mesh(name, build)
    return _finish(name, me, pal, bevel, 2, matrix=_local_matrix(pos, rot), **kw)


def lathe(name, profile, pal, pos=(0, 0, 0), rot=None, segs=20, bevel=0.0, **kw):
    """Revolve [(radius, height), ...] around local y. Radius 0 points close the ends."""
    def build(bm):
        rings_ = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ca, sa = math.cos(a), math.sin(a)
            rings_.append([bm.verts.new((r * ca, y, r * sa)) for r, y in profile])
        for i in range(segs):
            a, b = rings_[i], rings_[(i + 1) % segs]
            for k in range(len(profile) - 1):
                quad = [a[k], b[k], b[k + 1], a[k + 1]]
                try:
                    bm.faces.new(quad)
                except ValueError:
                    pass
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        # remove degenerate faces created at the axis
        bad = [f for f in bm.faces if f.calc_area() < 1e-9]
        bmesh.ops.delete(bm, geom=bad, context="FACES")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = _local_mesh(name, build)
    return _finish(name, me, pal, bevel, 2, matrix=_local_matrix(pos, rot), **kw)


def torus(name, pos, R_, r, pal, rot=None, segs=24, tsegs=10, arc=360, **kw):
    def build(bm):
        rings_ = []
        n = segs + (0 if arc >= 360 else 1)
        for i in range(n):
            a = math.radians(arc) * i / segs
            ca, sa = math.cos(a), math.sin(a)
            ring_ = []
            for k in range(tsegs):
                b = 2 * math.pi * k / tsegs
                rr = R_ + r * math.cos(b)
                ring_.append(bm.verts.new((rr * ca, r * math.sin(b), rr * sa)))
            rings_.append(ring_)
        for i in range(segs):
            a, b = rings_[i], rings_[(i + 1) % n]
            for k in range(tsegs):
                bm.faces.new((a[k], a[(k + 1) % tsegs], b[(k + 1) % tsegs], b[k]))
        if arc < 360:
            bm.faces.new(list(reversed(rings_[0])))
            bm.faces.new(rings_[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = _local_mesh(name, build)
    return _finish(name, me, pal, 0, matrix=_local_matrix(pos, rot), **kw)


def extrude_x(name, profile_zy, x0, x1, pal, bevel=0.0, **kw):
    """Extrude a closed (z, y) Roblox profile along X from x0 to x1."""
    def build(bm):
        a = [bm.verts.new((x0, y, z)) for z, y in profile_zy]
        f = bm.faces.new(a)
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        top = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=(x1 - x0, 0, 0), verts=top)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = _local_mesh(name, build)
    return _finish(name, me, pal, bevel, 2, matrix=frame((0, 0, 0)), **kw)


def pipe(name, pts, r, pal, bend=0.6, segs=12, arc_steps=6, **kw):
    """Tube through Roblox points with rounded bends (built as a mesh)."""
    P = [Vector(p) for p in pts]
    path = [P[0]]
    for i in range(1, len(P) - 1):
        a, b, c = P[i - 1], P[i], P[i + 1]
        d1, d2 = (a - b).normalized(), (c - b).normalized()
        ang = d1.angle(d2)
        if ang > math.pi - 1e-3:
            path.append(b)
            continue
        t = min(bend / math.tan(ang / 2), (a - b).length * 0.49, (c - b).length * 0.49)
        s, e = b + d1 * t, b + d2 * t
        for k in range(arc_steps + 1):
            u = k / arc_steps
            q = (1 - u) ** 2 * s + 2 * (1 - u) * u * b + u ** 2 * e
            path.append(q)
    path.append(P[-1])

    def build(bm):
        rings_ = []
        prev_n = None
        for i, p in enumerate(path):
            if i == 0:
                tdir = (path[1] - path[0]).normalized()
            elif i == len(path) - 1:
                tdir = (path[-1] - path[-2]).normalized()
            else:
                tdir = ((path[i + 1] - path[i]).normalized() + (path[i] - path[i - 1]).normalized()).normalized()
            if prev_n is None:
                ref = Vector((0, 1, 0)) if abs(tdir.y) < 0.9 else Vector((1, 0, 0))
                nrm = tdir.cross(ref).normalized()
            else:
                nrm = (prev_n - tdir * prev_n.dot(tdir)).normalized()
            prev_n = nrm
            bnm = tdir.cross(nrm)
            rings_.append([bm.verts.new(p + (nrm * math.cos(2 * math.pi * k / segs) + bnm * math.sin(2 * math.pi * k / segs)) * r) for k in range(segs)])
        for i in range(len(rings_) - 1):
            a, b = rings_[i], rings_[i + 1]
            for k in range(segs):
                bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
        bm.faces.new(list(reversed(rings_[0])))
        bm.faces.new(rings_[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = _local_mesh(name, build)
    return _finish(name, me, pal, 0, matrix=frame((0, 0, 0)), **kw)


def flat(pos):
    """Frame for shapes lying flat (outline in X/Z, thickness along Y)."""
    return frame(pos, (1, 0, 0), (0, 0, -1))


def side(pos):
    """Frame for shapes facing along X (outline in Z/Y, thickness along X)."""
    return frame(pos, (0, 0, 1), (0, 1, 0))


def sym(pts_r):
    """Half profile (z, y) from the right side to z=0 -> full right-to-left profile."""
    return list(pts_r) + [(-z, y) for z, y in reversed(pts_r[:-1])]


def round_poly(pts, r, n=5):
    """Round the corners of a convex 2D polygon (counter-clockwise points)."""
    out = []
    N = len(pts)
    for i in range(N):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % N])
        d1, d2 = (p0 - p1).normalized(), (p2 - p1).normalized()
        half = d1.angle(d2) / 2
        dist = r / math.sin(half)
        c = p1 + (d1 + d2).normalized() * dist
        t1 = p1 + d1 * (r / math.tan(half)) - c
        a0 = math.atan2(t1.y, t1.x)
        sweep = math.pi - 2 * half  # counter-clockwise polygons turn left at each corner
        for k in range(n + 1):
            a = a0 + sweep * k / n
            out.append((c.x + r * math.cos(a), c.y + r * math.sin(a)))
    return out


def transform_objs(objs, pivot_r, ry=0.0, rx=0.0, rz=0.0):
    """Rotate objects (Roblox-style angles, degrees) about a Roblox-space pivot."""
    mr = Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(ry), 3, "Y") @ Matrix.Rotation(math.radians(rz), 3, "Z")
    mb = (C @ mr @ CI).to_4x4()
    p = B(pivot_r)
    M = Matrix.Translation(p) @ mb @ Matrix.Translation(-p)
    for ob in objs:
        ob.matrix_world = M @ ob.matrix_world


def copy_at(ob, matrix):
    """Linked copy for previews (not exported)."""
    c = ob.copy()
    c.data = ob.data
    for k in ("template", "rbx_name"):
        if k in c:
            del c[k]
    c["noexport"] = True
    c.matrix_world = matrix
    ob.users_collection[0].objects.link(c)
    return c


def cutter(name, maker, *args, **kw):
    """Make a boolean cutter object (hidden, never exported)."""
    ob = maker(name, *args, **kw)
    ob["cutter"] = True
    ob.hide_render = True
    ob.display_type = "WIRE"
    ob.hide_set(True)
    return ob


CUTTERS = "_Cutters"  # each build script sets its own, so rebuilding one never deletes another's cutters


def cut(target_ob, cutters, solver="EXACT"):
    """Boolean-difference a list of cutters (put before the bevel modifier)."""
    cc = bpy.data.collections.get(CUTTERS) or coll(CUTTERS)
    for c in cutters:
        for col in list(c.users_collection):
            col.objects.unlink(c)
        cc.objects.link(c)
    cc.hide_render = True
    m = target_ob.modifiers.new("Cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.solver = solver
    if len(cutters) == 1:
        m.object = cutters[0]
    else:
        sub = bpy.data.collections.get("_Cut_" + target_ob.name) or bpy.data.collections.new("_Cut_" + target_ob.name)
        if sub.name not in [ch.name for ch in cc.children]:
            cc.children.link(sub)
        for c in cutters:
            cc.objects.unlink(c)
            sub.objects.link(c)
        m.operand_type = "COLLECTION"
        m.collection = sub
    # booleans go first so the bevel also rounds the cut edges
    with bpy.context.temp_override(object=target_ob):
        bpy.ops.object.modifier_move_to_index(modifier=m.name, index=0)
    return m


def mirror_z(ob):
    """Mirror across the Roblox z=0 plane (Blender y=0)."""
    m = ob.modifiers.new("MirrorZ", "MIRROR")
    m.use_axis = (False, True, False)
    m.mirror_object = None
    return m


# ------------------------------------------------------------------ export
def _export_objects(objs):
    """Return {key: {path, name, pal, tris: [(p, n, uv) x3]}} in Roblox coords."""
    dg = bpy.context.evaluated_depsgraph_get()
    groups = {}
    for ob in objs:
        if ob.get("cutter") or ob.get("noexport") or ob.type not in ("MESH", "CURVE"):
            continue
        path = "Templates" if ob.get("template") else ob.get("rbx_path", "Model")
        name = ob.get("rbx_name") or (ob.users_collection[0].name + "_" + ob.get("pal", "X"))
        key = "|".join((path, name, ob.get("pal", "X"), str(ob.get("group", ""))))
        g = groups.setdefault(key, {"path": path, "name": name, "pal": ob.get("pal", "X"), "corners": [],
                                    "collide": bool(ob.get("collide")), "template": bool(ob.get("template"))})
        eo = ob.evaluated_get(dg)
        me = eo.to_mesh()
        me.calc_loop_triangles()
        mw = eo.matrix_world
        nm = mw.to_3x3().inverted_safe().transposed()
        cn = me.corner_normals
        verts = me.vertices
        corners = []
        for lt in me.loop_triangles:
            for li, vi in zip(lt.loops, lt.vertices):
                p = R(mw @ verts[vi].co)
                n = (CI @ (nm @ cn[li].vector)).normalized()
                corners.append((p, n))
        g.setdefault("objects", []).append(corners)
        eo.to_mesh_clear()
    # Roblox meshes max out at 20k triangles: split big groups object by object along X
    out = {}
    for key, g in groups.items():
        objs_ = sorted(g.pop("objects"), key=lambda cs: sum(c[0].x for c in cs) / max(1, len(cs)))
        chunk, n, part = [], 0, 0
        for cs in objs_:
            if chunk and n + len(cs) // 3 > MAX_TRIS:
                out[key + "#%d" % part] = dict(g, corners=chunk)
                chunk, n, part = [], 0, part + 1
            chunk.extend(cs)
            n += len(cs) // 3
        out[key + ("#%d" % part if part else "")] = dict(g, corners=chunk)
    return out


MAX_TRIS = 19000


def _uv_for(p, n, scale=0.125):
    ax = max(range(3), key=lambda i: abs(n[i]))
    if ax == 0:
        return (p.z * scale, p.y * scale)
    if ax == 1:
        return (p.x * scale, p.z * scale)
    return (p.x * scale, p.y * scale)


def export_json(objs, out_dir, prefix):
    """Write one JSON per merged mesh plus a manifest; returns the manifest."""
    os.makedirs(out_dir, exist_ok=True)
    groups = _export_objects(objs)
    manifest = {"palette": {}, "meshes": []}
    for i, (key, g) in enumerate(sorted(groups.items())):
        cs = g["corners"]
        if not cs:
            continue
        lo = Vector((min(c[0].x for c in cs), min(c[0].y for c in cs), min(c[0].z for c in cs)))
        hi = Vector((max(c[0].x for c in cs), max(c[0].y for c in cs), max(c[0].z for c in cs)))
        center = (lo + hi) / 2
        vmap, nmap, uvmap = {}, {}, {}
        V, N, UV, T = [], [], [], []
        for p, n in cs:
            q = p - center
            kp = (round(q.x, 4), round(q.y, 4), round(q.z, 4))
            vi = vmap.get(kp)
            if vi is None:
                V.extend(kp)
                vi = vmap[kp] = len(V) // 3
            kn = (round(n.x, 3), round(n.y, 3), round(n.z, 3))
            ni = nmap.get(kn)
            if ni is None:
                N.extend(kn)
                ni = nmap[kn] = len(N) // 3
            u = _uv_for(p, n)
            ku = (round(u[0], 3), round(u[1], 3))
            ui = uvmap.get(ku)
            if ui is None:
                UV.extend(ku)
                ui = uvmap[ku] = len(UV) // 2
            T.extend((vi, ni, ui, 0))
        fname = "%s_%03d.json" % (prefix, i)
        data = {"name": g["name"], "v": V, "n": N, "uv": UV, "t": T}
        with open(os.path.join(out_dir, fname), "w") as f:
            json.dump(data, f, separators=(",", ":"))
        manifest["meshes"].append({
            "file": fname, "path": g["path"], "name": g["name"], "pal": g["pal"],
            "center": [round(center.x, 4), round(center.y, 4), round(center.z, 4)],
            "size": [round(hi.x - lo.x, 4), round(hi.y - lo.y, 4), round(hi.z - lo.z, 4)],
            "tris": len(cs) // 3, "verts": len(V) // 3,
            "collide": g["collide"], "template": g["template"],
        })
        manifest["palette"][g["pal"]] = {"color": PALETTE[g["pal"]][0], "material": PALETTE[g["pal"]][1],
                                         "transparency": PALETTE[g["pal"]][2], "reflectance": PALETTE[g["pal"]][3]}
    with open(os.path.join(out_dir, prefix + "_manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    return manifest


def export_fbx(objs, fbx_path, prefix):
    """Write the same merged meshes as export_json into one FBX (object names = '<prefix>_NNN').
    Objects sit at their Roblox centre; axes are converted so the file is Y-up like Roblox."""
    groups = _export_objects(objs)
    temp = bpy.data.collections.get("_Export") or coll("_Export")
    made = []
    for i, (key, g) in enumerate(sorted(groups.items())):
        cs = g["corners"]
        if not cs:
            continue
        lo = Vector((min(c[0].x for c in cs), min(c[0].y for c in cs), min(c[0].z for c in cs)))
        hi = Vector((max(c[0].x for c in cs), max(c[0].y for c in cs), max(c[0].z for c in cs)))
        center = (lo + hi) / 2
        vmap, verts, faces, lnorms, luvs = {}, [], [], [], []
        for t in range(0, len(cs), 3):
            face = []
            for p, n in cs[t:t + 3]:
                q = B(p - center)
                k = (round(q.x, 4), round(q.y, 4), round(q.z, 4))
                if k not in vmap:
                    vmap[k] = len(verts)
                    verts.append(k)
                face.append(vmap[k])
                lnorms.append(tuple(C @ n))
                luvs.append(_uv_for(p, n))
            faces.append(face)
        name = "%s_%03d" % (prefix, i)
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], faces, shade_flat=False)
        me.normals_split_custom_set(lnorms)
        uvl = me.uv_layers.new(name="UVMap")
        uvl.data.foreach_set("uv", [c for uv in luvs for c in uv])
        me.materials.append(mat(g["pal"]))
        ob = bpy.data.objects.new(name, me)
        ob.location = B(center)
        temp.objects.link(ob)
        made.append(ob)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in made:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    bpy.ops.export_scene.fbx(filepath=fbx_path, use_selection=True, object_types={"MESH"}, axis_forward="-Z", axis_up="Y",
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=False,
                             mesh_smooth_type="OFF", use_custom_props=False, path_mode="AUTO", bake_space_transform=True)
    clear_coll("_Export")
    return len(made)


def all_objects(collection_name):
    c = bpy.data.collections.get(collection_name)
    return list(c.all_objects) if c else []


# ------------------------------------------------------------------ preview
def preview_setup():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.show_object_outline = False
    sh.show_specular_highlight = True
    sc.display.render_aa = "8"
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    world = sc.world or bpy.data.worlds.new("World")
    sc.world = world
    world.color = (0.05, 0.06, 0.08)


def camera(name, pos_r, look_r, lens=24):
    cam = bpy.data.objects.get(name)
    if cam is None:
        cd = bpy.data.cameras.new(name)
        cam = bpy.data.objects.new(name, cd)
        bpy.context.scene.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_end = 2000
    cam.location = B(pos_r)
    d = B(look_r) - B(pos_r)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def render(path, cam=None):
    if cam:
        bpy.context.scene.camera = bpy.data.objects[cam]
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def hide_others(keep):
    """Show only collections whose names are in keep (for previews)."""
    for c in bpy.context.scene.collection.children:
        c.hide_render = c.name not in keep
