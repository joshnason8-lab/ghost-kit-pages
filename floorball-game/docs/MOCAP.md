# Motion capture: what the players move with

Since 0.5.0 the players and referees walk, jog and run with real people's movements: stride cycles from the
**CMU Graphics Lab Motion Capture Database** (mocap.cs.cmu.edu, Bruce Hahne's BVH conversion). Licence: "free for use
in research and commercial projects worldwide". The Licences screen credits it: *Motion capture data from
mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.*

## The clips used

| In the game (`assets/mocap/`) | CMU clip | What it is | Captured at |
|---|---|---|---|
| `walk.json` | **35_01** (subject 35, "walk"), its second full cycle | a walk, 1.12 s a cycle | 1.28 m/s, 1.43 m a cycle |
| `jog.json` | **35_17** (subject 35, "run/jog"), its first full cycle | a jog, 0.73 s a cycle | 3.13 m/s, 2.30 m a cycle |
| `run.json` | **16_55** (subject 16, "run"), its second full cycle | a fast run, 0.60 s a cycle | 4.19 m/s, 2.51 m a cycle |

One cycle each (left foot forward to left foot forward), 33, 22 and 18 frames at 30 a second, 9 to 14 KB each. The
BVH files are not in the repository: they come from the mirror at
`https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/<SSS>/<SS>_<TT>.bvh` (for example
`data/035/35_17.bvh`).

## How they were made

```
python3 -I tools/mocap/bvh_to_clip.py 35_01.bvh walk --report
python3 -I tools/mocap/bvh_to_clip.py 35_17.bvh jog --report
python3 -I tools/mocap/bvh_to_clip.py 16_55.bvh run --report
```

The tool (run from `floorball-game/`, writes `assets/mocap/<name>.json`):

1. **Trims** the take to one stride cycle: from one moment the left ankle is farthest ahead of the hips to the next
   (the middle cycle of the take).
2. **Retargets** onto the game's skeleton (game/body.gd: hips, spine, chest, neck, head, both arms, both legs). Each
   CMU joint's world rotation is turned once so that its bone's rest direction (CMU's legs splay 20 degrees, its arms
   stand out level) becomes the game bone's (limbs straight down, trunk up), then made local to the game's parent.
   Units: the CMU leg (thigh and shin) scaled to the game's 0.86 m.
3. **Takes the root motion out**: the cycle is turned so it travels along +Z and the ground it covers is taken away,
   so it moves on the spot. The game's movement (`Player.step()`) stays the only writer of where a player is; the
   clip only gives the hips' small sway (up and down, side to side).
4. **Foot locks**: where a foot is down (slow on the ground, low), its ankle is held at one spot of the floor for
   all its frames down, by two-bone IK on the game's leg; where a straight leg cannot reach that spot (pushing off),
   the hips come down that much, eased over the frames around. Which frames each foot is down is kept in the file.
5. **Loops** it (the last frame's difference from the first spread back over the cycle), **resamples** to 30 frames
   a second, and **stores** each frame as the hips' offset and a quaternion per bone, rounded to 3 decimals, with the
   stride, the speed and how far the captured trunk leans.

## How the game plays them (game/mocap.gd, game/player.gd)

- The cycle's phase moves with the **ground actually covered** (speed x time / the cycle's stride), so a foot that is
  down stays where it landed whatever the speed: no sliding, and the cadence is a real runner's (at a sprint of
  7.6 m/s, 3 cycles a second, 6 steps; the old code stride, 1.55 m, took 9 to 10 steps a second).
- **Blended by speed**: walk to jog between 1.3 and 3.1 m/s, jog to run between 3.1 and 4.2, the run above. Every
  cycle starts at the same foot, so they blend at the same phase. Below 0.9 m/s the pose made in code takes over
  (standing, shuffling, turning on the spot).
- **Any direction**: the legs turn up to 70 degrees toward the way he moves while the trunk keeps facing where he
  faces; moving backward the cycle plays backward.
- **The floorball layer on top**: the hips come lower than a jogger's (a floorball player runs bent at the knees),
  the knees bending by IK so each foot stays where the capture put it; the trunk bends forward over the stick by
  what the captured runner does not already lean; the arms stay on the stick (the stick and hands are the code's,
  as before). A referee runs with the captured arms.
- **Not for goalkeepers**: their stance, shuffles and saves stay as made in code.
- **Light**: three small files read once; per person and frame, two clips sampled and blended (17 bones) and two
  legs' IK. The Low graphics level plays them as the others do: the cost is the CPU's and small (perf below).

`tests/test_runner.gd` (`_mocap`) checks every cycle loads whole, and that a player running at 1.0 to 7.6 m/s,
ahead, on a slant and backward, keeps each foot that is down within 2 cm of where it landed (it measures 2 to 4 mm),
never under the floor. `tools/mocap/gait_view.tscn` takes a strip of pictures of a gait.

## What was looked at and left

| Move | Candidates | Why not |
|---|---|---|
| Turns, cuts | 16_37 to 16_44, 16_51 to 16_54 (90-degree run turns), 102_01 to 102_08, 102_33 | Turning in the game is continuous (the movement turns the body a little every frame, for the AI and the joystick alike). A turn clip has its own path and timing; playing it would mean either the clip moving the player (breaking the one writer of position) or a turn that does not match the path. The legs turning toward the way he moves covers it. |
| Stops | 16_08, 16_57 (sudden stop), 127_05, 127_17 to 127_20 | The same: a stop clip decelerates on its own timetable, the game's players on the movement's. With the phase driven by ground covered, a stopping player's feet stay planted as he slows. |
| Side steps, defensive slides | 102_22 to 102_28, 127_13, 127_14 | Would need a second blend direction for little time on the rink: defenders mostly run at an angle, which the turned legs cover. A candidate for later. |
| Dives, ducking | 127_23, 127_24, 127_29 to 127_32 | Floorball has no diving for field players (playing the ball lying down or on two knees is an offence, 507.8 to 507.11 in docs/RULES.md); the goalkeeper's saves are low kneeling stretches, not dives, and no CMU clip is a goalkeeper. |
| Striking (shots, passes) | 124_07 (baseball swing), 63 / 64 (golf) | A floorball shot is a short wrist-and-shoulder sweep with the blade on the floor; the swings in the library are full-body and high (a high stick is an offence). The shot stays the code's, tied to the stick and the ball. |
| Throwing, catching | 33 / 34 | Only the goalkeeper throws and catches, from his own stance; the clips are standing, two-handed, at chest height. |
| Idles | the "stand" clips | Upright, weight shifting; a floorball player stands bent over his stick, ready. The code's stance stays. |

## Performance

`tests/perf_probe.tscn` (xvfb, this machine's software renderer; the CPU figure is what matters here):

| | Before (0.4.1, code only) | After (0.5.0, motion capture) |
|---|---|---|
| Posing 14 people a frame (12 players, 2 referees, running) | see docs/PROGRESS.md | see docs/PROGRESS.md |

Draw calls and triangles do not change (the same meshes, the same skeletons).
