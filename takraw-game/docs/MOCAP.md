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

`tests/test_runner` checks each of these moves on the man's and the woman's models: it loads, and while a foot is on the floor it moves less than 3 cm from one frame to the next (0.9 m/s at 30 frames a second). On the man they move at most 2.4 cm (block), 1.8 cm (header spike) and 1.3 cm (celebration).

## Rebuilding them

The BVH files aren't in the repository (they run to megabytes). Fetch the clip from the GitHub mirror into a folder of its own:

    mkdir -p /tmp/cmu && curl -sSfLo /tmp/cmu/118_04.bvh \
      https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/118/118_04.bvh

Then run the converter. It prints each move's `Moves.CONTACT` row:

    godot --headless --path . res://tools/models/fbx_to_move.tscn -- /tmp/cmu block

`tools/models/bvh.gd` reads a BVH into a Skeleton3D and an Animation, as an FBX would be read:

- the CMU back renamed to the models' (LowerBack, Spine, Spine1 become Spine, Spine1, Spine2);
- metres at 0.0564 a unit (its legs as long as the man's);
- 120 frames a second resampled to 30.
