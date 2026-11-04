# Blender in the foundation's pipeline (headless)

`blender -b --python <script> -- <args>`; no GUI. Blender 4.x: Ubuntu's (`apt-get install blender`, 4.0.2 here) works
- its Cycles has no OpenImageDenoise, so every script turns denoising off (else bakes come out zero, silently).

| Script | What it does |
|---|---|
| `export_obj.gd` | A Godot mesh (.res, every surface) as OBJ for Blender (Godot side: `godot --headless --path <project> -s ...`). |
| `bake_normals.py` | Cycles tangent-space normal map, a detailed mesh onto a light one (selected to active, cage). |
| `bake_normals.sh` | Both, for any game: `tools/blender/bake_normals.sh <project> <hi.res> <lo.res> <out.png> [size]`. |
| `decimate_lod.py` | A character's light mesh by Blender's edge collapse: X-symmetric, hands and head kept denser, UV seams kept, triangulated; prints how far its surface is from the detailed one (and an old light mesh's, `--compare`). |
| `lod_from_obj.gd` | The decimated OBJ as a skinned Godot mesh again: each vertex weighted as the nearest point of the detailed surface (its triangle's weights blended), tangents, Godot's far levels. |
| `make_lod.sh` | Both, for any game: `tools/blender/make_lod.sh <project> <hi.res> <out lo.res> <triangles> [old lo.res]`. |
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

Light meshes (make_lod.sh): measured on Hurling's HD hurler at the same 1,758 triangles, against the detailed
surface - meshoptimizer's level (bake_character's cut until now): 8.8 mm off on average, 56 mm at the 99th
percentile, 100 mm at worst (fingers and the helmet's rim collapsed); Blender's: 2.2, 9.0 and 16.1 mm. The rig test
on the light mesh: 11 failures against 14, 6 joints with no skin to measure against 16 (it is made for detailed
meshes: the detailed one has 3). The officials' light meshes: 1,600 triangles from 4,200 (1.8 and 2.3 mm off).
