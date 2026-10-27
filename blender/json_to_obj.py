# Converts the exported mesh JSON (see rod_lib.export_json) into OBJ files for Roblox's Import 3D.
# Each merged mesh becomes one OBJ group named like its JSON file (train_000, lobby_012, ...),
# with world positions in studs, per-corner normals and UVs.
# Usage: python json_to_obj.py <mesh json folder> <output .obj> <prefix>[:Name+Name...] [...]
#   "lobby" takes every lobby mesh; "lobby:SideWallE+TrainBody" only the meshes with those names.
import json, os, sys

src, out_path = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(out_path), exist_ok=True)
vo = no = to = 0
count = skipped = 0
with open(out_path, "w") as f:
    f.write("# Ride or Die (made in Blender)\n")
    for spec in sys.argv[3:]:
        prefix, _, names = spec.partition(":")
        only = set(names.split("+")) if names else None
        manifest = json.load(open(os.path.join(src, prefix + "_manifest.json")))
        for m in manifest["meshes"]:
            if only and m["name"] not in only and m["file"][:-5] not in only:
                continue
            data = json.load(open(os.path.join(src, m["file"])))
            cx, cy, cz = m["center"]
            # Roblox's importer splits OBJ files by group ("g"); ungrouped faces all land in "default"
            f.write("g %s\n" % m["file"][:-5])
            v, n, uv, t = data["v"], data["n"], data["uv"], data["t"]
            for i in range(0, len(v), 3):
                f.write("v %.4f %.4f %.4f\n" % (v[i] + cx, v[i + 1] + cy, v[i + 2] + cz))
            for i in range(0, len(uv), 2):
                f.write("vt %.4f %.4f\n" % (uv[i], uv[i + 1]))
            for i in range(0, len(n), 3):
                f.write("vn %.4f %.4f %.4f\n" % (n[i], n[i + 1], n[i + 2]))
            for i in range(0, len(t), 12):
                a, b, c = t[i], t[i + 4], t[i + 8]
                if a == b or b == c or a == c:
                    skipped += 1
                    continue
                f.write("f %s\n" % " ".join("%d/%d/%d" % (t[i + k] + vo, t[i + k + 2] + to, t[i + k + 1] + no) for k in (0, 4, 8)))
            vo += len(v) // 3
            to += len(uv) // 2
            no += len(n) // 3
            count += 1
print(count, "meshes ->", out_path, os.path.getsize(out_path) // 1024, "KB, skipped", skipped, "degenerate tris")
