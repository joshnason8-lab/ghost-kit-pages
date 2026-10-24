# The player model and its animations

Since 0.3 every player and official is the owner's model: one athlete rigged to Mixamo's skeleton (a GLB of about
195,000 triangles with a 4096 px texture), moved by six Mixamo animations the owner chose. The source files are the
owner's and are **not** in this public repository; what is here is what the game needs, built from them.

## What is in the game

| File | What |
|---|---|
| `assets/models/player.glb` | Two light copies of the model on its own skeleton (23 bones): `player_lod0`, 3,600 triangles with a 1024 px texture (Medium and High graphics), and `player_lod1`, 1,400 triangles with a 512 px texture (Low). 2 MB. |
| `assets/models/anims/*.res` | The clips, baked onto that skeleton: `run`, `dive`, `reach`, `turn`, `kneel_down`, `kneel` (the owner's), `walk` (the model's own), `dodge` and `idle` (recorded motion capture, from the CMU library: below), and held poses for the officials, the crowd and a cheer: `stand`, `whistle`, `signal_out`, `signal_foul`, `signal_end`, `cheer`, `seated`, `clap`. |
| `game/model_body.gd` | The body: the model, its AnimationPlayer, the kit recoloured in the shader, the head turned toward the play. |

## How a clip is chosen (`Athlete._animate`)

| The player | Clip |
|---|---|
| running over 2.6 m/s | `run`, at his speed ÷ 3.5 m/s (0.5-1.9 times) |
| moving slower | `walk`, at his speed ÷ 1.4 m/s |
| still (a player or an umpire) | `idle`, looping, each man from his own point in it |
| dodging (DODGE, or an AI defender reading a dive) | `dodge`, fitted to the dodge (0.4 s) or faster if he moves faster; mirrored for a cut to his right |
| sitting in his square | `kneel_down` (sped up), then `kneel` |
| giving a kho or reaching | the second half of `reach`, fitted to the act |
| diving (sky dive, pole dive) | `dive` from 0.25 s, ended at 0.9 s: Mixamo's clip is a dive into water and goes under the floor after that |
| lying after a dive | `dive`'s last frame, held |
| getting up | `idle`, blended in |
| round the pole | `turn`, its middle, fitted to the turn |
| an umpire's signals | `whistle`, `signal_out`, `signal_foul`, `signal_end` |

A pole dive round the other side plays the clip mirrored.

## Motion capture (since 0.5)

Two movements are recorded people, from the **CMU Graphics Lab Motion Capture Database** (mocap.cs.cmu.edu: "free for
use in research and commercial projects"; credited in the Licences screen). The BVH files are not in the repository;
only the baked clips are.

| Clip | From | What it is | Where |
|---|---|---|---|
| `dodge` | **127_11** ("Run Left"), 0.57-1.17 s | A runner's hard cut to his left: the outside (right) foot planted, a low lean, the push off; heading +42°. | DODGE, and the AI defenders' dodge from a dive. Mirrored for a cut right. |
| `idle` | **77_02** ("standing"), 0.6-5.6 s, looped | Standing at ease, the weight shifting from foot to foot. The actor was looking at the floor, so the neck and head keep a third of their own movement (the game turns the head to the play). | Any player or umpire standing still, and getting up after a dive. |

How they are made:

1. **Fetch** the BVH from the GitHub mirror of the BVH conversion (mocap.cs.cmu.edu's certificate chain is broken):
   `https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/127/127_11.bvh` and `.../077/77_02.bvh`.
2. `python3 tools/models/bvh_to_json.py BVH_DIR JSON_DIR` takes each clip's window, at 30 frames a second (every
   fourth of the 120), and takes out its **root**: the hips' path over the ground, smoothed, and its heading (where it
   travels; standing, where the hips face on average). What is left moves in place, so the game's movement system
   stays the one writer of a player's position and facing. A looping clip's last half second blends into the frames
   just before its first.
3. `godot --headless --path . -s res://tools/models/retarget_bvh.gd -- JSON_DIR res://assets/models/anims` puts the
   model's rig in the BVH skeleton's rest pose bone by bone (as `retarget.gd` does for Mixamo's), carries each frame's
   world rotations across, scales the hips by the two legs' lengths, sets the clip down so planted toes stand on the
   floor, and **locks the feet**: through each contact (a toe low and nearly still, the root moving under it) the hip
   and knee are turned, two-bone IK in the knee's own plane, so the toe stays where it landed. The root stays in the
   clip's metadata (`root`: x, z in metres and heading, a frame each; `speed`), for its playback rate and for the
   test. Saved compressed (Animation.compress): 4 KB and 18 KB.

`tests/test_runner.gd` (`_mocap`) plays each clip on the model with its root and checks no planted toe slides more
than 3 cm (the bake measures the worst at 0.0 cm on the dodge and 0.4 cm on the idle, from 2.0 and 1.3 cm
before the locks), and that a dodge cuts the way the player goes.

**Considered and left out** (the CMU index has about 2,500 clips): its runs and sprints (subjects 09, 16, 35, 127,
143) are jogs at 3-4 m/s, where a chaser here runs at up to 7, and the owner's Mixamo run is itself recorded; its dives
(127_23, 128_10) are dives over an obstacle into a forward roll, not kho kho's flat dive to touch, and the owner's dive
is kept; its quick stops (127_19, 16_08, 143_02) stop over 0.8 s with a turn, where a player here stops in half that
and the AI changes its mind every few frames, so a committed stop would fight the movement system; its tight turns
(102) are basketball turns, not a turn round the post, which the owner's `turn` is; its basketball signals (26-41)
are not a kho kho umpire's; its side-steps (127_13, 127_14) move aside at 1 m/s, a fifth of a dodge here, so the feet
would skate; the defensive slides (102_22-28) are basketball's low shuffle, which a kho kho defender does not use.

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
