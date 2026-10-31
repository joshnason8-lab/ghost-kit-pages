# Bakes the light on a game's built geometry (and on the ground under it) with Cycles: the sun, the sky, their
# shadows and a bounce, onto the second UVs WsgLightBake made (export: <base>.obj + <base>.json). Writes
# <base>_light.png (the built geometry: the light divided by the JSON's "scale") and, if the JSON gives a ground,
# <base>_ground.png (seen from above, x0 z0 at the top left: the light there as a share of the light on open ground -
# the shadows and the occlusion, for a ground shader that lights itself). Stored linear (Non-Color). With
# <base>_probe_points.json beside it (fans' heads), <base>_probes.json: the light at each as a share of an open seat's (WsgLightBake.probes).
#   blender -b --python bake_light.py -- --base out/stadium_day [--samples 64] [--ground-size 1024] [--probes-only]
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--base", required=True)
    p.add_argument("--samples", type=int, default=64)
    p.add_argument("--ground-size", type=int, default=1024)
    p.add_argument("--bounce", type=float, default=0.45, help="the surfaces' albedo for the bounce")
    p.add_argument("--probes-only", action="store_true", help="only the probes (the maps are baked already)")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def bl(v):
    """Godot's (x, y, z), Y up, to Blender's (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


def diffuse(name, albedo):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (albedo, albedo, albedo, 1.0)
    b.inputs["Roughness"].default_value = 1.0
    return m


def target(obj, img):
    """obj's material(s) bake into img (the active image node)."""
    for slot in obj.material_slots:
        nt = slot.material.node_tree
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        nt.nodes.active = n


def bake(obj, img, margin):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    target(obj, img)
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"DIRECT", "INDIRECT"}, margin=margin, use_clear=True)


def save(img, path, scale):
    px = np.empty(len(img.pixels), dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    px[:, :3] = np.clip(px[:, :3] / np.asarray(scale, dtype=np.float32), 0.0, 1.0)
    px[:, 3] = 1.0
    out = bpy.data.images.new(img.name + "_out", img.size[0], img.size[1], alpha=False, float_buffer=False)
    out.colorspace_settings.name = "Non-Color"
    out.pixels.foreach_set(px.ravel())
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()


def probes(a, info, built, to_sun, sun_energy, sky, sun_col):
    """The light at each probe (a fan's head: [x, y, z, facing x, facing z], Godot's), as a share of what an open seat
    gets: the sky through the half facing the pitch (what lights a fan's front; the stand behind them is not counted),
    and the sun seen or not (five rays across its disc). Writes <base>_probes.json {"values": [...]}."""
    dg = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(built, dg)
    lum = lambda col: 0.2126 * col[0] + 0.7152 * col[1] + 0.0722 * col[2]
    sky_w = lum(sky) * float(info.get("sky_energy", 1.0))
    sun_w = lum(sun_col) * sun_energy * 0.6
    # Directions over a hemisphere (a Fibonacci spiral, cosine-weighted about its pole).
    n = 48
    hemi = []
    for i in range(n):
        z = math.sqrt(1.0 - (i + 0.5) / n)
        r = math.sqrt(1.0 - z * z)
        t = i * 2.399963
        hemi.append((r * math.cos(t), r * math.sin(t), z))
    jit = [Vector((0, 0, 0)), Vector((0.012, 0, 0)), Vector((-0.012, 0, 0)), Vector((0, 0.012, 0)), Vector((0, -0.012, 0))]
    out = []
    for p in info["probes"]:
        o = bl((p[0], p[1], p[2]))
        pole = (bl((p[3], 0.0, p[4])).normalized() + Vector((0, 0, 1))).normalized()
        u = pole.cross(Vector((0, 0, 1)))
        u = u.normalized() if u.length > 1e-6 else Vector((1, 0, 0))
        v = pole.cross(u)
        seen = 0
        for d in hemi:
            ray = (u * d[0] + v * d[1] + pole * d[2]).normalized()
            if ray.z < -0.05:
                continue
            if tree.ray_cast(o + ray * 0.05, ray, 400.0)[0] is None:
                seen += 1
        sky_vis = seen / n
        sun_vis = 0.0
        for j in jit:
            ray = (to_sun + j).normalized()
            if tree.ray_cast(o + ray * 0.05, ray, 600.0)[0] is None:
                sun_vis += 1.0 / len(jit)
        out.append(round((sky_w * sky_vis + sun_w * sun_vis) / (sky_w + sun_w), 3))
    json.dump({"values": out}, open(a.base + "_probes.json", "w"))
    print("bake_light: %s_probes.json (%d probes, %.2f on average, %d under 0.6)" % (
        a.base, len(out), sum(out) / max(len(out), 1), sum(1 for x in out if x < 0.6)))


def main():
    a = args()
    info = json.load(open(a.base + ".json"))
    scale = float(info.get("scale", 2.0))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = a.samples
    scene.cycles.use_denoising = False   # (without OpenImageDenoise a bake with it on is zeros)
    scene.cycles.max_bounces = 3
    scene.cycles.diffuse_bounces = 2

    bpy.ops.wm.obj_import(filepath=a.base + ".obj", forward_axis="NEGATIVE_Z", up_axis="Y")
    built = [o for o in bpy.data.objects if o.type == "MESH"][0]
    built.data.materials.clear()
    built.data.materials.append(diffuse("built", a.bounce))

    # The sky: a uniform light of the game's ambient colour and strength (an open face up gets all of it).
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    sc = info.get("sky_colour", [0.6, 0.65, 0.75])
    bg.inputs["Color"].default_value = (sc[0], sc[1], sc[2], 1.0)
    bg.inputs["Strength"].default_value = float(info.get("sky_energy", 1.0))
    scene.world = world

    # The sun: Godot's energy is the light on a face square to it; Cycles' diffuse light from a sun of strength S is
    # S / pi (measured: open ground under the county's sun and sky came out 0.62 of Godot's, as S / pi predicts).
    sun_energy = float(info.get("sun_energy", 1.0))
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = sun_energy * math.pi
    c = info.get("sun_colour", [1, 1, 1])
    sun.color = (c[0], c[1], c[2])
    sun.angle = math.radians(float(info.get("sun_angle", 1.0)))
    so = bpy.data.objects.new("sun", sun)
    scene.collection.objects.link(so)
    to_sun = bl(info["sun_dir"]).normalized()
    so.rotation_mode = "QUATERNION"
    so.rotation_quaternion = to_sun.to_track_quat("Z", "Y")   # a sun shines down its -Z

    # The ground under it (the pitch and round it): receives the built geometry's shadow, seen from above.
    g = info.get("ground", [])
    ground = None
    if g:
        x0, z0, x1, z1, y = g
        me = bpy.data.meshes.new("ground")
        vs = [bl((x0, y, z0)), bl((x1, y, z0)), bl((x1, y, z1)), bl((x0, y, z1))]
        me.from_pydata([tuple(v) for v in vs], [], [(0, 3, 2, 1)])
        me.update()
        uv = me.uv_layers.new(name="UVMap")
        # (Image v runs up; the map's top row is z0.)
        for loop in me.loops:
            p = vs[loop.vertex_index]
            uv.data[loop.index].uv = ((p.x - x0) / (x1 - x0), 1.0 - (-p.y - z0) / (z1 - z0))
        ground = bpy.data.objects.new("ground", me)
        scene.collection.objects.link(ground)
        ground.data.materials.append(diffuse("ground", 0.25))

    if os.path.exists(a.base + "_probe_points.json"):
        info["probes"] = json.load(open(a.base + "_probe_points.json"))
        probes(a, info, built, to_sun, sun_energy, sc, c)
    if a.probes_only:
        return
    size = int(info.get("size", 2048))
    img = bpy.data.images.new("light", size, size, alpha=False, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    bake(built, img, 2)
    save(img, a.base + "_light.png", scale)
    print("bake_light: %s_light.png (%d x %d)" % (a.base, size, size))
    if ground is not None:
        gw = a.ground_size
        gh = max(16, int(round(gw * (z1 - z0) / (x1 - x0))))
        gi = bpy.data.images.new("ground", gw, gh, alpha=False, float_buffer=True)
        gi.colorspace_settings.name = "Non-Color"
        bake(ground, gi, 4)
        sc_e = float(info.get("sky_energy", 1.0))
        k = max(to_sun.z, 0.0) * sun_energy
        save(gi, a.base + "_ground.png", [sc[0] * sc_e + c[0] * k, sc[1] * sc_e + c[1] * k, sc[2] * sc_e + c[2] * k])
        print("bake_light: %s_ground.png (%d x %d)" % (a.base, gw, gh))


main()
