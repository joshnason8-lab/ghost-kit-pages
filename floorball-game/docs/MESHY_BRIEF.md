# Meshy models: what is in the game, and how more would go in

Since 0.3.0 the players, goalkeepers and referees are the owner's Meshy models, and the stick is the owner's Meshy
stick. **No Meshy credits were spent by the build**: the owner made the models and handed them over. The originals
are not in the repository (28 to 33 MB each); what ships is what `tools/meshy/prepare.gd` made from them.

## What is in the game

| Model | Source | In the game (`assets/characters/`) |
|---|---|---|
| Man (men's players, goalkeepers, referees) | A Meshy character, rigged by Meshy with Mixamo's 23 bone names, with Running and Walking clips; 21,500 triangles, a 4096 px texture | `man.scn` 10,800 triangles (High), `man_mid.scn` 5,400 (Medium), `man_low.scn` 2,700 (Low); `man.jpg` 1024 px |
| Woman (women's players and goalkeepers) | The same kind, 136,500 triangles | `woman.scn` 8,500, `woman_mid.scn` 4,300, `woman_low.scn` 2,100; `woman.jpg` |
| Stick | A Meshy prop with a 4096 px texture (black shaft, light-blue blade), 74,000 triangles | `stick.res` 1,400 triangles, `stick.jpg` 512 px |
| Stick, plain | The same stick untextured (white) | `stick_plain.res` (kept, unused) |

Both people wear a dark-blue kit with light-blue trim. The game recolours it to each team's colours in the shader
(game/rigged_body.gd): the texture's dark blue becomes the shirt, shorts or socks (told apart by how high each
vertex stands at rest, baked into the mesh), its light blue the trim; the shoes keep their own colours; a
goalkeeper's legs become his long trousers and he wears a helmet with a face cage (made in code); the skin takes
each player's tone.

## How the models move

The game still poses its own simple skeleton every frame (game/body.gd, game/player.gd: the run, the shot, the
tackle, the goalkeeper's saves, the referees' signs, the stick in the hands) and the model follows it bone by bone
(game/rigged_body.gd). Each model bone is first turned once so that it points as the game's bone does at rest (the
game's limbs hang straight down; the models stand in an A-pose), and from then on turns as the game's bone turns.
After that the model's own arms reach for the stick (two-bone IK on its own arm lengths), sliding along the shaft
when the place the game wants is beyond reach, so the hands never leave the stick.

The models' own Running and Walking clips are kept in the scenes but not played: the game's stride is matched to
the ground covered, and the arms are on the stick.

## Remaking them

```
godot --headless --script tools/meshy/prepare.gd -- character man.glb man 10000 5000 2800 1024
godot --headless --script tools/meshy/prepare.gd -- character woman.glb woman 10000 5000 2800 1024
godot --headless --script tools/meshy/prepare.gd -- prop stick.glb stick 1200 512
```

The tool cuts each mesh with Godot's own simplifier (only triangles are dropped, so skin weights and UVs stay),
shrinks the texture and saves the scenes. `tools/meshy/view.tscn`, `match_view.tscn`, `close_view.tscn` and
`keeper_view.tscn` take pictures to check them (xvfb-run, see their first lines); `tools/meshy/grip_check.tscn`
measures how far the hands are from the stick.

## Another model

Any Meshy person rigged with Mixamo's bone names (Meshy's auto-rig names them so) goes in the same way. A kit in
another colour than dark blue needs the shader's kit test changed (game/rigged_body.gd, `main` and `trim`).
