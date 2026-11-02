# Bakes a tangent-space normal map from a detailed mesh onto a light one (Cycles, selected to active), so the light
# mesh keeps the detailed one's sculpted detail - faces, cloth folds, kit seams - at its own cost. Both meshes in the
# same pose and place (the foundation's characters: the rig's T; export them with export_obj.gd). The map is in the
# light mesh's UVs, OpenGL convention (green up), as Godot reads it.
#   blender -b --python bake_normals.py -- --high hi.obj --low lo.obj --out normal.png [--size 1024] [--cage 0.015]
#       [--ray 0.04] [--samples 4] [--margin 8]
import argparse
import sys

import bpy


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--high", required=True)
    p.add_argument("--low", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--size", type=int, default=1024)
    p.add_argument("--cage", type=float, default=0.015, help="how far out the rays start (m)")
    p.add_argument("--ray", type=float, default=0.04, help="how far in they may go (m)")
    p.add_argument("--samples", type=int, default=4)
    p.add_argument("--margin", type=int, default=8, help="pixels the islands bleed out")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def load(path, name):
    before = set(bpy.data.objects)
    # Y up as written (Godot's), so both land the same way.
    bpy.ops.wm.obj_import(filepath=path, forward_axis="NEGATIVE_Z", up_axis="Y")
    objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    return o


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hi = load(a.high, "high")
    lo = load(a.low, "low")
    # The light mesh shades smooth with its own normals (as Godot draws it): the map is the difference.
    for o in (hi, lo):
        for poly in o.data.polygons:
            poly.use_smooth = True
    img = bpy.data.images.new("normal", a.size, a.size, alpha=False, float_buffer=False)
    img.generated_color = (0.5, 0.5, 1.0, 1.0)
    mat = bpy.data.materials.new("bake")
    mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    mat.node_tree.nodes.active = node
    lo.data.materials.clear()
    lo.data.materials.append(mat)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = a.samples
    # (Distribution builds of Blender without OpenImageDenoise bake nothing - zeros, silently - with it on.)
    scene.cycles.use_denoising = False
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = a.cage
    bake.max_ray_distance = a.ray
    bake.margin = a.margin
    bake.normal_space = "TANGENT"
    bake.normal_r, bake.normal_g, bake.normal_b = "POS_X", "POS_Y", "POS_Z"
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    bpy.ops.object.bake(type="NORMAL")
    img.filepath_raw = a.out
    img.file_format = "PNG"
    img.save()
    print("bake_normals: %s -> %s (%d triangles onto %d), %dx%d" % (
        a.high, a.out, sum(len(p.vertices) - 2 for p in hi.data.polygons),
        sum(len(p.vertices) - 2 for p in lo.data.polygons), a.size, a.size))


main()
