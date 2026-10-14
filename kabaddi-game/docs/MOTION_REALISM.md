# Motion realism overhaul

Work in milestones, each measured before and after with `tests/locomotion_check.tscn` (see "Measuring"
below). Milestone A (movement and animation foundations) is done; B to E (tackles, chain tackles, team
defence, events) are to come.

## How a player moves and is drawn (as found)

Players are plain `Node3D` nodes (`game/athlete.gd`) with a custom controller, not `CharacterBody3D`.
There are no physics bodies: the court is flat, and players are kept apart by code. One frame, all in
`_process` (nodes run parent first, so the match, then each athlete, then his model):

1. `game/match.gd` `_process` → `_tick_raid`: AI or input decides a desired velocity; `Athlete.drive`
   accelerates `vel` toward it (18 m/s²) and moves `position`; `face_toward` turns `facing`. Then
   `_separate` (players apart), `_clamp_defender` (court bounds), holders pinned to the raider
   (`position = raider.position + hold_offset`), the struggle (`raider.position += v * dt`), `_release`.
2. `Athlete._process`: the node turns to `facing`; `_pose` sets the model's pose parameters (speed,
   crouch, lean, reach ...) from the state.
3. `HumanModel._process` (`game/human_model.gd`): `_animate` builds the hand-made pose on the code
   skeleton (13 joints), `_apply_moves` lays a running clip over it (`move_*`), `_apply_clip` the state's
   clip (stances, moves, falls ...), then `RiggedBody.drive` (`game/rigged_body.gd`) turns the mesh's
   bones to follow the code skeleton and grounds the body. That is the only place bone poses are written
   (bone indices cached at load).

Positions are written by `Athlete.drive` and, in `match.gd`, by placement at the start of a raid, the
spacing (`_separate`), court clamps, holders, the struggle, releases and the bench; all within the match's
frame, before the athletes pose. No two systems write the same pose in conflict: the layers in step 3 are
intended (each lays its pose over the last), and the rig writes the bones once.

## Milestone A: what was wrong and what changed

Measured problems, with where they came from:

| Problem | Cause |
|---|---|
| Joints jumping up to 177 degrees in one frame | `HumanModel._animate` set knees, elbows, spine, chest and head one Euler angle at a time (`kn_l.rotation.x = ...`). Godot rebuilds the other angles from the last frame's rotation, which the clips had blended into, so clips leaked into later frames; near 90 degrees (dives, falls) the angles flip branch. The neck was never set at all. |
| Running clip switched ~55 times a minute, cross-fades restarted mid-fade (pose snaps) | `_apply_moves` re-chose the clip every frame with no hysteresis; switching again mid-fade restarted from the half-faded clip. |
| A clip still fading out dropped outright | `play_clip` kept one fading clip; a third arriving cut it off. |
| Body turning at up to 2500 deg/s | `Athlete.drive` and `face_toward` turn by a fraction per frame with no limit, and the node followed `facing` directly. |
| Feet sliding over the floor | Grounding (`RiggedBody._ground`) set the body's height but never held a foot in place; crouched players took half their legs from a running clip and half from the hand-made gait, two different strides; looping stance clips kept a share of the legs while the player moved. |
| Players jumping 0.4-5 m in one frame | `_begin_setup` put the raider at the start spot outright; `_release` put a defender 0.44 m out. |

Changes:

- **Every joint set whole** (`_animate`): rotations assigned as full vectors, neck included, so each frame
  starts from the hand-made pose alone.
- **One final pose stage** (`HumanModel._settle`): when a clip changes under a fading one, a running clip
  switches mid-fade, or any joint would turn faster than 1200 deg/s (40 degrees a frame at 30 fps, 20 at
  60), last frame's pose is kept as an offset that fades out over 0.18 s (inertial blending). Every
  transition starts from the pose on screen, whichever layer changed.
- **Running clip hysteresis** (`_apply_moves`): another clip must fit clearly better (score margin 0.3)
  and the current one has had 0.3 s; crouched and upright gaits switch at different crouch levels.
- **Legs from one source**: a running clip drives the legs, pelvis and hip height in full; a crouch
  only softens its trunk and arms. A stance clip hands the legs to the running set while the player moves.
  Footage clips (version 1) are applied as rotations, knees and elbows as hinges.
- **Measured motion drives the legs** (`Athlete._track_motion`): stride speed and direction come from
  how far the player really moved (whatever moved him), not the velocity he asked for.
- **Body facing on screen kept apart from gameplay facing**: the node turns toward `facing` at no more
  than 900 deg/s standing and 420 deg/s at a sprint. Gameplay angles (aim, contact) still use `facing`.
- **Planted feet** (`RiggedBody._plant_feet`): the sole point touching the floor (heel, ball or toe) is
  held where it is in the world while the body moves over it, with two-bone IK on thigh and shin
  (`_ik_leg`, shared with the old `_reach_down`). It moves to another sole point as the foot rolls, lets
  go as the foot lifts, slides no more than 0.2 m from where the motion puts it, and a foot that the clip
  drags along the floor (a shuffle's trailing foot) steps on instead of sliding: it lifts at once and only
  then swings across.
- **No teleports in play**: the raider walks to the start spot in the setup he already had (placed only
  from more than 7 m away); a released defender is thrown back with a velocity instead of moved, and can't
  grab on again for 0.15 s; a defender who takes hold from further than arm's length closes in at 3 m/s
  instead of appearing at 0.55 m.

Kept as is, on purpose:

- **Custom controller, not `CharacterBody3D`**: there are no colliders to slide along on a flat court;
  spacing between players is part of the gameplay code. Switching would mean collision shapes for every
  player and re-tuning all the spacing, for no gain in this milestone.
- **`_process`, not `_physics_process`**: every step is integrated with its own delta; the match runs as
  one ordered pass per frame. No physics bodies are involved.
- **The animation layers**: no `AnimationTree`; the existing code skeleton and clip pipeline carry all of
  the fixes above.
- **Acceleration (18 m/s²) and speeds**: unchanged, as they set the feel of the controls and the
  balance tuned to the footage; braking and turn limits are on the body as drawn.

### Before and after

`tests/locomotion_check.tscn`, before (0.7.5) and after. The course is the same every run: a raider and a
defender sprint, stop, backpedal, shuffle, pivot and sprint again (18 s each). AI matches play out
differently each time, so the 30 fps match column is three 60 s matches (14 players) each way, as a
range, and the 60 fps column one match each way.

| Measure | Course raider | Course defender | Match, 30 fps | Match, 60 fps |
|---|---|---|---|---|
| Foot skate, median m/s | 0.90 → 0.00 | 0.22 → 0.00 | 0.12-0.14 → 0.00 | 0.17 → 0.00 |
| Foot skate, 90th percentile m/s | 3.06 → 1.22 | 2.46 → 0.37 | 0.92-1.12 → 0.33-0.49 | 1.27 → 0.44 |
| Joints turning > 1200 deg/s ("pops") | 35 → 0 | 2 → 3 | 298-501 → 117-138 | 1399 → 231 |
| Sudden jerks (3x the frame before) | 33 → 7 | 5 → 4 | 435-595 → 278-326 | 1057 → 461 |
| Largest joint step, deg per 1/30 s | 138 → 35 | 49 → 55 | 107-158 → 61-70 | 276 → 72 |
| Body turning > 720 deg/s | 6 → 2 | 1 → 0 | 9-33 → 5-8 | 31 → 4 |
| Fastest turn, deg/s | 1200 → 775 | 900 → 517 | 1662-4635 → 770-784 | 8379 → 802 |
| Jumps in play (> 10 m/s) | 0 → 0 | 0 → 0 | 0-3 → 0 | 6 → 0 |
| Placements (> 1 m at once) | | | 5-9 → 0-4 | 7 → 6 |
| Cross-fades restarted mid-fade | 9 → 6 | 5 → 4 | 269-374 → 163-208 | 379 → 200 |
| Neck left turned after clips, deg | | | 13-24 → 4-6* | 15 → 5* |
| Leg speed vs real speed, 90th pct m/s | 0.00 → 0.31 | 0.00 → 0.33 | 0.00 → 0.26-0.29 | 0.00 → 0.35 |

\* measured during the final stage's fades, not left over.

The course at 60 fps: raider skate 2.84 → 1.60 m/s (90th percentile), pops 110 → 3; defender 2.51 → 0.40,
pops 13 → 2.

The last row is the price of driving the legs from measured motion: the measurement is smoothed over a
few hundredths of a second, so the stride trails a sudden change of speed by about a frame. Before, the
legs read the speed the player asked for, which matched exactly whenever nothing else moved him and was
wrong whenever something did (a hold, a push, the spacing).

Clips still fading out are still let go when a third arrives (28-34 → 35-41 times a match), but the final
pose stage now carries the pose over, so they no longer snap.

**Gameplay unchanged.** `tests/ai_bench.tscn -- 4 1`, two runs of four AI matches each way:

| | Before | After |
|---|---|---|
| Raids | 272 | 267 |
| Successful | 71% | 72% |
| Tackled | 17% | 19% |
| Empty | 6% | 6% |
| Help after the first hold (median) | 0.60-0.67 s | 0.70-0.83 s |

**Cost.** Timing 14 players running about, posed and drawn (headless, 600 frames, two runs each way):
3.3-3.5 ms a frame before, 3.6-3.9 after, about 0.3 ms for the planted feet and the final pose stage.

**Checks.** `tests/test_runner.tscn` passes (181 checks); `tests/compile_check.tscn` 52 scripts, none broken;
`tests/ground_check.tscn` worst 2.5 cm off the floor while on it (2.4 before); the web export builds and
plays its menu match in headless Chromium with no errors; CI builds the Android APK.

Still open after Milestone A:

- Fast action clips (back kick, celebrations, dubki, dodge) are played faster to fit the game's move
  lengths, so arms whip past 1200 deg/s: most of the remaining match "pops" are those, not transitions.
- Some steps still slide (90th percentile 1-2 m/s on the course, 0.3-0.5 in matches): a foot touching down
  while the clip still swings it, the trailing foot of a backpedal at full stretch, and the cut back. The
  touch-down is judged on the pose before the legs reach for their planted feet, so a foot can land a frame
  or two before it is held.
- A few placements remain: players put back in formation between raids from the bench or after a tackle.

## The phone beta's legs

Playing the beta on a phone, the legs still looked herky-jerky. Three causes were found and fixed: the running
clip changing back and forth as a player eased off or turned a little (each change a fresh cross-fade, the legs
jumping between two strides), planted feet let go of in a frame, and the body dropped onto its planted feet by
whatever it took. In a 3-minute AI match, sudden leg steps went from 175 to 128 a player-minute, the hips moving
over 4 cm in a frame from 88 to 40, clip changes from 59 to 45 a minute, and a planted foot's slide from 0.53 to
0.01 m/s (90th percentile). A held, fallen or rising raider's feet are laid flat as before. The details and the full table are in
[REALISM_REVIEW.md](REALISM_REVIEW.md), "Third review".

## Measuring

```sh
godot --headless --path . --fixed-fps 30 res://tests/locomotion_check.tscn -- both 60 --json out.json --log
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --write-movie course.avi \
    --fixed-fps 30 res://tests/locomotion_check.tscn -- view [defender]
```

`--log` prints each jump, facing snap and pop with the state and the clips playing. The view draws the
planted feet's anchors as yellow discs on a 1 m grid. Each frame's real time step is used (under
`--fixed-fps` Godot's steps vary a little around 1/fps), and joint steps are scaled to a 30th of a second, so
runs at 30 and 60 fps compare.
