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
- **`hero_albedo.jpg`**: the model's 4096 texture at 1024 (Low); **`hero_albedo_2k.jpg`** the same at 2048 for
  Medium and High (VRAM-compressed with mipmaps, as the 1024 is), and **`hero_mask_1k.png`** the mask below at 1024,
  its classes found at the full 4096 (imported as the 512 one is). `game/hero_body.gd` loads them through
  `Game.tex` (autoload/game.gd `HD_TEX`).
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

## Motion capture (CMU)

Two of the players' moves are real recorded movement from the CMU Graphics Lab Motion Capture Database
(mocap.cs.cmu.edu; "free for use in research and commercial projects worldwide"; credited in Settings > About >
Licences), stored as `assets/player/mocap.json` (25 KB: each frame the 17 bones' turns in degrees, Euler YXZ, and
the hips' shift; which feet are planted; how far along her path she is):

| Move | Clip | Used for |
|---|---|---|
| `slide_left`, `slide_right` | **102_27** DefensiveMoveSideToSide, 0.77-1.30 s (one cycle; mirrored for the other way) | any player going sideways to where she faces (marking, leading with her eyes on the ball) under 4 m/s: the defender's side-step instead of a run crabwise, its cycle locked to how far she goes sideways |
| `land_r`, `land_l` | **16_08** run/jog, sudden stop, 0.80-1.67 s (mirrored for the left foot) | a catch on the move (over 1.5 m/s): she comes down on the landing foot the footwork rule gave her, steps the other foot down beside it and stops on them, played in step with how far she has really gone |

`cmu_bvh.py` (python3 and numpy) reads the BVH files, puts CMU's 31 joints onto the game's 17 bones (each bone's
world turn taken from the joint carrying the same segment, corrected for the two rest poses: CMU's T with its legs
apart, the game's arms and legs hanging straight), scales by leg length, trims, resamples 120 to 30 fps, finds the
planted feet (an ankle low and still), pins each planted run in place with two-bone leg IK (lowering the hips where a
leg could not reach, so no knee pops), closes a cycle's loop, and keeps root motion apart: the clip's travel is a
list of distances the game follows (the player's position is only ever written by `Player.advance`), and what is
left of the hips' movement is a shift of the body. Mirrored clips are made in the tool.

Rebuild: `tools/player/fetch_cmu.sh [scratch_dir]` downloads the two clips (from the GitHub mirror
`una-dinosauria/cmu-mocap`; the raw BVH files are megabytes and are not committed) and writes `mocap.json`.
`tests/test_runner` checks each clip loads and that a planted foot moves less than 2 cm over a planted phase as the
match plays it; `tests/player_view.tscn -- OUT 2 moves` draws the moves on the model.

Compared and left as they were (the hand-made or Mixamo moves fit netball better): the run (Mixamo Walking, Running
and Fast_Run, already captured and looped, vs 102_05/102_10, a stride or two of a basketball run); cuts and turns
(102_01-04, 102_33: the clip would have to turn the player; the game turns her itself); the pivot (102_29: real pivot
footwork but basketball's ball protection, low and swung overhead, and its turn would have to drive her facing); the
quick stop 127_19 and jump stop 127_21 (the body swings far off her path and the landing foot shuffles; a two-foot
landing is only for a player all but stopped); defending the ball at 0.9 m (102_22-28 keep the hands low and wide;
netball's arms go up over the ball); the leap (13_10 is tiptoe reaching with 10 cm hops, 49_04 a running bound forward, arms out for balance rather than up for the ball); passes
and catches (33_01/34_01 are short, easy American-football tosses, the hands never above 1.3 m; no chest, bounce or
lob pass in the library); the shot (124_03-06 are basketball shots from a set point at the forehead, with a hop; a
netball shooter holds the ball above her head and does not leave the floor).
