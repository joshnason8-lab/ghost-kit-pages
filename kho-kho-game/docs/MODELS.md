# The player model and its animations

Since 0.3 every player and official is the owner's model: one athlete rigged to Mixamo's skeleton (a GLB of about
195,000 triangles with a 4096 px texture), moved by six Mixamo animations the owner chose. The source files are the
owner's and are **not** in this public repository; what is here is what the game needs, built from them.

## What is in the game

| File | What |
|---|---|
| `assets/models/player.glb` | Two light copies of the model on its own skeleton (23 bones): `player_lod0`, 3,600 triangles with a 1024 px texture (Medium and High graphics), and `player_lod1`, 1,400 triangles with a 512 px texture (Low). 2 MB. |
| `assets/models/anims/*.res` | The clips, baked onto that skeleton: `run`, `dive`, `reach`, `turn`, `kneel_down`, `kneel` (the owner's), `walk` (the model's own), and held poses for the officials and a cheer: `stand`, `whistle`, `signal_out`, `signal_foul`, `signal_end`, `cheer`. |
| `game/model_body.gd` | The body: the model, its AnimationPlayer, the kit recoloured in the shader, the head turned toward the play. |

## How a clip is chosen (`Athlete._animate`)

| The player | Clip |
|---|---|
| running over 2.6 m/s | `run`, at his speed ÷ 3.5 m/s (0.5-1.9 times) |
| moving slower | `walk`, at his speed ÷ 1.4 m/s |
| still | `stand` |
| sitting in his square | `kneel_down` (sped up), then `kneel` |
| giving a kho or reaching | the second half of `reach`, fitted to the act |
| diving (sky dive, pole dive) | `dive` from 0.25 s, ended at 0.9 s: Mixamo's clip is a dive into water and goes under the floor after that |
| lying after a dive | `dive`'s last frame, held |
| round the pole | `turn`, its middle, fitted to the turn |
| an umpire's signals | `whistle`, `signal_out`, `signal_foul`, `signal_end` |

A pole dive round the other side plays the clip mirrored.

## Rebuilding them

1. **The model.** `python3 tools/models/build_player.py SOURCE.glb assets/models/player.glb` (needs numpy, scipy,
   Pillow, meshoptimizer and xatlas). It welds the vertices by position (the source's atlas has thousands of UV
   islands, whose seams stop any simplifier at about 6,600 triangles), simplifies to each level's budget, unwraps
   the result afresh and bakes the source's texture onto it, texel by texel from the nearest point on the source
   surface.
2. **The clips.** Put the FBX files and the built `player.glb` in a scratch Godot project's `src/` folder and run
   `godot --headless --path SCRATCH -s res://retarget.gd -- res://out` (copy `tools/models/retarget.gd` there), then
   copy `out/*.res` to `assets/models/anims/`. The two rigs rest differently (the FBX in a T-pose, the model in an
   A-pose, with different bone lengths and units), so a rotation cannot be copied straight across: the model's rig is
   first put into the FBX rig's T-pose bone by bone, and each frame's world rotations are carried over through that.
3. **Look at them.** `tests/quickshot.tscn -- OUT venue graphics frames...` renders a match on a ground at the
   frames given (`KK_CAM=1` for the close camera).

## The kit

The model's texture paints a light blue shirt and navy shorts and trim. The shader (`ModelBody.SHADER`) finds them by
hue and saturation and paints the side's colours over them, keeping the cloth's shading; the skin takes the player's
own tone the same way; white and hair stay as painted. One material per kit and skin tone, shared.
