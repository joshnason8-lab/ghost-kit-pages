# Motion capture: what comes from where

The players move to three kinds of motion:

- **Kicks and strides from Mixamo** (0.4.0):
  - the serve (Kicking), the roll spike (Scissor Kick), the sunback (Mma Kick), the sole spike (Roundhouse Kick) and the knee (Knee Kick Lead);
  - the models' own run and walk.
- **Real jumps from the CMU library** (0.6.0, below).
- **The game's own key poses** (`game/moves.gd`) for the rest.

All of them are converted by `tools/models/fbx_to_move.tscn` into `assets/moves/<move>.json`: a pose every 1/30 s, about 20 to 40 KB a move. Nothing is decoded on the phone but that JSON.

## The CMU library (0.6.0)

The Carnegie Mellon Graphics Lab Motion Capture Database (mocap.cs.cmu.edu), B. Hahne's BVH conversion. Free for commercial use. The Licences screen credits it: "Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217."

### Used

| Move | Clip | What is real, what is the game's own |
|---|---|---|
| Block (`block`) | **118_04**, 1.6 to 3.1 s | **Real:** the dip with the arms swung back, the spring, the landing taken on the knees. **The game's own, in the air:** side on, the right leg raised with its sole to the spike, the arms out (never up: a hand on the ball is a fault). **Throughout:** the head on the ball and the back not folding over the net. |
| Header spike (`head_spike`) | **118_04**, 1.6 to 3.1 s | **Real:** the dip, the jump, the landing. **The game's own:** the arch and the nod at the top, and the arms' swing. |
| Jump for joy (`celebrate`) | **118_04**, 1.6 to 3.3 s | **Real:** the legs (dip, spring, landing). **The game's own:** upright, both arms thrown up. |

**How the clips are fitted to the game:**

- **Timing:** each move keeps its old timing, so gameplay doesn't change.
  - The top of the jump falls at the move's contact moment.
  - The dip is played about 2.4 times as fast as recorded, a quick reactive dip.
  - The landing plays at its own speed.
- **Jump height:** the move's old height (`lift_to`: 0.6 m for the block, 0.68 m for the header spike, 0.38 m for the celebration).
- **Contact rows:** the header spike's and the block's `Moves.CONTACT` rows are measured again on the new poses: the block meets the ball at 2.10 m, the header spike at 2.34 m.

### Considered and left out

- **90_05 to 90_07 (jump kicks):** martial-arts flying kicks off a run-up. Not a takraw block or spike. The roll spike is already a scissor kick from Mixamo.
- **85, 90 (flips, acrobatics):** the bicycle kick is the roll spike, already motion capture.
- **10_01 to 10_06, 11_01 (soccer kicks) and 74_03 to 74_06 (kicks):** a ball kicked along the ground, or a front kick while walking. Takraw's touches meet the ball in the air: the inside of the foot (sila), the instep lifting it (kuda). Nothing in the library does those.
- **86 (long mixed sequences):** nothing in them the game lacks.
- **The header and the feint:** stay the game's own. Their hops are small and quick (0.16 and 0.34 m, under 0.35 s to the top), and a full jump's dip doesn't fit them.
- **The sila, kuda, chest, dig, horse kick, toss and the other celebrations:** no clip of those actions in the library.

## Feet that stay put

A jump is converted on the spot (`root: "feet"`), so where a player stands stays the movement system's to decide:

- **Hips:** measured from his feet while both are down, so the subject's own travel is left out.
- **Vertical:** the rig keeps a foot on the floor while he is on it (`plant`).
- **Horizontal (the lock, `_lock_feet`):** while both feet are down, the hips are moved so that, on our own model, the feet stay where they stood. Our legs aren't the subject's, so his planted feet would otherwise move a little on ours. In the air, the correction carries over from take-off to landing.
- **Blends:** the dip and the landing ease in and out of the ready stance over longer (`blend_in`, `blend_out`).

### The kicks (Mixamo), off one foot

The kicks used to slide their planted feet badly as they blended from the ready stance and back to it: on the man, up to 9.5 cm in one frame (the serve), 21 cm (the roll spike), 21 cm (the sunback), 14 cm (the sole spike) and 10 cm (the knee). They are converted with a lock of their own now (`"lock": "support"`, `_lock_support`):

- **The standing foot held:** the hips are moved so the foot he stands on stays where it is: the left while it is down (the kicks are the right foot's), else the one that is down, until it leaves the floor. Landing (the roll spike), a foot is held a frame or two before it is down, so it comes to rest as it meets the floor.
- **The other foot steps:** where it would move along the floor while still down (the ready stance's feet are not the kick's), it is lifted into a step: raised straight up by its hip and knee (`_lift_foot`, a two-bone solve on our own model), a little more each pass until it no longer slides on either model.
- **Kept on the floor:** the kicks keep a foot on the floor (`plant`), as the jumps do: the woman's legs are shorter, and on the roll spike's landing her feet went up to 10 cm into the floor. (RealBody stopped planting once the hips came within 35 cm of the feet, a guard meant for upside-down poses; a deep crouch on her shorter legs crossed it. It is 8 to 23 cm now.)
- **Where he finishes:** with his feet no longer sliding back to where they started, some kicks end away from it: the roll spike 65 cm (he lands behind and to the side of his take-off), the sunback 24 cm, the sole spike 18 cm. As a kick ends, `Player` moves him there, so the ready stance takes over where the kick left him.
- **Timing unchanged:** each kick's length and contact moment are as they were. Where the ball is met moved with the hips: the sunback now meets it 0.79 m in front of him (1.15 m before: his standing foot had slid forward 36 cm with the step into the kick), the sole spike 0.97 m (1.32 m), the serve 0.92 m (0.70 m), the roll spike 0.73 m (0.58 m). The converter printed the new `Moves.CONTACT` rows; the players stand where the new rows say.

### The test

`tests/test_runner` checks every move from motion capture on the man's and the woman's models (`fbx_to_move.gd`'s `slide`; `godot --headless --path . res://tools/models/fbx_to_move.tscn -- slide` prints it frame by frame): it loads, and while a foot is on the floor it moves less than 3 cm from one frame to the next (0.9 m/s at 30 frames a second).

| Move | Man | Woman |
|---|---|---|
| Serve | 0.0 cm (9.5 before) | 0.5 cm (8.6) |
| Roll spike | 0.0 cm (21.2) | 0.9 cm (19.5) |
| Sunback | 0.0 cm (20.6) | 1.6 cm (19.6) |
| Sole spike | 0.0 cm (13.6) | 0.8 cm (13.1) |
| Knee | 0.0 cm (9.8) | 0.5 cm (8.8) |
| Block | 2.4 cm | 2.0 cm |
| Header spike | 1.8 cm | 1.6 cm |
| Celebration | 1.3 cm | 1.2 cm |

## Performance

Unchanged. The moves are poses read from JSON, as before; nothing new is drawn. `tests/perf_probe.tscn -- all 0,1,2` (`--fixed-fps 30`, a match in each venue) gives the same draw calls and triangles in 0.6.0 as in 0.5.2 at every venue and level: from 72 draw calls and 102k triangles (the National Arena, Low) to 122 draw calls and 315k triangles (the night market, High). The full table is in [PROGRESS.md](PROGRESS.md).

## Rebuilding them

The BVH files aren't in the repository (they run to megabytes). Fetch the clip from the GitHub mirror into a folder of its own:

    mkdir -p /tmp/cmu && curl -sSfLo /tmp/cmu/118_04.bvh \
      https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/118/118_04.bvh

Then run the converter. It prints each move's `Moves.CONTACT` row:

    godot --headless --path . res://tools/models/fbx_to_move.tscn -- /tmp/cmu block

The kicks come from the owner's Mixamo FBX files (not in the repository either): put them in a folder of their own and run the converter on it, a move at a time (`serve`, `roll`, `sunback`, `tapak`, `thigh`) or all of them.

`tools/models/bvh.gd` reads a BVH into a Skeleton3D and an Animation, as an FBX would be read:

- the CMU back renamed to the models' (LowerBack, Spine, Spine1 become Spine, Spine1, Spine2);
- metres at 0.0564 a unit (its legs as long as the man's);
- 120 frames a second resampled to 30.
