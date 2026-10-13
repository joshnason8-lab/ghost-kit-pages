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
| Planted foot's speed along the floor (90th percentile / worst) | 0.24 / 1.72 m/s | 0.15 / 0.22 m/s |
| Raider's lean: early, halfway, end of the hold | 17°, 37°, 58° | 18°, 32°, 62° |
| Lies once down, against the way the hold pulls him | 5° | 5° |

| `drag` (driving for the line as hard as he can, as the AI does) | V2 | Now |
|---|---|---|
| How it ends | reaches the line 2.3 s into the hold | taken down 6.2 s into the hold |
| Holder's body moved along the floor | 2.52 m, smoothly | 0.51 m, a few cm at a time |
| Held ankle from its hold (worst) | 0.153 m | 0.000 m |
| Free foot on the floor while not hopping | 49% | 99% |

AI bench, four matches each (V2 and now): tackles 23 and 27 of about 120 raids; holds ending in a takedown 15
and 20 of 40; raids where the raider got home still held 6 and 7; raid points 137 and 130. A lone ankle holder
now stops a driving raider instead of being slid to the line, and that moves the game a little toward the
defence.

**Remaining limitations:**

- With other holds on him as well, the raider is still carried along by the struggle rather than stepping.
- The hips sink at most 0.3 m for a held leg. A raider pulled further than that would show the held leg short
  of its hold (no scenario reaches it).

### The chain tackle's fall and getting up (2:59-3:03)

| | |
|---|---|
| Functions found responsible | `Grapple.update` let every holder go in the same frame, 0.7 s after the takedown, before the raider was down. `Match._tick_post` then gave every leg holder the same 1.2 s get-up from lying (a kneeling holder too) and stood the rest straight up, so they rose in step. On the way down, the grapple's body-follow overshot, `_tick_post` drove the holders a second time with their last velocity, and the grapple's moves fed the holder's running gait. The bodies shook by up to 0.2 m a frame and the hands came 0.2-0.4 m off. |
| Fix | Each holder lets go at his own moment after the raider lands (`Grapple.takedown`): leg first, ankle a moment later, arms round the middle last. Each rides him down until he lets go. Each gets up from where he is at his own pace (`Match._get_up_from_hold`): from the floor, up off his knees, or straightening from a bend, and waiting if he is under the raider. Only the grapple moves a holder, and only part of the way each frame. |
| Tests | `tackle_check`, all 15 scenarios (`chain`, `crowd`, `join`, `thigh` and `waist` most of all), with a new `recovery` measure: when each holder let go, how and when he was up. `test_runner` at a fixed 30 fps, as CI runs it. `locomotion_check` (the course and a 60 s match within their usual range). |
| Recording | `chain` from above, V2 and now side by side |

| `chain` | V2 | Now |
|---|---|---|
| Holders let go (s after the takedown) | 0.70, 0.70, 0.70 | 0.87-1.07 |
| Holders up again (s after the takedown) | 1.90, 1.90 (in step), 0.73 | 1.67, 1.87, 2.27 |
| How the kneeling thigh holder gets up | from lying on the floor | off his knees |
| Grip all through the fall, 90th percentile (ankle, thigh, block) | 0.069, 0.119, 0.195 m | 0.074, 0.079, 0.018 m |

With four holders (`crowd`) they let go together at 0.70 s in V2, and over 0.77-1.07 s now. Each is up on his
own (1.57-2.17 s), not the two leg holders together. The raider no longer moves along the floor once he is down
(fastest 0.77 m/s in V2, 0 now).

### The lion jump out of an ankle hold (2:52-2:54)

| | |
|---|---|
| Functions found responsible | `Match._raider_escape` let go of the hold in the frame the jump was called for, while the jump clip was still in its crouch with both feet on the floor. `Match._release` had the holder getting up in that same frame, his hands opened where they had held (`Grapple._open_hands`), and "Lion jump!" and "Broke free!" went up at the press. `_release` also reset the raider to "raid", so the jump was started over. In the air `Match._move_raider` kept speeding him up. |
| Fix | The escape is still decided at the press, but done with the body (`Match._tick_escape`). The raider gathers himself on his free leg for 0.18 s, still held. The hold lets go as he springs, halfway to the jump clip's own takeoff (`MocapClip.takeoff`). The foot comes out of the hands in 0.07 s, and his speed is set as he leaves the floor. The holder's hands stay on the leg as it is torn out of them, so his arms are pulled after it. He lies there 0.3 s, then gets up. The messages go up as the hold lets go. A jump that does not slip the hold is stopped by it: he comes back down on his free foot, still held. |
| Tests | `tackle_check` `escape` with a new `escape_timing` measure, and a new `stopped` scenario (a jump the hold keeps); all 16 scenarios; `test_runner` |
| Recording | `escape`, V2 and now side by side, close up and from the side |

| `escape` | V2 | Now |
|---|---|---|
| From the jump called for to the hold letting go | 0.03 s | 0.23 s (gathering 0.18 s, then the push-off) |
| From the hold letting go to both feet off the floor | 0.03 s | 0.03 s |
| His speed over the floor, landing against taking off | 5.1 m/s faster | the same |
| The holder's hands out from his shoulders, the 0.3 s after | 0.42 m | 0.55 m (reaching after the leg) |
| The holder lying where the leg left him | 0.03 s | 0.30 s |
| "Lion jump!", "Broke free!" | at the press | as the hold lets go |

### A dubki with the ankle still held (3:19-3:24)

| | |
|---|---|
| Mechanics, checked | A dubki is meant to slip arms round the middle, sometimes a thigh hold, never a held ankle (`Grapple.ESCAPES`, `best_escape`), so the ankle holding on is right. But the recorded `slip` raid had no waist hold when he ducked: the helper sent for the waist took the free leg (a thigh hold), the dubki slipped that, and he took the waist only afterwards. The scenario now brings him in from behind, so it is the ankle and arms round the middle. |
| Functions found responsible | `Match._raider_escape` let the arms go at the press; `Match._release` threw the holder back at 3 m/s. `Athlete._pose` kept the one-leg stance only in "held", so the dubki's clip and squat took both legs: he squatted 0.36 m on a held foot. `Match._move_raider` drove a held raider's sidestep 0.71 m across the floor. |
| Fix | The arms slip as he is down under them (`Match._tick_escape`, `MocapClip.ducked`). The holder's arms slide off the trunk and he straightens up where he was (`rise`). A move made with the ankle held (a dubki, a sidestep, gathering to jump) is made on the free leg: the one-leg stance stays, he ducks his top half and dips on the free leg (`Grapple.DUCK_SINK`), no hop starts mid-move, and a held sidestep is not driven across the floor. |
| Tests | `tackle_check` `slip` (now ankle and arms round the middle, which hold slipped checked), `duck`, a new `sidestep`, with a new `dubki_held` measure; all 17 scenarios; `test_runner` |
| Recording | `slip`, V2 and now side by side, close up and from above |

| | V2 | Now |
|---|---|---|
| `slip`: arms let go after the dubki is called for | 0.03 s | 0.13 s (as he is down under them) |
| `slip`: his middle's drop in the duck | 0.36 m | 0.09 m, on the free leg all through |
| `slip`: the slipped holder, the frame after | thrown back at 1.77 m/s | straightening up where he was |
| `slip`: held ankle from its hold, the whole hold (worst) | 0.451 m | 0.000 m |
| `duck` (ankle only): middle's drop / free foot planted | 0.35 m / 8% | 0.06 m / 100% |
| `sidestep` (ankle only): body moved / held foot off its hold | 0.71 m / 0.136 m | 0.00 m / 0.000 m |

### Ordinary AI matches, audited

| | |
|---|---|
| Asked | Proof that the corrections hold in ordinary AI matches, not only in the scripted close-ups: 100 or more deterministic AI-v-AI raids, with the distributions and worst cases of contacts, contact-anchor errors, unexplained corrections, conflicting states, sharp speed changes, duplicate events, tackle phases, bodies inside one another and softlocks, checking the gameplay logic and what is drawn alike. |
| How | A new `tests/raid_audit`: four whole AI-v-AI matches on Pro from fixed seeds (about 120 raids), every frame of every raid, every player who was on the mat when it began. Run on the V2 build and on this one. A match now takes its seed from its config (`Match._ready`). The defence coach's reaction times now come from numbers of its own: `DefenceCoach._react` drew on the engine's global ones, which the sounds and the HUD use too. So the same seed plays the same match in any process. |
| Functions found responsible | `Match._tick_post` ended neither a wind-up nor a dive that the raid's end caught, nor the raider's own move: 57 softlocks in V2, players frozen in a pose until the next raid. `Match._check_contacts` let a dash shove a held raider out from among his holders. `Match._separate` kept no one off a held raider and no one apart after the raid; it moved players 60% of an overlap in a frame and pushed bodies lying on the floor. Joint pops came from limbs swung onto the rig where the placeholder limb's direction flips. Found after the first four tasks: a held raider turned at a free raider's 8 rad/s, swinging his waist holders round at 9-12 m/s. `RiggedBody._sink_to_hold` and `_held_legs` moved the hips in one frame when a hold let go or a held leg was the one he stood on (a lion jump out of a hold threw his middle up 0.3-0.6 m; a caught back kick dropped it 0.75 m). `Grapple._footwork` took up a hop frozen by a second hold, yanking him 0.42 m in a frame. The plant after a dubki cut his speed to a third in a frame. `Match._put_out` and `_react` cut get-ups, falls and moves short at the raid's end, and a raider put out stood frozen, then slid to the bench. |
| Fix | `_tick_post` finishes each move the raid's end caught, and reactions to the end of the raid wait until the player is up (`_react_as`). A dash into a held raider only bumps into the struggle. `_separate` keeps standing players off a held raider and off bodies on the floor, never pushes a body on the floor or in the grapple, and never moves anyone faster than 3 m/s; players keep apart after the raid too. A last pose stage, `RiggedBody._limit_turns`: no bone turns faster than 1,200°/s. A held raider turns at most 1.5 rad/s (`HELD_TURN`). The hips come up out of a sink, or onto a leg let go of, at 2.5 m/s at most (`SINK_RISE`), and down onto the other leg at 3 m/s (`SETTLE_DROP`). A hop is dropped when another hold comes on. The plant sheds a burst over a step (`PLANT`). Players put out finish what they are doing, then walk off. |
| Tests | `raid_audit` on V2 and now. Two runs of it in separate processes give the same events and scores in all four matches; one match traced, the same place and state for every player in every frame. `tackle_check`, all 17 scenarios; `test_runner` at a fixed 30 fps, as CI runs it; `compile_check`. |
| Recording | A new AI-v-AI match (seed 3), not scripted: the TV camera all the way through, then passages from the follow camera |

| Four AI matches on Pro, every frame of every raid | V2 | Now |
|---|---|---|
| Raids (tackles, escapes) | 118 (20, 28) | 120 (27, 23) |
| Holds checked: valid / invalid | 89 / 0 | 103 / 0 |
| Grip, hands from the part held: median / 99th percentile / worst | 0.061 / 0.231 / 0.674 m | 0.066 / 0.123 / 0.212 m |
| Held foot from its hold: 90th / 99th percentile / worst | 0.474 / 1.343 / 1.506 m | 0.000 / 0.000 / 0.078 m |
| Speed changes over 40 m/s² (frames; share of holders' frames) | 3,740; 48% | 1,575; 4% |
| Sharpest speed change | 410 m/s² | 261 m/s² |
| A body's middle moving over 0.2 m beyond the body in a frame: frames / worst | 124 / 0.46 m | 132 / 0.32 m |
| Joint pops, bone-frames over 40° in a 30th of a second / worst | 12,673 / 180° | 8,891 / 40° |
| Bodies inside one another, frames over 5 cm | 4,783 | 3,621 |
| A held raider shoved (episodes) | 3 | 0 |
| Duplicate or impossible events; points not adding up | 0; 0 | 0; 0 |
| Softlocks | 57 | 0 |
| Each holder letting go / up again after a takedown (median, worst) | 0.73, 0.73 / 1.93, 1.93 s (all alike) | 0.93, 1.23 / 1.77, 2.37 s |

The full tables, with every tackle phase, are in `docs/TACKLE_SYSTEM.md` ("Ordinary AI matches, audited").

**Still not right:**

- **Middles jumping.** About as many frames as in V2 have a body's middle jumping over 0.2 m (132 against 124),
  though the worst is lower (0.32 m against 0.46 m). About half are the hand-made ankle dive, grounded on the
  diver's chest as he goes down; the rest are mostly getting up, and coming out of a lion jump's gather.
- **Speed changes.** A dive's launch and a defender being nudged aside still change speed in a frame.
- **Bodies inside one another.** Still 3,621 frames over 5 cm, mostly round a held raider, where bodies are meant
  to touch.
- **Joint turns.** The last pose stage hides joint flips (0.65% of bone-frames) rather than removing their cause.
- **With other holds on him**, the raider is still carried along by the struggle rather than stepping (as in the
  first task).
- **The audit's own effect.** An audited match is repeatable, but the recording was not the same match frame for
  frame. (Put down here to its reads of the skeletons, wrongly: see below.)

### What the audit left, fixed

| | |
|---|---|
| Asked | Fix what the audit of ordinary matches still found: middles jumping in a frame, speed changing in a frame (a dive's launch, defenders nudged aside), joint flips hidden rather than removed, a raider under two or more holds carried along rather than stepping, and the audit's own effect on the match. |
| Functions found responsible | The audit's reads of the bodies change nothing. The audit itself re-seeded each match after `Match._ready` had drawn the toss from its seed (`raid_audit._play`), and the engine's first six frames are not a 30th of a second even at a fixed frame rate, so a match begun among them (the first in any process) parts from the same seed begun later. Joint flips: `RiggedBody._swing` turned each limb from its rest direction, a turn that flips half round when the limb points nearly opposite it; `_flatten` flipped a foot pointing straight down. Middles: `RiggedBody._ground` set the body on its lowest point anew each frame, so the hips moved in a frame whenever that point changed (a diver's chest going below his feet) or the pose did (a get-up clip, a hold's sink, a spring). Speed: `Match._defender_tackle` set the dive's full speed at once; `_separate` moved players aside in a frame; `_tick_escape` set a lion jump's speed at once; `_attach` and `Grapple.update` stopped a raider dead and swung holders round; `_evade` ran defenders into the court's edge. Holds: `Match._move_raider` slid a raider with any hold but a lone ankle along the floor. |
| Fix | The audit no longer re-seeds and, like the new `tests/match_record`, starts each match once the frame steps are steady. Each limb bone is swung from where its parent carries it; a foot on its toes is not laid flat. `RiggedBody._limit_height`: the hips rise at most 4 m/s and drop at most 5 m/s, the feet kept on and out of the floor. The dive drives off over 0.14 s from the speed he had; players steer round one another and anyone standing is eased aside; the lion jump's spring builds at 35 m/s²; a raider caught on the move carries on into the hold; a holder is brought round at most 35 m/s²; an evasion pulls up short of a line. With one leg held he hops on the other (ankle or thigh, with arms round him or not); with both held he stays put; held only round the middle he steps a foot at a time. Details: `docs/TACKLE_SYSTEM.md`, "What the audit left, fixed". |
| Tests | `raid_audit` on the audit's build and now (four matches, 120-odd raids); the audit with and without its reads, compared every frame; the first match replayed in the same process; a rendered recording against the audit, every frame; `tackle_check` (17 scenarios, with new feet measures); `test_runner` at a fixed 30 fps, as CI runs it; `compile_check`. |
| Recording | `waist` close up and `chain` from above, before and now side by side, at half speed. Seed 1's match rendered with the movie writer (`tests/match_record`) is the audit's first match, frame for frame: every player's place, state and timer the same in all 10,506 frames of its 32 raids. |

| Four AI matches on Pro, every frame of every raid | Before | Now |
|---|---|---|
| Raids (tackles, escapes) | 122 (23, 34) | 120 (21, 30) |
| A body's middle moving over 0.2 m beyond the body in a frame: frames / worst | 113 / 0.35 m | 4 / 0.20 m |
| Speed changes over 40 m/s²: frames (per 1,000 body-frames) | 1,490 (3.2) | 408 (0.9) |
| ... of defenders standing ready / diving / holding: share of those frames | 0.3% / 12.2% / 3.9% | 0.0% / 4.1% / 0.7% |
| Joint turns held back by the last pose stage (share of bone-frames) | 0.65% | 0.30% |
| ... asking for 120° or more in a 30th of a second (one match, every body) | 565 | 0 |
| Bodies inside one another, frames over 5 cm | 2,922 | 2,374 |
| Holds valid / invalid; held foot from its hold, 99th percentile | 94 / 0; 0.000 m | 83 / 0; 0.000 m |
| Duplicate or impossible events; points not adding up; softlocks | 0; 0; 0 | 0; 0; 0 |
| A recording of seed 1 against the audit's first match | a different match | the same, all 10,506 frames |
| The audit with and without its reads (four matches) | byte-identical (42,287 frames) | byte-identical (43,468 frames) |

| Held by (`tackle_check`) | Before | Now |
|---|---|---|
| A thigh hold (`thigh`) | slid 0.84 m | 4 hops |
| Arms round his middle (`waist`) | slid 0.50 m, feet sliding 0.72 m/s | steps, feet sliding 0.09 m/s |
| Both legs and more (`chain`, `crowd`) | slid 0.71, 0.85 m | stays where he is |
| The ankle and arms round him (`slip`) | 0.37 m slid between hops | hops only |

In eight random AI matches each, more raids end in a tackle (15% against 21%) and fewer out of bounds (13% against
8%), with the same share of successful raids (65%): a raider held by both legs can no longer be carried over a
line.

**Still not right:**

- **Speed changes** left (0.9 per 1,000 body-frames): a dive's first frames (4% of dive frames), a holder kept clear
  of a raider still carried on by the hit, and the raider's own sidestep (1.9 times top speed, by design).
- **Bodies inside one another:** fewer in the struggle than before, but players outside it still meet a little more
  often than when they were pushed apart in a frame (1.8 against 1.5 frames per 1,000 body-frames).
- **An ankle dive's first grip** is looser (0.21 m as the hands close, within the 0.3 m contact): the dive reaches
  him two frames later in its arc.
- **A held foot** can be short of its hold for a frame or two (worst 0.10 m) as a new hold's sink comes in.
- **The steps** held round the middle are made by the body (the trailing foot on an arc), not a captured clip.

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
