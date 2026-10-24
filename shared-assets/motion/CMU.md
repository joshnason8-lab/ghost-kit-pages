# Motion capture: the CMU library

The Carnegie Mellon Graphics Lab Motion Capture Database: about 2,500 real recorded movements from 144 subjects.
The owner asked each game to use it wherever a real movement beats the hand-made one.

## Licence

"Use this data! This data is free for use in research and commercial projects worldwide." (mocap.cs.cmu.edu).
Bruce Hahne's BVH conversion adds no restrictions. Credit it in each game's Licences screen as:
"Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217."

## Getting the files

mocap.cs.cmu.edu is on the owner's allowed list, but its HTTPS certificate chain is incomplete, so tools refuse it.
Use the GitHub mirror of the BVH conversion instead. Every session can reach it:

    https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/<SSS>/<SS>_<TT>.bvh

`<SSS>` is the subject number padded to 3 digits and `<SS>_<TT>` is the clip as listed, e.g. `data/102/102_05.bvh`
or `data/006/06_02.bvh`. `cmu-index.txt` (here) describes every clip. CMU advises starting with the higher-numbered subjects.

Don't commit the raw BVH files to the repo (they run to megabytes). Commit only the trimmed, retargeted and compressed
result your game uses, and list each source clip ID in your licences or docs.

## The skeleton

- 31 joints (Hips, LHipJoint, LeftUpLeg, LeftLeg, LeftFoot, LeftToeBase, ..., Spine, Spine1, Neck, Neck1, Head,
  LeftShoulder, LeftArm, LeftForeArm, LeftHand, ...), ZYX Euler channels, root position.
- 120 fps (frame time 0.00833 s). Resample to 30 fps for phones.
- Units are not metres. Scale by the subject's real leg length (shin offset is about 6.6 units, about 0.43 m).
- Y up. Check the facing (+Z or -Z) on import.
- Retarget to your game's skeleton by bone name and rest pose. Fix foot sliding with foot locks. Keep root motion
  separate so your movement system stays the one writer of each player's position.

## Where to start, by game

| Game | Clips to try |
|---|---|
| Netball | 102 (basketball cuts, feints, pivots, defensive slides, drives), 124_03 to 124_06 (shot, free throw, jump shot, lay-up), 06 (dribbling, for footwork), 33/34 (throw and catch) |
| Floorball | 102 (cuts and turns), 09 / 35 / 38 (runs), 127 / 128 (ducking, quick stops) |
| Hurling | 124_07 (baseball swing), 63 / 64 (golf swing), 09 / 16 (runs), 33/34 (catch) |
| Sepak Takraw | 10 / 11 (soccer kicks), 86_01 / 86_03 / 86_06 (jump kicks), 74 (kicks), 85 / 90 (flips, acrobatics, for the bicycle kick), 118 (jumps) |
| Kabaddi Raid | 102_16 to 102_28 (evasive walks, feints, defensive slides), 135 (martial-arts stances), 127 / 128 (dives, rolls), 76 (avoidance) |
| Kho Kho Rush | 09 / 16 / 35 (sprints), 127 / 128 (dives, rolls, quick stops), 102 (tight turns) |
| Pok Ta Pok Rivals | 127 / 128 (low lunges, dives, rolls), 10 / 11 (soccer moves for the hip and chest contact), 102 (defensive slides) |

Search `cmu-index.txt` for more (e.g. "jump", "run", "dive", "throw", "catch").
