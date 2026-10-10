#!/usr/bin/env python3
"""Turn a textured Meshy GLB into one of the game's bodies, every step in one go:

prepare.py (turn, stand on the floor) -> render_views (Godot) -> joints2d.py -> autorig.py (rig, palms down,
finger bones) -> kit_texture.py (1024 px textures and kit map) -> pack_body.py, then copy the files into
assets/characters/bodies/ with their import settings and list the body in bodies.json, which the game reads
to pick a body for each person.

Run it with the Python that has the rig tools' packages (see README.md), from anywhere:

  python make_body.py NAME MODEL.glb --kind player --build 1.0 --yolo yolo11m-pose.pt [--godot godot] [--work DIR]

--build is the body's build on the game's scale (0.92 lean to 1.1 stocky); the game gives each player the
body nearest his skin tone and build. --hem is the shirt's hem as a fraction of the height (default 0.53).
"""

import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
GAME = HERE.parent.parent
BODIES = GAME / "assets" / "characters" / "bodies"
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/characters/bodies/{name}"

[params]

compress/mode=1
compress/high_quality=false
compress/lossy_quality={quality}
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""
SCENE = """[gd_scene format=3]
[ext_resource type="Script" path="res://render_views.gd" id="1"]
[node name="R" type="Node3D"]
script = ExtResource("1")
"""


def run(cmd, **kw):
    print("$", " ".join(str(c) for c in cmd), flush=True)
    r = subprocess.run([str(c) for c in cmd], capture_output=True, text=True, **kw)
    if r.returncode != 0:
        print(r.stdout[-2000:], r.stderr[-2000:])
        raise SystemExit(f"failed: {cmd[0]}")
    return r.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name")
    ap.add_argument("model")
    ap.add_argument("--kind", choices=["player", "referee"], default="player")
    ap.add_argument("--build", type=float, default=1.0)
    ap.add_argument("--hem", type=float, default=0.53, help="shirt hem as a fraction of the height")
    ap.add_argument("--yolo", required=True, help="YOLO pose weights (yolo11m-pose.pt)")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--work", default=None)
    a = ap.parse_args()

    work = pathlib.Path(a.work or tempfile.mkdtemp(prefix=f"body_{a.name}_"))
    work.mkdir(parents=True, exist_ok=True)
    py = sys.executable
    model = pathlib.Path(a.model).resolve()
    prep = work / "model_prep.glb"
    out = run([py, "-I", HERE / "prepare.py", model, prep, "--turn"])
    height = json.loads(out.strip().split("bounds ")[-1])[1][1]

    proj = work / "views_project"
    proj.mkdir(exist_ok=True)
    shutil.copy(prep, proj / "model.glb")
    shutil.copy(HERE / "render_views.gd", proj / "render_views.gd")
    (proj / "project.godot").write_text("config_version=5\n")
    (proj / "render_views.tscn").write_text(SCENE)
    views = work / "views"
    views.mkdir(exist_ok=True)
    run([a.godot, "--headless", "--path", proj, "--import"])
    run(["xvfb-run", "-a", "-s", "-screen 0 1024x1024x24", a.godot, "--path", proj, "--rendering-driver", "opengl3",
         "--resolution", "1024x1024", "res://render_views.tscn", "--", views, f"{height / 2:.3f}"])
    run([py, "-I", HERE / "joints2d.py", a.yolo, views])

    rigged = work / "rigged.json"
    print(run([py, "-I", HERE / "autorig.py", prep, views / "joints2d.json", rigged,
               "--center-y", f"{height / 2:.3f}", "--hem", f"{a.hem * height:.3f}"]))
    BODIES.mkdir(parents=True, exist_ok=True)
    albedo, kit = f"{a.name}_albedo.webp", f"{a.name}_kit.webp"
    print(run([py, "-I", HERE / "kit_texture.py", model, rigged, work / albedo, work / kit,
               "--res-path", "res://assets/characters/bodies/", "--size", "1024"]))
    krb = f"{a.name}.krb"
    print(run([py, "-I", HERE / "pack_body.py", rigged, BODIES / krb]))
    for f, q in ((albedo, 0.85), (kit, 0.9)):
        shutil.copy(work / f, BODIES / f)
        (BODIES / (f + ".import")).write_text(IMPORT.format(name=f, quality=q))

    skin = json.load(open(rigged))["texture"]["skin_ref"]
    index_path = BODIES / "bodies.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else []
    index = [e for e in index if e["file"] != krb]
    index.append({"file": krb, "kind": a.kind, "build": a.build, "skin": skin, "source": model.name})
    index.sort(key=lambda e: e["file"])
    index_path.write_text(json.dumps(index, indent=1) + "\n")
    print(f"body {a.name}: {BODIES / krb}, listed in {index_path.relative_to(GAME)} ({len(index)} bodies)")


if __name__ == "__main__":
    main()
