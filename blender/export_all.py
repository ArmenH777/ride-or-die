# Rebuilds the train, tools and lobby and exports their meshes as JSON (+ saves RideOrDie.blend).
# Runs headless:  blender.exe -b --factory-startup --python export_all.py -- blender/export/json
# Then json_to_obj.py turns the JSON into OBJ files for Studio's Import 3D (see CLAUDE.md).
import os, sys
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
out_dir = sys.argv[sys.argv.index("--") + 1]

for c in list(bpy.data.collections):
    bpy.data.collections.remove(c)
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

for script in ("build_train.py", "build_tools.py", "build_lobby.py"):
    exec(open(os.path.join(HERE, script)).read(), {"__name__": "__build__"})

import rod_lib as L
for coll, prefix in (("Train", "train"), ("Tools", "tools"), ("Lobby", "lobby")):
    m = L.export_json(L.all_objects(coll), out_dir, prefix)
    print(prefix, len(m["meshes"]), "meshes", sum(e["tris"] for e in m["meshes"]), "tris")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "RideOrDie.blend"))
