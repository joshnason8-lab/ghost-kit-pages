# A character's light mesh from its detailed one, by Blender's edge-collapse decimation: the same both sides (X
# symmetry), the hands and the head kept denser (they read at any distance), UV seams and the silhouette kept, all
# triangles. Both in the rig's T (the foundation's characters, exported with export_obj.gd); lod_from_obj.gd gives the
# result back its skin.
#   blender -b --python decimate_lod.py -- --in hi.obj --out lo.obj --tris 1800 [--keep 0.6] [--compare old_lo.obj]
import argparse
import sys

import bmesh
import bpy
from mathutils.bvhtree import BVHTree


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--tris", type=int, required=True)
    p.add_argument("--keep", type=float, default=0.6, help="how much denser the hands and head stay (0-1)")
    p.add_argument("--compare", help="an existing light mesh (OBJ): print its surface error too")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def surface_error(src, dst):
    """Mean and worst distance (m) from the detailed surface's vertices to the light one."""
    bm = bmesh.new()
    bm.from_mesh(dst.data)
    tree = BVHTree.FromBMesh(bm)
    d = []
    for v in src.data.vertices:
        hit = tree.find_nearest(v.co)
        if hit[0] is not None:
            d.append(hit[3])
    bm.free()
    d.sort()
    return sum(d) / len(d), d[int(len(d) * 0.99)], d[-1]


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=a.src, forward_axis="NEGATIVE_Z", up_axis="Y")
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        o.select_set(True)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    # The OBJ's vertices are split at every UV seam (as the GPU wants them): joined again, the seams kept in the UVs.
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(o.data)
    bm.free()
    src = o.copy()
    src.data = o.data.copy()
    before = tris(o)
    # The hands (the arms' outer ends in the T) and the head (the top of the body) kept denser.
    xs = [abs(v.co.x) for v in o.data.vertices]
    zs = [v.co.z for v in o.data.vertices]   # (Blender's Z is Godot's Y)
    reach, top, floor_ = max(xs), max(zs), min(zs)
    g = o.vertex_groups.new(name="keep")
    for v in o.data.vertices:
        hand = abs(v.co.x) > reach * 0.84
        head = v.co.z > floor_ + (top - floor_) * 0.86
        g.add([v.index], 1.0 if hand or head else 0.0, "REPLACE")
    m = o.modifiers.new("decimate", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.use_symmetry = True
    m.symmetry_axis = "X"
    m.use_collapse_triangulate = True
    m.vertex_group = "keep"
    m.vertex_group_factor = 1.0 + 9.0 * a.keep
    m.invert_vertex_group = True
    # The ratio that lands on the triangles wanted (a few tries: protected parts and symmetry move it).
    ratio = a.tris / max(before, 1)
    dg = bpy.context.evaluated_depsgraph_get()
    for _ in range(8):
        m.ratio = min(max(ratio, 0.001), 1.0)
        dg.update()
        got = sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons)
        if abs(got - a.tris) < a.tris * 0.02:
            break
        ratio *= a.tris / max(got, 1)
    bpy.ops.object.modifier_apply(modifier="decimate")
    for p in o.data.polygons:
        p.use_smooth = True
    after = tris(o)
    mean, p99, worst = surface_error(src, o)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.wm.obj_export(filepath=a.out, export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y",
                          export_uv=True, export_normals=True, export_materials=False, export_triangulated_mesh=True,
                          export_vertex_groups=False)
    if a.compare:
        before_objs = set(bpy.data.objects)
        bpy.ops.wm.obj_import(filepath=a.compare, forward_axis="NEGATIVE_Z", up_axis="Y")
        other = [x for x in bpy.data.objects if x not in before_objs and x.type == "MESH"][0]
        cm, c99, cw = surface_error(src, other)
        print("decimate_lod: compared %s (%d triangles): off by %.1f mm on average, %.1f mm at the 99th percentile, "
              "%.1f mm at worst" % (a.compare, tris(other), cm * 1000, c99 * 1000, cw * 1000))
    print("decimate_lod: %d -> %d triangles; surface off by %.1f mm on average, %.1f mm at the 99th percentile, %.1f mm "
          "at worst -> %s" % (before, after, mean * 1000, p99 * 1000, worst * 1000, a.out))


main()
