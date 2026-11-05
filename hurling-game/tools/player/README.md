# The players' model

The hurlers in the game are the owner's model (`player.glb`, from
[Google Drive](https://drive.google.com/file/d/1WDmggD62izAKyLWvZ6bbfaVwRIKf9pg8/view)), animated with four Mixamo
clips the owner downloaded (`Fast_Run.fbx`, `Baseball_Hit.fbx`, `Baseball_Strike.fbx`, `Golf_Drive.fbx`). Neither is
in the repository (the model is 36.7 MB; Mixamo's files may be used in a game but not handed out as they are): to
rebuild, put the four clips in `src/` under those names; `build.sh` fetches the model itself. It bakes them into
`assets/player/`, which is what the game ships:

- **`hero_hi.res`, `hero_lo.res`**: the body's mesh, moved onto the game's own seventeen bones (`ToonBody.BONES`,
  every rest rotation the identity, arms and legs hanging straight) and cut down for phones: 187,754 triangles to
  5,866 (with levels of 2,930 and 1,757 for far away) and 1,757 for Low graphics. The vertex colour carries each
  point's rest position and whether it is below the knee, for the kit's design and the socks.
- **`hero_albedo.jpg`**: the model's 4096 texture at 1024.
- **`hero_mask.png`**: where the kit is (red the jersey's green, green the gold trim, blue the white shorts, alpha
  the skin), so `game/hero_body.gd`'s shader paints each county's colours on the one model.
- **`hero.json`**: the skeleton's offsets, the kit's mean colours, and the clips as the game's poses (each bone's
  turn a frame, 30 a second): the sprint whole, and about a second and a half of each swing around the moment the
  bas meets the ball, with that moment and the turn that sends the ball the way the man faces.

How: Godot imports the model and the clips with its humanoid retarget (`mixamo_map.tres`, made by `mkmap.gd`; the
`.import` files), so
they share bone names and rest poses; `bake.gd` skins the model into the game's rest stance, moves its weights onto
the game's bones, simplifies it (meshoptimizer, through Godot's LOD generator) and samples the clips;
`make_textures.py` shrinks the texture and finds the kit by its colours.

`tests/clip_view.tscn` draws a clip as a strip of stills, to look at one:
`xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/clip_view.tscn -- /out Baseball_Hit 0.2 1.4`
