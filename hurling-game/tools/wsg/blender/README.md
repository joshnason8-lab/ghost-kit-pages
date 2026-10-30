# Blender in the foundation's pipeline (headless)

`blender -b --python <script> -- <args>`; no GUI. Blender 4.x: Ubuntu's (`apt-get install blender`, 4.0.2 here) works
- its Cycles has no OpenImageDenoise, so every script turns denoising off (else bakes come out zero, silently).

| Script | What it does |
|---|---|
| `export_obj.gd` | A Godot mesh (.res, every surface) as OBJ for Blender (Godot side: `godot --headless --path <project> -s ...`). |
| `bake_normals.py` | Cycles tangent-space normal map, a detailed mesh onto a light one (selected to active, cage). |
| `bake_normals.sh` | Both, for any game: `tools/blender/bake_normals.sh <project> <hi.res> <lo.res> <out.png> [size]`. |
| `bake_light.py` | Cycles light on a game's built geometry (sun, sky, shadows, a bounce) onto WsgLightBake's second UVs, and the shadow on the ground under it: `--base <dir>/<arena>_<time> [--samples 64]` (reads `<base>.obj/.json` from `WsgLightBake.export`, writes `<base>_light.png`, `<base>_ground.png`). Python needs numpy (`apt-get install python3-numpy`). |

Normal maps: bake a model onto its own cuts (tools/bake_character.sh makes both from one source, in the rig's T); a
different model's surface does not match and the map is noise. Measured on Hurling's hurler: the HD pack's 23,468
triangles onto its 5,866-triangle cut, 2048 px, about 2 s.

Baked light (WsgLightBake): for the stands, walls and roofs a game builds in code (Hurling's Geo), on the tiers that
light them per vertex without shadows (GL Compatibility; Low and Medium). The game exports each arena with its sun
and sky as it sets them (`WsgLightBake.export(mesh, light, base)`; Hurling: tools/env/bake_light.sh), Cycles bakes,
and at run time `WsgLightBake.load_for(mesh, base)` gives the mesh its second UVs - made the same way at run time,
so only the maps ship - and `WsgLightBake.material(lm)` draws it unshaded, vertex colour times the map (one texture
read). A map is used only on the geometry it was baked for (`signature`). Measured on Hurling: 15,000-21,000
vertices per stadium, unwrapped in about 0.1 s; a 2048 map and a 1024 ground map in about 2 minutes on 4 CPU cores
at 64 samples. Cycles' sun light comes out S / pi of its strength S: the script multiplies Godot's energy by pi.

Why not Godot's LightmapGI: its baker runs only in the editor (a button on a saved scene; no script call) and needs
the scene's meshes saved in it, where these stadiums are built at run time; and it would bake every tier's light
the same. Cycles from the command line bakes in CI or on any machine, onto the geometry the game builds.
