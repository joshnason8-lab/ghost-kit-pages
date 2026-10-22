# The players' model

The netball players in the game are the owner's model (`player.glb`, a Mixamo-rigged netball player in a navy and
light blue dress, from [Google Drive](https://drive.google.com/file/d/1oanBoio6KVpuOcwgiglwNZZiayZHfRsQ/view)), with
its own Mixamo clips (Walking, Running) and the owner's Mixamo sprint, **Fast_Run**, which Hurling's players use too.
The model is not in the repository (34 MB): `build.sh` fetches it into `src/` and bakes it into `assets/player/`,
which is what the game ships. The sprint is committed as poses already (`clips/fast_run.json`, copied from Hurling's
`assets/player/hero.json`, where it was baked from the owner's `Fast_Run.fbx` onto the same seventeen bones), so no
Mixamo file is needed to rebuild.

- **`hero_hi.res`, `hero_lo.res`**: the body's mesh, moved onto the game's own seventeen bones (`ToonBody.BONES`,
  every rest rotation the identity, arms and legs hanging straight) and cut down for phones: 187,060 triangles to
  5,840 (with levels of 2,920 and 1,460 for far away) for Medium and High, and 1,460 for Low. The vertex colour and
  UV2 carry each point's rest position, for the bib.
- **`hero_albedo.jpg`**: the model's 4096 texture at 1024.
- **`hero_mask.png`**: where the kit is (red the dress's navy, green the light blue panels and trim, blue the hair,
  alpha the skin), so `game/hero_body.gd`'s shader paints each team's colours on the one model and gives each player
  her own skin tone; the white socks and shoes stay white. Imported without mipmaps or compression (the atlas's
  islands are small: far away they would run into each other) and without the alpha border fix (which would rewrite
  the colour channels wherever there is no skin).
- **`hero.json`**: the skeleton's offsets, the torso's measurements for the bib (`torso`), the kit's mean colours
  (`ref`), and the clips as the game's poses (each bone's turn a frame, 30 a second; `left_forward` the time the
  left thigh is furthest forward, so the game can lock a clip to the stride).

How: Godot imports the model with its humanoid retarget (`mixamo_map.tres`, made by `mkmap.gd`; `src/player.glb.import`),
so its bones have Godot's humanoid names; `bake.gd` skins the model into the game's rest stance (its feet as they
were bound: the retarget's rest fixer turns the foot bones level, which would tip the toes up), moves its weights onto
the game's bones, simplifies it (meshoptimizer, through Godot's LOD generator) and samples the model's own clips;
`make_textures.py` shrinks the texture and finds the kit by its colours.

To see the result up close: `xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/player_view.tscn -- /out [0-2]`
(four teams from the front, the back and the side; the run at walking, jogging and sprinting speeds).
