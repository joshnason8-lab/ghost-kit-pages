# Realism reviews

## Third review (the phone beta): eleven notes

The third review came from playing the beta APK on a phone: eleven notes, from the app icon to the legs. Each is
below with what was found and what changed; the numbers are from the tests and AI matches named.

| # | Note | What was wrong | What changed |
|---|---|---|---|
| 1 | Make the painted raider-and-defender picture the app icon | The icon was a placeholder drawing. | The picture is the launcher icon: the adaptive icon's background, framed so his face, his reaching hand and the hand on his thigh sit inside the part every launcher shows, with a plain icon for older launchers (`tools/ui_art/import_art.py`, `assets/icon/`). |
| 2 | The yellow, green, blue and purple figures as the home screen's tile backgrounds | Small grey pose pictograms. | Each tile shows its figure in its own colours: the yellow raider behind Quick Match, the green chain on League Season, the blue celebration on Nations Cup, the purple lunge on Training (`UI.tile`, `assets/ui/art_*.png`). |
| 3 | Menu music from the attached track | No music. | "Indian" by LNPLUSMUSIC (Pixabay), cut into a loop: the opening once, then its middle minute round and round, joined on a downbeat with a 40 ms crossfade, at one steady loudness (`tools/audio/make_menu_music.py`). It fades in on the menus and out as a match starts; Settings has a Music switch. |
| 4 | The lightest players are far too white | The two lightest skin tones (e8b98f, d6a07a) are a pale peach; on the bodies' own tan skin textures they came out washed out, grey-white. | A light and a mid tan (d4966c, cf9069); the four darker tones are unchanged. |
| 5 | A way to break free when tackled, labelled so, and bigger | Dodge was the button, small, labelled Dodge, and a sidestep, which never slips an ankle hold. | While the player's raider is held, Dodge becomes **Break free**: half as big again (72 px), gold and pulsing, with the touch buttons dimmed. It makes the escape that suits the holds on him (a lion jump out of hands on his ankle, a dubki out of arms round his middle, a sidestep out of a thigh hold); Dubki and Lion jump are still there to pick one yourself. A press goes to the nearest button, so the big one does not take presses meant for Dubki. |
| 6 | A kick scores with the foot still far from the defender | A touch or kick was given when the two bodies were within the move's reach, up to 2.2 m apart: the foot did not have to get to him. In two AI matches, the foot was a median 1.09 m from the defender's body at the moment a toe touch was given, and 1.45 m for a back kick; none of 9 back and side kicks given got there. | A touch or kick is given only when the hand or foot, as drawn, is on him: within 5 cm of his legs, trunk or arms (each with its own thickness), checked every frame, and halfway back to the last frame so a fast foot cannot pass through a leg between two. The hand or foot is steered at the nearest of him within its reach, and the body steps in as far as it needs to and no further: the AI's strikes as a lunge, anything else as a short step. From too far off it falls short, and the AI goes for him only from where it can get there. Details below. |
| 7 | Bigger pause buttons | 420 px wide, standard height, 14 px apart. | 560 px wide, 80 px tall (Resume 96), larger text, 18 px apart, and Quit set apart in red. |
| 8 | Points without crossing back over the midline | A held raider was home when he was within 0.86 m of the midline (his reach), stretched out or not. | Held, he is home only with a foot, a knee, his middle or a hand down on the midline or past it. Unheld, he still has to be 0.35 m into his own half. |
| 9 | The next raid starts before the player put out reaches the bench | The next raid started 2.2 s into the set-up, wherever the players put out were. | It waits until they are sitting or within 1.5 m of their places in the sitting block (at most 9 s), and they jog there faster between raids. |
| 10 | The blue figure for the player of the match | A small pictogram. | The blue celebrating figure, large, on the result screen. |
| 11 | Leg movement still herky-jerky | See below. | See below. |

### Touches and kicks (6)

`Match._aim_limb` steers the toe touch's foot at the nearest point of the defender's shins, a back or side
kick's at a shin or thigh, and the hand touch's hand at his nearest shoulder or thigh, each over the move's own
curve (out and back), aimed at his surface. `RiggedBody._reach_kick` bends the leg to it with the same two-bone
solver the hands use, twice: the foot turns with the shin, so after one pass the toe was up to 0.1 m from where it
was aimed, and a back kick from 0.85 m got to the defender only as it came back. `Match._check_contacts` gives the
touch on the limbs as drawn (`_limbs`, `_gap_to`).

How far each gets to a defender who stands still, the raider not stepping (centre to centre): a hand 1.0 m, a toe
touch 1.1 m, a back kick 1.0 m. Before, touches were given out to 1.3-1.7 m for the hand and 1.5-2.2 m for kicks.
To keep the touches a raider ought to make, the body now steps in (`Match._strike_vel`): at the defender, wherever
he goes, by as much as the hand or foot is short (to 0.9, 0.9 and 0.75 m apart), by the time it is fully out. The AI's
strike is a lunge at up to 95% of his speed; the player's touch, a kick and a toe tap take a step at up to half his
speed, so from much further off they fall short. A lunge used to run straight on along his facing for most of the
move, whatever the distance, past the defender or short of him. The AI goes for a touch only from where its step
gets there (`Match._strike_from`: the reach, plus the step at the speed it is coming in at, plus the defender's own
step toward it), not from about 2 m whatever its speed.

| AI matches | Before | Now |
|---|---|---|
| Touches given with the hand or foot on the defender (two matches, before) | 21 of 66 | all |
| A toe touch's foot from the defender as it was given (median) | 1.09 m | 5 cm or less |
| Back and side kicks given that got to him (two matches, before) | 0 of 9 | all |
| Attempts that land: hand touch, toe touch, back or side kick | (given from where they stood) | 67%, 86%, 53% |
| ... missed because the defender pulled back | | 12 of 66 hand touches, 9 of 59 toe touches |
| Hand or foot touches a raid | 0.73 | 0.47 |
| Raids succeeding, tackled, out of bounds, empty | 61%, 21%, 11%, 7% | 53%, 29%, 12%, 6% |
| Raid points a raid | 1.06 | 0.84 |

Before: 16 matches, 491 raids, on the last build; now: 8 matches, 236 raids (`ai_bench`, Pro). A raider now has to get
within about a metre of a defender for a touch, so the defence catches him more often, mostly with ankle holds and
grabs back at the touch. Points add up in every match, and every event check is clean (no escape a move could not
make, no two holds on one part, no takedown within 0.6 s of a new hold).

Still to do: AI raiders go for a touch from 1.55 m from the nearest defender (median; 1.78 m before, 2.04 m in the
India v Pakistan footage). The game's lunge is the body's ordinary acceleration, so it carries him less far than a
real raider's long step, and he has to start closer.

A defender who pulls back from a touch (`Match._evade`) now gets out of its reach; before, the touch was given
anyway. `tackle_check`'s `touch` and `flurry` scenarios have the defender stand his ground, as they test the
scoring and what follows a touch. In `flurry` the raider now steps in for the touch as the next defender dives:
that diver's hands are up to 0.38 m off the ankle for a few frames as they close (0.02 m once he holds it).

### The legs (11)

Three causes, measured in a 3-minute AI match (`locomotion_check`, every player's legs every frame) and on the
locomotion course:

- **Clip changes.** The running clips (jog, run, strafes, backpedal, shuffles) were picked from the raw speed and
  direction every frame, so a player easing from a jog to a walk, or turning a little, swapped clips back and forth,
  each swap a fresh 0.2 s cross-fade restarted part-way, and the legs jumped between two strides at different
  points of the cycle. Now the speed and direction are smoothed (0.18 s), a new clip has to be clearly better to
  take over, the cross-fade is longer (0.28 s, was 0.2), and the new clip starts at the same point of its stride as
  the old (`MocapClip.stride`: the left leg furthest forward, about to come down), so the feet carry on rather
  than swap.
- **Feet let go in a frame.** Every planted foot was let go in one frame when the body left the floor or came off
  its feet, and a sole was laid flat by how near the floor it was that frame, so a foot coming down snapped flat.
  Now the planted feet are let go over 0.08 s, held where they were for that moment, and a plant takes hold over
  0.1 s (was 0.06). On his feet and free to move, a sole lies flat and lifts over 0.1 s, and is laid flat only from
  a little off flat (15-35 degrees), so a stride's push off and heel strike are the clip's own
  (`RiggedBody._release_plants`, `_flatten`).
- **The body dropping onto its feet.** Re-grounding the body each frame brought it down onto the planted feet by
  whatever it took, often more than 4 cm in a frame. Now the planted feet bring it down at most 3 cm a frame; a
  foot that would need more comes off the floor and is let go of instead.

| 3-minute AI match, every player | Before | Now |
|---|---|---|
| Sudden leg steps (a joint turning far more than the frame before), per player-minute | 175 | 128 |
| ... while running | 4,132 in all | 2,688 |
| Middle (hips) moving over 4 cm in a frame, per player-minute | 87.8 | 39.8 |
| Largest joint step a frame (99th percentile) | 26.7° | 22.7° |
| Clip changes a minute | 59.2 | 44.8 |
| Pose pops a minute | 9.2 | 5.1 |
| Planted foot sliding (90th percentile) | 0.53 m/s | 0.01 m/s |

What is left is mostly defenders edging about in their ready stance and the frames in the middle of a cross-fade.
With the floor contact off altogether, the raider on the course still has about 60 sudden steps: some are in the
clips themselves.

The feet of a raider who is held, down or getting up are laid flat as they were. With the free foot's rules, a held
raider's free foot stood on its toes (on the floor in a fifth of the `drag` scenario's frames, 97% before) and,
caught by three at once and taken down, his feet slid 1.8 m/s. `tackle_check` against the last build now: the free
foot is on the floor 86-100% of the time in the leg holds (88-100% before), and the held ankle is on its hold in
every frame, as before. His feet on the floor slide about as before (90th percentile 0.03-0.17 m/s, 0.07-0.21
before), and a planted free foot's slide is the same at the 90th percentile with one holder, a little higher at
worst (`catch` 0.27 to 0.35 m/s for a frame, `thigh` 0.30 to 0.44) and with two or three holders (0.23 to 0.36
m/s). The hold point itself is hauled further in some (0.27 m in `catch`, 0.06 before): the leg's pose as it is
caught is a little different.

### Tests

`test_runner` (188 checks, at a fixed 30 fps as CI runs it): the back kick now has to reach (from 0.85 m it touches
him; from 1.7 m it falls short and gives nothing), and Break free out of an ankle hold is a lion jump.
`tackle_check`: 17 scenarios as expected.
`compile_check`: 61 scripts. `tests/demo_tour.tscn` plays the home screen, the Quick Match screen and a quick match
with the player's raids made through the on-screen controls, for a recording with sound.

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

### The rest of the list, and what the last fixes broke

| | |
|---|---|
| Asked | Keep going: the middles still jumping, what was left of a dive's launch, and the three things the last round made worse (players outside the struggle meeting more often, an ankle dive's looser first grip, a held foot short of its hold). |
| Functions found responsible | Keeping apart (`Match._separate`) went by where players' feet were, so a defender walked into a holder bent over the raider, and two divers getting up lay inside one another; nothing kept players apart after the raid, or off a team-mate as they walked off put out. The defender clamp (`_clamp_defender`) held a corner defender's place at the sideline but not his speed, so his wind-up started sideways and the dive snapped him back. The defence's dive did not move in its first frame (`_ai_defender` returned before it), and the push-off went at one speed for every dive. The fall limit held the hip joint, while a trunk tipping forward lowered the middle with it. `_plant_feet` judged the floor from the held foot too. Found on the way: `RiggedBody._ground` took "nothing left to stand on" (the standing leg caught as the other was let go of) as an endless sink, which sank the body through the floor for the rest of the raid, or sent it to NaN; after the raid most players were moved twice a frame (`_tick_post` and `_walk_to_positions`); an all out set the tackled last man walking in the frame he began to go down, and his holders were swung round with him as he walked off; an evading defender ran into the court's edge from a sprint. |
| Fix | Bodies kept apart by their trunks, in three dimensions (`_trunk`, `_nudge_body`, `BODY_GAP`), during the raid and after it. The clamp takes the speed into a line with it. The dive moves from its first frame and gets to its speed from however he was moving, no quicker than from a standstill, each dive as far as it always went (the defence's 4.0 m/s out of the wind-up, the player's 5.0 m/s at the button). The limit is on the middle. A held foot is left out of where the floor is, and a free foot is planted once the body is down on it. Nothing to stand on is no sink; each player moved once a frame after the raid; a player brought back down or mid-move finishes it first; an evasion runs no faster than he can stop by the line. Details: `docs/TACKLE_SYSTEM.md`, "The rest of the list, and what the last fixes broke". |
| Tests | `raid_audit` on last round's build and now, eight matches each (seeds 1-8, about 245 raids); a new check in `test_runner` for the leg let go of as the other is caught (it fails without the fix); `tackle_check` (17 scenarios); `test_runner` at a fixed 30 fps, as CI runs it; `compile_check`; `ai_bench`. |
| Recording | The ankle dive (`catch`, a third of the speed) and a dubki with the ankle held (`duck`, half speed), last round's build and now side by side. |

| Eight AI matches on Pro, every frame of every raid | Before | Now |
|---|---|---|
| Raids (tackles, escapes) | 240 (45, 70) | 247 (45, 56) |
| A body's middle moving over 0.2 m beyond the body in a frame: frames / worst | 14 / 0.21 m | 0 / 0.17 m |
| Speed changes over 40 m/s²: frames (per 1,000 body-frames) | 705 (0.77) | 246 (0.27) |
| ... diving / winding up / the free raider: frames | 195 / 84 / 208 | 16 / 2 / 0 |
| Bodies inside one another outside the struggle (per 1,000 body-frames) | 1.82 | 1.47 |
| ... the raider and his holder (per holder's frame) | 0.117 | 0.133 |
| A body moving over 9 m/s in a frame | 17 | 10 |
| Grip, hands from the part held: 99th percentile / worst | 0.12 / 0.22 m | 0.12 / 0.30 m |
| Held foot from its hold: 99th percentile / worst | 0.000 / 0.10 m | 0.000 / 0.18 m |
| Holds valid / invalid; events, points; softlocks | 181 / 0; consistent; 0 | 172 / 0; consistent; 0 |

| Scripted (`tackle_check`) | Before | Now |
|---|---|---|
| `catch`: the ankle dive's first grip (hands from the ankle as they close) | 0.208 m, on the other leg, 0.10 s late | 0.086 m, the near ankle, at 0.77 s as it always was |
| `duck`, `sidestep`: the free foot planted through a held dubki or sidestep | 8%, 63% | all through |
| A held raider's free foot sliding (90th percentile): `catch`, `drag`, `thigh`; `waist` | 0.25, 0.21, 0.23; 0.09 m/s | 0.07, 0.07, 0.18; 0.13 m/s |
| The first grip, hands from the part as they close: `thigh`, `waist` | 0.094, 0.113 m | 0.12, 0.151 m |

**Still not right:**

- **A thigh hold's grip** is looser at its worst (0.30 m for a few frames, against 0.22 m), though as before at the
  median and 99th percentile, and the thigh and waist dives' first grips are looser (0.12 and 0.15 m); not found yet.
- **A held foot** is off its hold in a lion jump's first spring frame, up to 0.18 m (0.10 m before): one frame a jump.
- **The raider and his holder** are inside one another a little more often (0.117 → 0.133 per holder's frame).
- **Speed changes** left (0.27 per 1,000 body-frames): defenders standing ready (as many as before), holders in a
  hold's first frames, a dive's first two frames, getting up, and the raider's own sidestep (over 9 m/s by design).
- **Standing over a man lying flat**, a player is not moved off him, and his legs can be in the other's body.

### The thigh hold's grip

| | |
|---|---|
| Asked | Fix the thigh hold's grip: in AI matches a thigh holder's hands came up to 0.30 m off the thigh for a few frames, and the scripted thigh and waist dives' first grips read looser. |
| Functions found responsible | The scripted first grips were the hands still closing on the hold's first frame (0.12 m, then 0.055 m). In matches: `RiggedBody._ik_two` turned a holder's arm onto the hold from the hand-made pose by the shortest turn, from a forearm pointing 90-160 degrees off, so the forearm's twist, and with the arm folded right up the elbow, flipped from frame to frame; the last pose stage held the flips back (`_limit_turns`), and the hands trailed the thigh by up to 0.4 m; the same twist kept every hold's hands about 0.06 m off the part. And `Grapple.update` carried a holder's being kept clear of another holder into his speed, so a thigh diver backing off to his place went 0.3 m past it, out of reach. |
| Fix | A hand reaching for a hold starts each frame from the arm as drawn the frame before, the wrist keeping the pose's bend and the fingers their grip; a folded or straight elbow bends the way it did. Where the hand goes while a hold closes or lets go is unchanged (between the pose and the hold, by how far the hold has closed): a helper's hands still take the hold's 0.2 s to close, and a hand letting go goes back to the pose over the let-go. Being kept clear moves a holder without becoming speed he carries. Details: `docs/TACKLE_SYSTEM.md`, "The thigh hold's grip". |
| Tests | `raid_audit`, eight matches (seeds 1-8), on the last build, with the arms alone (the same matches, frame for frame) and with both; `tackle_check` (17 scenarios), with each holder's hands traced frame by frame as they close and let go; `test_runner` at a fixed 30 fps, as CI runs it; `compile_check`; `ai_bench`. |
| Recording | `thigh` close up, the last build and now side by side, at half speed: the holder's near arm was held out past the thigh; now it wraps it. |

| Eight AI matches on Pro | Before | Now |
|---|---|---|
| Grip, hands from the part held: median / 90th / 99th percentile | 0.06 / 0.10 / 0.12 m | 0.02 / 0.03 / 0.10 m |
| Worst grip | 0.30 m (a thigh holder's arm flipping) | 0.15 m (a dubki ducking a held thigh out of reach) |
| Holds valid / invalid | 172 / 0 | 191 / 0 |
| Holders' speed changes over 40 m/s² (share of their frames) | 0.64% | 0.57% |
| `tackle_check`: grip median in every hold | 0.05-0.07 m | 0.02 m |
| `tackle_check`: a thigh helper's grip once his hold has closed (median) | 0.053-0.057 m | 0.021-0.022 m |

**Still not right:**

- **An ankle holder at full stretch** has his hands 0.12 m short of the ankle.
- **A defender getting up outside the sideline's margin** is put back inside it in one frame (0.3 m), as he always was.
- **A thigh helper as the raider lands** holds at full stretch while the thigh drops away, up to 0.13 m off it, for the 0.2 s before he lets go (as before).
- **Letting go to get up from the floor,** an ankle holder's hands swing back to the get-up pose in the let-go's 0.15 s however far it is: up to 1.3 m in five frames (as before).

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
