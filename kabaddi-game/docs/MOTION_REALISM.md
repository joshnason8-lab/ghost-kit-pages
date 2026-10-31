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

## Recorded crouched walks (0.10.0)

The owner added the CMU Graphics Lab Motion Capture Database to the shared assets and asked every game to use real
recorded movement wherever it is clearly more real than what the game has. The moves that have a clip here already
play studio motion capture (Mixamo's clips are capture too) or match footage, so the CMU takes were weighed against
those clips and against the moves made by hand, on the game's own body, in the course and in AI matches.

- **Taken: a crouched walk, forward and back.** A defender standing ready is in a crouch, and in a 5-minute AI match
  the players on the mat spent 320 player-seconds creeping forward or back in it, more than in any other way of
  moving. The running set had no crouched walk: the walk and the backward jog carried his legs upright under his
  crouched trunk, so a creeping defender stood up and strode, or jogged backwards at half speed, and sank back down
  when he stopped (creeping forward at 0.8 m/s his middle was 0.93-1.02 m off the floor, against 0.90 m standing
  ready). Two takes of CMU subject 136 ("Weird Walks") fill the gap:
  - **136_09**, Walk Crouched, 7.27-8.48 s (one stride, 1.22 s): `move_crouch_walk`;
  - **136_11**, Walk Backwards Crouched, 4.80-6.28 s (1.48 s): `move_crouch_back`.

  Knees bent, short steps, the hips down: creeping forward at 0.8 m/s his middle is now 0.87-0.95 m up. Before and
  after: [img/crouch_walk_0.10.0.jpg](img/crouch_walk_0.10.0.jpg).
- **How they play**: as the other running clips do (`HumanModel._apply_moves`): the clip nearest his way, pace and
  crouch carries the legs, played at the rate that keeps the feet still, the rig holding the planted feet,
  cross-faded with the clip before and laid over the hand-made pose by his pace, the stance clip keeping his trunk
  and arms while he barely moves. A clip has no root motion, only how fast and which way it goes; the game moves the
  body. The CMU subjects' legs are longer for their height than the game's, so a clip's speed is the one the game's
  own skeleton goes at taking its strides (`MocapClip.foot_speed`): 0.81 and 0.64 m/s, where the subject went 0.96
  and 0.75. A crouched clip carries a player only up to 1.8 times its speed, the fastest a running clip is played,
  going by his smoothed pace; one he is not in yet, only up to three quarters of that. Running in to tackle at 3 m/s,
  a defender takes the jog with his crouch in the trunk, as before. The same holds for the shuffle (the goalkeeper's
  sidestep): past 4 m/s sideways, the strafe.
- **Not taken**, each against what the game has:
  - the basketball defensive slide (102_22-28) against the shuffle: captured at about 3 m/s, more than twice the
    0.5-1.2 m/s a kabaddi defender shuffles at in the match footage, so it would play at its slowest with the feet
    sliding, and its stance is narrower and more upright than the sidestep's;
  - the basketball feints (102_18, 102_19) against the dodge: running drives at 2.8 m/s, not a sidestep on the spot;
  - the karate kicks (front kick 135_04, side kick 135_11, roundhouse 135_07) against the kicks: head high, the foot
    0.9-1.4 m up, where a kabaddi kick is a low toe touch or a back kick;
  - "A pulls B; B resists" (18_03, 19_03) against a held raider's pull: the one resisting stands up and steps back,
    where a held raider drives low for the line;
  - "avoid attacker" and "defensive guard pose" (76_03, 76_04) against the evade and the raider's stance: a boxer's
    guard and hops;
  - the crouched walks on the toes (136_13-16): the hips higher than the flat-footed ones, and a defender's crouch
    is lower;
  - "Run Side Step" (127_13, 127_14): a change of lane at 3 m/s, not a dodge;
  - subject 139's "Sneak Sideways", "Ducking" and get-ups: the sideways sneak drifts forward with the hips barely
    down, and the copies of 139's takes found are byte for byte those of subject 77, so which take each is could not
    be told; subject 111's get-ups from the floor are not an athlete's.

  Nothing in the library is a kabaddi move: no holds, chains, dives at a leg or dubki. Those keep their Mixamo clips
  or the hand-made pose.
- **Checked**:
  - `test_runner`: each CMU clip (a BVH source) loads, and on the game's skeleton at its own speed a planted foot
    slides 0.18 and 0.17 m/s (the median; the captured walk's 0.17, the other running clips' 0.22-0.36; under 0.2
    passes); a crouched defender creeping forward and back is carried by them and running in by the jog; the
    licences screen credits the database.
  - Three seeded 60-second AI matches, every player on the mat (`locomotion_check`), before and after: joints
    jumping in a frame (pops) 123 → 88, sudden steps 267 → 196, a planted foot's slide 0.05 → 0.03 m/s (90th
    percentile), a straight leg standing ready 1.0 → 0.6 % of the time and a splayed one 2.3 → 1.4 %. But the
    running clip changes 41 → 44 times a minute, and cross-fades restarted 187 → 253 times: a defender creeping on a
    slant goes between the crouched walk and the shuffle (the final pose stage takes those in).
  - The course (`locomotion_check`, its defender now creeping forward and back too): a foot slides less of the time
    it is down creeping back (10 → 7 %), running in (38 → 30 %) and chasing (20 → 13 %), but more creeping forward
    (6 → 16 %: the crouched walk's low steps bring the foot near the floor early as it lands) and in the backpedal
    after the run in (5 → 22 %).
  - `motion_audit`: its encounters are the same as before. Over six seeded AI matches the drawn body turned back on
    itself 618 → 737 times, nearly all of it standing ready, barely moving, with no running clip in the pose: the
    matches went differently (the players' own reversals 202 → 216), not the clips. `tackle_check` 19 of 19,
    `raid_audit`, `ai_bench` and `fit_audit` as before.
- **Cost**: two clips of 14 and 18 KB (the BVH takes they came from are 0.86 and 1.09 MB, and are not in the
  repository: `tools/mocap/README.md` says where they are). `perf_probe` before and after, every ground on Low and the dome on Medium and High: the same draw calls,
  primitives, objects and video memory to the unit (on Low, the dome's 100 and 218, 634k, 317, 164 MB). The
  players' animation, timed alone (14 players creeping, shuffling and running in, 900 frames, three runs each): 4.90
  ms a frame before, 4.92 after, within the runs' own spread (4.75-5.09). Nothing is different on Low.

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
