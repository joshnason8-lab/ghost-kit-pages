# Blender in the foundation's pipeline (headless)

`blender -b --python <script> -- <args>`; no GUI. Blender 4.x: Ubuntu's (`apt-get install blender`, 4.0.2 here) works
- its Cycles has no OpenImageDenoise, so every script turns denoising off (else bakes come out zero, silently).

| Script | What it does |
|---|---|
| `export_obj.gd` | A Godot mesh (.res, every surface) as OBJ for Blender (Godot side: `godot --headless --path <project> -s ...`). |
| `bake_normals.py` | Cycles tangent-space normal map, a detailed mesh onto a light one (selected to active, cage). |
| `bake_normals.sh` | Both, for any game: `tools/blender/bake_normals.sh <project> <hi.res> <lo.res> <out.png> [size]`. |

Normal maps: bake a model onto its own cuts (tools/bake_character.sh makes both from one source, in the rig's T); a
different model's surface does not match and the map is noise. Measured on Hurling's hurler: the HD pack's 23,468
triangles onto its 5,866-triangle cut, 2048 px, about 2 s.
