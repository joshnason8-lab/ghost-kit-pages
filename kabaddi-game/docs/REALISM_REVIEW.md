# Realism reviews

## Second review (the V2 video): the ankle hold first

The second review asked for one interaction to be made believable before anything else: the ankle hold at
2:43-2:49 of the V2 video, the `tackle_check` `catch` scenario. It saw a defender lying flat who seemed to be
dragged behind the raider, and a raider who stayed steady too long before he fell. It asked for the exact
functions responsible, a fix in the existing GDScript skeletons and pose stages (no ragdoll), automated tests,
a side-by-side video, and measured results.

| | |
|---|---|
| Functions found responsible | `Grapple.update` moved the holder's whole body every frame to keep his reach on the ankle: a still lying pose slid along the floor, and at the takedown it shook back and forth by 15 cm a frame. `Match._move_raider` slid the raider's body toward the line all the time, and `Grapple.update` dragged the held foot along with it. `RiggedBody._ground` stood him on the held leg (his free foot hung above the floor), skipped the held foot in the air, and moved it off its hold after the IK. The held raider was posed a frame behind his own body (process priority -1). |
| Fix | An ankle hold is two bodies joined at the ankle (`Grapple._ankle`, `Grapple._footwork`, `HumanModel._apply_footwork`, `RiggedBody._sink_to_hold`). The holder stays where his dive put him and is dragged only in short jerks when the raider out-drives him; his arms, chest and knees do the hauling. The raider stands on his free foot, sinks on it as low as the held leg needs, and gets about only by hopping. The leg snaps taut, a haul yanks him back a hop, and he goes down forward, away from the hold, with the foot still held. Details: `docs/TACKLE_SYSTEM.md`, "Second review". |
| Tests | `tackle_check`: 15 scenarios, a new `drag`, and new restraint numbers. `test_runner` at a fixed 30 fps, as CI runs it. `locomotion_check` (the course is unchanged). |
| Recording | `catch`, V2 and now side by side, from the side and close up |

| `catch` (half push) | V2 | Now |
|---|---|---|
| Holder's body slid along the floor while holding | 3.80 m | 0.26 m |
| Holder's body turning back on itself / sharpest change of speed | 16 frames / 261 m/s² | 0 / 22 m/s² |
| Held ankle from its hold (90th percentile / worst) | 0.088 / 0.111 m | 0.000 / 0.000 m |
| Free foot on the floor while not hopping | 40% | 98% |
| Raider's travel made sliding rather than hopping | 100% | 2% |
| Hops on the free foot | 0 | 5 |
| Planted foot's speed along the floor (90th percentile / worst) | 0.24 / 1.72 m/s | 0.15 / 0.27 m/s |
| Raider's lean: early, halfway, end of the hold | 17°, 37°, 58° | 18°, 32°, 62° |
| Lies once down, against the way the hold pulls him | 5° | 5° |

| `drag` (driving for the line as hard as he can, as the AI does) | V2 | Now |
|---|---|---|
| How it ends | reaches the line 2.3 s into the hold | taken down 6.2 s into the hold |
| Holder's body moved along the floor | 2.52 m, smoothly | 0.51 m, a few cm at a time |
| Held ankle from its hold (worst) | 0.153 m | 0.000 m |
| Free foot on the floor while not hopping | 49% | 99% |

**Remaining limitations:**

- With other holds on him as well, the raider is still carried along by the struggle rather than stepping.
- In a pile, the other holders' hands come off in the last 0.3 s of the fall. During the hold their grips
  are as before. Both belong to the chain tackle, which is next.
- The hips sink at most 0.3 m for a held leg. A raider pulled further than that would show the held leg short
  of its hold (no scenario reaches it).

## First review (the 0.7.5 recording): five fixes, and where milestones A-E stand

A review of the 0.7.5 gameplay recording (11 Oct 2026) named five problems. This page answers it: for each, the
code found responsible, the cause, the fix, the tests run and the recordings compared. Details and the full
before/after tables are in `docs/TACKLE_SYSTEM.md` ("Review fixes"). After that, an honest account of
milestones A-E: what was done, what was only partly done, and which tests check it.

The timestamps the review gave are in the recording sent with it, which was put together from:

| Recording | Source |
|---|---|
| 12-16 s, 45-53 s | AI match, TV camera, 5-9 s and 38-46 s into it |
| 80-83 s, 155-157 s | AI match, follow camera, 73-76 s and 148-150 s into it |
| 163-167 s | `tests/tackle_check` `catch` scenario (an ankle hold), 6.2-10.2 s |
| 175-178 s | `chain` scenario, 5.4-8.4 s |
| 185-189 s | `flurry` scenario, 5.8-9.8 s |

Every "before" below is the code that made that recording (commit 950a7a8), measured with the same tests, on the
same scripted raids and the same seed. Body motion is how fast the hands, shoulders, waist and feet move
against the player's own root: a pose that does not move reads near zero.

### 1. The ankle hold

| | |
|---|---|
| Code | `Match._move_raider` (the struggle), `Match._check_end` (when he goes down), `Athlete._pose` ("held", "holding"), `HumanModel` (clips), `Grapple` |
| Cause | The struggle was one hidden number (`raid.progress`) rising evenly to 1, then the fall clip from its upright start. Nothing drew it: the raider looped one clip, the holder held one lying pose. |
| Fix | Each holder hauls in rhythm (`Grapple.haul`); a haul draws the held leg back and lifts it, the holder's arms bend, the raider is pulled back and loses balance mostly on the hauls. `HumanModel._apply_struggle` draws it over the clips (the raider topples further, sinks, flails for balance, jerks on each haul; the holder lifts his chest and drives with his knees). A fall starts from the frame nearest his pose. |
| Tests | `tackle_check` (14 scenarios), `test_runner` (all checks), `locomotion_check` (unchanged) |
| Recording | `catch`, before and after, side by side |

| Measured | Before | After |
|---|---|---|
| Holder's body motion while holding | 0.10 m/s | 0.43 m/s |
| Raider's lean from upright: early, halfway, end of the hold | 16°, 14°, 18° | 17°, 38°, 58° |
| Held foot dragged along the floor over the hold | 1.41 m | 0.45 m |
| Free foot sliding (90th percentile) | 1.02 m/s | 0.70 m/s |
| Hands to the held leg (90th percentile) | 0.051 m | 0.075 m |
| Hold duration | 3.40 s | 3.57 s |

### 2. The chain tackle

| | |
|---|---|
| Code | `Match._check_end`, `Grapple.add`, `Grapple.update`, `HumanModel._apply_struggle` |
| Cause | Three holders brought him down as soon as the struggle passed half, 0.23 s after the last one's hands were on him; each hauled to his own rhythm; a block (in front) leant back like the rest. |
| Fix | A team-mate joining falls in with the first holder's haul (they heave together); the pull on the raider is all their hauls together; a block drives into him; he goes down only once every hold has been held 0.6 s (`Grapple.established`). |
| Tests | `tackle_check` `chain`, `crowd`, `join` |
| Recording | `chain` from above (`view chain plain high`), before and after |

| Measured | Before | After |
|---|---|---|
| Last helper's hold to the takedown | 0.23 s | 0.60 s |
| First holder's body motion | 0.08 m/s | 0.50 m/s |
| Grips once on (90th percentile): ankle, thigh, block | 0.13, 0.12, 0.23 m | 0.07, 0.14, 0.25 m |
| Four holders (`crowd`): grips | 0.15, 0.13, 0.17, 0.24 m | 0.08, 0.12, 0.05, 0.11 m |

### 3. Falls and getting up

| | |
|---|---|
| Code | `Match._tick_post`, `Match._end_raid`, `MocapClip`, `HumanModel.play_state` |
| Cause | Told to get up 1.2 s after the takedown whatever the fall was doing (about 0.5 s on the floor); a 1.4 s get-up clip squeezed into 0.9 s; walking off the moment it ended; a standing holder went straight from holding to cheering; holders stood up inside the man on the floor. |
| Fix | A fall knows when it lands (`MocapClip.landing`): the thud and a short give of the body then; 0.9 s down; up over 1.4 s; half a second on his feet before walking. A standing holder goes down with him; anyone getting up beside him steps off him. |
| Tests | `tackle_check` (on the floor, getting up, up to walking, moving while down, standing inside him) |
| Recording | `flurry`, before and after |

| Measured (`catch` and `flurry` alike) | Before | After |
|---|---|---|
| On the floor before getting up | 0.50 s | 1.06 s |
| Getting up | 0.93 s | 1.40 s |
| On his feet before walking off | 0 s | 0.53 s |
| Moving along the floor while down or getting up | 0.76 m/s | 0.00-0.02 m/s |
| Nearest a standing defender is to him while he is down (`thigh`) | 0.14 m | 0.64 m |

### 4. Defensive positioning

| | |
|---|---|
| Code | `DefenceCoach.update` ("working the cover"), `Match.formation_spot` |
| Cause | Every defender stood on an evenly spaced spot at one depth, and the line slid sideways with the raider as one unit. The waiting team stood the same way. |
| Fix | The line curves round where the raider is about to be (0.35 s ahead): straight in front of him a little back, out to his sides up, deeper the further in he is. Every player has his own place in the line, a little deeper or shallower and to one side, and a defender's depth drifts slowly about it. Roles, reaction times, spacing and lanes are unchanged. |
| Tests | `ai_bench`, four matches each; the footage measured the same way (`tools/mocap/raid_events.py`) |
| Recording | AI match from the TV camera, before and after |

| Measured | Before | After | Footage |
|---|---|---|---|
| Defenders' depths, front to back (sd) | 0.12 m | 0.50 m | 0.89-1.12 m |
| Line depth | 4.58 m | 4.44 m | 4.43-4.93 m |
| Nearest defender while he raids | 1.90 m | 2.08 m | 2.26-2.51 m |
| Way home covered as he runs for it | 13% | 24% | |
| Pairs closer than 0.9 m | 0.08 | 0.05 | |
| Raids out of bounds | 6% | 9% | |

The line is still more regular than the footage's, and more raids end out of bounds.

### 5. Events close together

| | |
|---|---|
| Code | `Match._check_contacts` (a grab back at a touch), `Match._raider_escape` and `_raider_dodge`, `Match._attach`, `Grapple.claim` |
| Cause | A touched defender's grab back was given in the same frame as the touch, with no check that his hands could reach. An escape was judged on the defender's tackle name, not the hold, and a move that could not slip a hold still did 20% of the time. "Broke free!" went up with other holds still on him. Two defenders could be given the same leg. |
| Fix | A grab back after a 0.18 s reaction, only within reach of his hands and a step; otherwise his wind-up carries on into a tackle. Escapes judged on the grapple's holds: a dubki cannot slip a held ankle, a jump cannot clear arms round his middle, a sidestep cannot slip hands on his ankle. "Broke free!" only when he is free. A part already held is never given again. |
| Tests | `tackle_check` `flurry`, `slip`, `duck`; `ai_bench` event checks |
| Recording | `slip` from above |

| Measured, AI matches | Before | After |
|---|---|---|
| Grabs back made in the same frame as the touch | 15 of 16 | 0 of 14 |
| Escapes a move could not make | 3 of 23 | 0 of 15 |
| Escapes that left him held, with "Broke free!" | 8 of 23 | 5 of 15, no message |
| Takedowns within 0.6 s of a new hold | (in the recording) | 0 of 12 |

### Also fixed

- The HUD's play-by-play messages were drawn over the middle of the screen, over the holds they named. They
  now sit under the raid strip.
- Two defenders could hold the same leg: a helper's claim on a part was kept after a diver's hands took it,
  and a hold given a part did not check it was free (`Grapple.claim`, `Match._attach`).

### Milestones A-E

What each one set out to do, what is in the game, what is only partly there, and what checks it. "Partly"
means it is in the game but does not yet look or behave as the milestone meant.

#### A. Natural locomotion and animation transitions (`docs/MOTION_REALISM.md`)

| Done | Partly | Checked by |
|---|---|---|
| Feet planted in the world with two-bone leg IK, rolling heel to toe; a final pose stage that blends out of every transition and joint jump; running clips switched with hysteresis, legs from one source; legs following the measured motion; the body turning at a human rate; nothing teleported in play | Some steps still slide (course 90th percentile 1.22 m/s; worst in shuffles and cut-backs, 2.6-3.4 m/s); fast action clips (kicks, celebrations, dubki, dodge) played faster than captured, so arms whip (117-138 joint "pops" a minute in a match); players still placed between raids | `tests/locomotion_check` (course and match), re-run after these fixes: unchanged |

#### B. One believable ankle hold (`docs/TACKLE_SYSTEM.md`)

| Done | Partly | Checked by |
|---|---|---|
| A hold only on real contact (hands swept along their path to within 0.3 m of the leg); hands kept on the ankle with arm IK; the held foot kept where it was caught; a takedown with the foot held; a lion jump out of it; events for each step | Until fix 1, the hold itself was two still poses and a sudden fall. Classic (code-built) bodies still have no hand or foot IK. The dive aims at his middle, not the leg. | `tackle_check` `miss`, `catch`, `escape`, `whiff`; `tackle_reach` |

#### C. Waist holds, thigh holds, chain tackles

| Done | Partly | Checked by |
|---|---|---|
| Every hold on its own part of him (two legs, back, front); helpers claim a free part; holders kept out of each other and of him; grips within a few centimetres once on | Until fix 2, a pile did not work together and went down before the last hold was a hold. Until today, two could hold the same leg. A block's grip is still the loosest (about 0.25 m at the 90th percentile in `chain`). | `tackle_check` `thigh`, `waist`, `chain`, `join`, `crowd`, `committed`; `ai_bench` (holds on a part already held) |

#### D. Defence as a team

| Done | Partly | Checked by |
|---|---|---|
| Roles worked out for the team each frame (line, mark, cover, lane, contain, help); each defender's reaction time; places at least 1.05 m apart; cutting off his way home; helpers claiming holds | Until fix 4, the line was a straight wall. The way home is still open most of the time (covered 14-21% of the time as he runs for it). | `ai_bench` (shape, way home, help timing, depth stagger against the footage); `tests/defence_view` recording |

#### E. Events, scoring, transitions

| Done | Partly | Checked by |
|---|---|---|
| Every HUD message from a logged event; every point given once and every match's points adding up; holders getting up before celebrating | Until fix 5, a grab back at a touch was granted in the same frame with no reach check, an escape was judged on the wrong thing, and "Broke free!" went up while he was still held. Until fix 3, getting up was rushed. Until today, the messages covered the play. | `tackle_check` `touch`, `flurry`, `slip`, `duck`; `ai_bench` (points accounted for; event checks); `test_runner` |

Passing these tests says the rules and the events are right. How it looks was checked separately, frame by
frame, on new recordings of the same scenarios, side by side with the old ones.
