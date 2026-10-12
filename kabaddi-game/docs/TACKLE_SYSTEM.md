# Tackles and holds

Milestones B to E of the realism plan (see `MOTION_REALISM.md` for milestone A, movement): making a hold
real contact between two bodies (B), then building every tackle (C), the team's defence (D) and the match's
events and scoring (E) on it. Each milestone is measured before and after (see "Measuring").

## How a tackle worked (as found)

All in `game/match.gd`, run from `_tick_raid` each frame:

1. **Wind-up and dive.** `_ai_defender` (or the player's Tackle button) puts a defender in `telegraph`, then
   `_defender_tackle` starts a `dive` (0.3 s) aimed at the raider's middle. The dive was driven like running:
   `drive(dive_dir * 8.0)`, from a standstill at the running acceleration (18 m/s²). So it covered only
   0.8 m while it lasted, and then the defender slid another 0.8 m along the floor while getting up.
2. **Contact.** `_check_contacts`: a diving defender whose middle came within 0.75-0.9 m of the raider's
   middle, at any point in the dive, rolled a hold chance. Where the hands were never came into it.
3. **Holding.** `_attach` put the defender in `holding` and pinned him 0.55 m from the raider's middle,
   every frame (`position = raider.position + hold_offset`). The holding pose was the same for every hold,
   half a dive with the arms round, whichever leg or body part the hold was meant to be on.
4. **Struggle.** `_move_raider` slows the raider in proportion to the holds; `raid.progress` fills, and at 1
   (or with three holders past half) `_check_end` calls the tackle.
5. **The end.** `_end_raid("tackle")` dropped the raider to `fallen` and set every holder to `ready` at once,
   then `_react` had them roar or celebrate on the spot: a man lying on the floor stood up and cheered in one
   frame. The raider stood up from `fallen` straight into a walk.
6. **Escapes.** `_raider_escape` rolls a chance against the holders; `_release` threw the holder back 4 m/s.
7. **Messages.** The HUD message ("Ankle hold!") went up in `_attach`, so it followed the dice, not contact.
   There was no record of what happened, in what order.

Nothing else moved players during a hold. `_separate` already left holders out of the spacing between
players, so it did not fight the holds.

## Milestone B: one believable ankle hold

Measured with the ankle dive scenarios below, before (0.7.5) and after:

| | Before | After |
|---|---|---|
| When the hold is given | the two middles within 0.9 m; the nearer hand 0.66-0.74 m from the leg | a hand within 0.3 m of the leg; 0.12 m after the first frame's reach |
| Hands to the held leg while holding, median | 1.01-1.23 m | 0.03-0.04 m |
| ... 90th percentile | 1.17-1.27 m | 0.04-0.05 m |
| ... worst frame | 1.30 m | 0.12 m |
| A dive from too far (no hand reaches him) | no hold | no hold |
| Holder pose | standing, arms round the raider's chest | on the floor, both hands round the ankle |
| Raider while held | upright, arms forward | leaning away, the held foot kept where it was caught |
| Takedown | raider drops; holder stands and roars in the same frame | raider trips forward with the foot held; holder keeps hold 0.7 s, gets up, then celebrates |
| Escape (lion jump out of the hold) | holder thrown back 0.44 m | the foot pulled out of his hands; he stays down and gets up |
| Holder jumps (> 10 m/s in a frame) | 0 | 0 |
| Events recorded | none | attempt, contact, hold, escape, release, takedown, raid end |

What changed:

- **A grapple controller** (`game/grapple.gd`, `Grapple`): one per raider in defenders' hands. It records
  each hold (who, what kind, which leg, where the foot is kept, since when) and owns what the hold does to
  both bodies until the takedown or the escape. Its states follow the players' existing ones (`telegraph`,
  `dive`, `holding`, `held`, `fallen`, `recover`) rather than adding a second state machine.
- **Contact on the bodies as drawn** (`Grapple.ankle_contact`): an ankle dive grips only if one of the
  defender's hands is within 0.3 m of the raider's lower leg (ankle to mid shin). It has to happen while
  the arms are out (the last 70% of the dive, or 0.15 s after he lands), going at the raider, on a leg no
  one else holds. Points on the body come from the skeleton (`RiggedBody.anchor` and `HumanModel.anchor`:
  hands, feet, ankles, shins, thighs, waist, in world space). The hold chance (skill, energy, timing) still
  decides whether a grip that reached him holds; when it does not, the event says so ("grip lost").
- **A dive that launches** (`_dive_motion`): off the crouch at 4.2 m/s, slowing to 1.5 m/s as he lands,
  so the ground is covered in the dive and not by sliding afterwards. The distance covered in the dive is
  about what it was (0.86 m against 0.8 m), so the other tackles' reach is unchanged.
- **The held foot** (`RiggedBody.foot_goal`): kept where it was caught, with leg IK. Only when the raider
  stretches more than 0.55 m from it does he drag it, and the holder with it, along the floor.
- **The holder's body and hands** (`RiggedBody.hand_target`, `_reach_hands`): his body is moved, at no more
  than 2.5 m/s beyond the drag, to keep his reach on the leg. His arms reach the rest of the way with
  two-bone IK, one hand at the ankle and one a hand's width up the shin, with the hands and fingers turning
  with the forearms. The leg IK and the arm IK are the same routine (`_ik_two`). The held raider is posed
  first each frame (`process_priority`), so the hands go where the leg is now, not where it was.
- **An ankle holder lies on the floor** (`Athlete._pose`, `holding`). A body lying on the floor no longer
  runs (`HumanModel._animate`): dragged along, his legs used to cycle as if he were sprinting.
- **The takedown** (`Grapple.takedown`, `_tick_post`): the raider trips (`fall_trip`) with the foot still
  held and let go of as he goes down. The holders keep hold 0.7 s, then get up (`recover`), and only then
  celebrate (`_react` puts off the cheer of anyone still on the floor). The raider gets up before he walks
  off. The pause after a tackle is 0.9 s longer to fit it.
- **Escapes**: a hold slipped by a lion jump lets go of the foot at once. The holder's hands open where the
  leg was, over 0.15 s, and he stays down and gets up instead of being thrown back.
- **A lion jump over an ankle dive**: with the raider in the air, a hand passing under his feet counts as
  reaching his legs, so the jump has something to clear, and whether he does is still the lion jump's roll.
- **Gameplay events** (`_event`, `game_event`, `event_log`): every attempt, contact, lost grip, hold,
  release, escape, takedown, touch and raid end, numbered in order. The HUD's messages come from the same
  places, so "Ankle hold!" means a hand is on the leg.
- **Lab mode** (`config.lab`): a scripted raid for tests. The raider moves as told and defenders go in when
  told; `lab_force` can settle a chance (hold, escape) but never contact.

Kept as is, on purpose: the hold chances, the struggle and its progress bar, the escape chances, and
every other tackle (thigh, waist, block, dash, piling on, chain), which still go by distance and are drawn
the old way. Those are milestone C.

**Gameplay.** `tests/ai_bench.tscn -- 4 1`, AI matches at normal difficulty: 70% of raids successful, 18%
tackled, 8% empty (391 raids, 12 matches), against 72%, 19% and 6% before (267 raids, 8 matches): within
the noise of a few matches. Help still arrives about when it did in the footage (0.7-0.8 s after the first
hold, footage 0.65-1.15 s).

**Checks.** `tests/tackle_check.tscn`: all four scenarios as expected. `tests/test_runner.tscn` passes
(182 checks; the lion jump check now lays the diver's hands at the raider's feet, as contact needs).
`tests/locomotion_check.tscn`: course unchanged; joint pops in a 60 s match down from 117-138 to 68, since
players lying on the floor stopped running.

Still open after milestone B:

- Only ankle holds are made this way. Thigh, waist, block and pile-on holds still pin the holder 0.55 m
  from the raider's middle, arms round him (milestone C).
- The classic code-built bodies (Settings, models off) have no IK: their contact is checked on their own
  joints, but their hands do not reach.
- The dive aims at the raider's middle and leads him a little, not at the leg it will grab.
- A lying holder is a body on the floor that team-mates running in to help can pass through.

## Milestone C: every hold, on its own part of him

Measured with the scenarios below on milestone B's code (before) and now (after):

| | Before | After |
|---|---|---|
| Thigh hold: hands to the thigh, median / 90th percentile | 0.91 / 0.96 m | 0.07 / 0.09 m |
| Waist hold: hands to his middle, median / 90th percentile | 0.41 / 0.46 m | 0.01 / 0.03 m |
| When a thigh or waist hold is given | the two middles within 0.75-0.8 m | a hand within 0.3 m of the thigh or his middle |
| Team-mates helping: hands to what they hold, 90th percentile | 0.65 m | 0.16 m |
| Two holders on the same part of him | possible: every helper pinned 0.55 m from his middle | never: one defender a part |
| Closest a holder's middle comes to the raider's | 0.48 m (arms round thin air) | 0.30 m (bodies touching, not inside one another) |
| Closest two holders' middles come | 0.40 m | 0.33-0.43 m |
| Four defenders going in together | (the dive at the ankles missed) | four holds on four parts, one takedown |
| "Chain tackle!" for one hold with two helpers | twice | once |

What changed:

- **Slots** (`Grapple.SLOTS`): a hold is on a part of the raider, one defender each. There is a leg each
  (`leg_l`, `leg_r`), his middle from behind (`back`) and from the front (`front`). Four slots, the same
  limit of four holders as before.
- **Hold styles**, drawn and reached for differently (`Grapple.HANDS`, `Athlete._pose`):
  - **ankle**: lying on the floor, hands round the ankle and lower shin;
  - **thigh**: bent right down at his hip, arms round the thigh above the knee;
  - **waist**: bent into his back or side, arms round his middle;
  - **block**: chest to chest, arms round him.

  The tackle sets the style, and the slot can adjust it: a helper on a leg makes a thigh hold, and one on
  the raider's front makes a block. The foot of a held leg is kept where it was caught, for thigh holds as
  for ankle holds.
- **Contact for every dive** (`Grapple.contact`): thigh dives need a hand on the thigh, and waist dives a
  hand on his middle, like ankle dives on the lower leg. Dives now aim at the part they go for
  (`_aim_point`), the nearer ankle or thigh or his middle, rather than his centre. The dash is a shoulder
  charge, not a hold, and still goes by distance.
- **How far each dive reaches**, measured from a standing raider (`tests/tackle_reach.tscn`, the furthest start
  from which the dive still makes contact). Two things came out of it:
  - Every dive used the one captured dive, a flying tackle at thigh height. Its hands never got below
    0.6 m, so an ankle dive could not reach a standing raider's ankles at all. Ankle dives now go in low with
    the hand-made dive, made flatter and with the arms angled down along the floor (`HumanModel._animate`).
  - With hands checked against the thigh or his middle, thigh and waist dives reached further than they used
    to: 2.1 m and more for a thigh dive against 1.6 m. A dive now also needs the two bodies within its stretch
    (thigh 0.75 m, waist and block 0.7 m, middle to middle), which brings them back to about the old reach.
    An ankle dive's stretch is a body's length (1.25 m): its hands are a whole body out along the floor.
- **Contact along the hand's path** since the last frame, not just where it is: at 30 frames a second a
  diving hand moves 15 cm a frame and could pass through a leg unseen.
- **Helpers** (`Grapple.claim`, `approach`, `can_reach`, `_ai_defender`, `_check_contacts`):
  - Each team-mate coming to help claims a free slot and runs to that slot's side of the raider, so they no
    longer all run at his middle. A leg is taken from its side, his middle from behind or in front.
  - He takes hold once the slot is within his reach, facing it, at the same rate as before.
  - With every slot held or claimed, he blocks the way home instead.
  - A counter-grab (a defender the raider touched) and a chain closing on him take the free slot nearest each
    of them. A defender with no slot left does not hold.
- **Holders' bodies**: each is placed so his shoulders are within arm's reach of his slot (an arm's length
  off it on the floor, closer when the slot is lower than his shoulders), coming at it the way he is. A
  holder's middle stays at least 0.34 m from the raider's and 0.42 m from another holder's.
- **How he goes down**: tripped (`fall_trip`) if anyone has a leg, taken down (`fall_takedown`) otherwise.
  Holders on the floor get up before they celebrate; standing holders celebrate when they let go.
- **Messages**: the first hold's own name, then "Chain tackle!" once when help first arrives, then nothing
  more for the same hold. A hold's name is the hold actually made: a defender grabbing back at the raider who
  touched him, on his thigh, used to be announced as "Ankle hold!".

**Gameplay.** `tests/ai_bench.tscn -- 4 1`, 12 AI matches at normal difficulty (391 raids): 69% of raids
successful, 17% tackled, 8% empty, 6% out of bounds, against 71%, 17%, 6% and 6% for 0.7.5. Per 100 raids
there are now 24 ankle holds (12 in 0.7.5), 11 thigh holds (8.5) and 8 waist holds (12.5). Help still
arrives 0.6-0.8 s after the first hold (footage 0.65-1.15 s). The first try at the dives' stretch (0.75 m for a
thigh dive, 0.7 m for waist) halved thigh holds and tackles fell to 14%; the values above put them back.

Kept as is: the chances (hold, pile-on rate, escapes), the struggle and what each hold kind adds to it, and
four holders at most.

**Checks.** `tests/tackle_check.tscn`: all twelve scenarios as expected; `tests/test_runner.tscn` passes (183
checks: the waist-hold-in-the-air check now lays the diver's hands at the raider's middle first, as contact
needs); `tests/tackle_reach.tscn` gives each dive's reach.

Still open after milestone C:

- A holder pushed aside by another loses some reach: the team-mates' grip is looser than the first
  holder's (90th percentile 0.16 m against 0.05-0.09 m).
- Helpers still run in as fast as they can from wherever they are. Choosing who helps, who blocks the way
  home and who stays in shape is milestone D.

## Milestone D: the defence as a team

As found (`_ai_defender`), each defender decided for himself every frame:

- his place in the line, sliding with the raider and giving ground as he came close;
- once the raid was on (a touch, or the raider deep), everyone ran for a point just in front of the raider,
  between him and the midline;
- once he was held, everyone within 4.2 m ran at the raider himself (milestone C gave each helper a hold of
  his own).

The set line was already well spread (each defender's nearest team-mate about 1.4 m away, pairs closer than
0.9 m rare). The weakness was the way home: as a raider ran for the midline after a touch, someone stood in
his way only 12-18% of the time. Everyone ran for the same point a fixed distance in front of him, which
defenders behind him could not reach in time.

What changed:

- **A team plan** (`game/defence.gd`, `DefenceCoach`), worked out once a frame for all the free defenders
  (not the ones diving, holding or getting up, nor the player's own). Each gets a role and a place:
  - **line**: his place in the line, sliding with the raider and giving ground when he comes close;
  - **mark**: the man the raider is working on, who holds his ground and is the one who goes for him;
  - **cover**: the two either side of the mark, a little in toward him, near enough to tackle or help;
  - **lane**: once the raid is on, the two best placed to stand in his way home;
  - **contain**: the rest once the raid is on, and anyone left over while he is held, spread round his
    way home further off;
  - **help**: once he is held, to a hold of his own (milestone C's slots).
- **Utility**: places are given out best placed first, by how quickly each defender can get there. Running
  past the raider to get there costs extra, and lanes favour fresh, strong tacklers. No two places are
  closer than 1.05 m (linked pairs aside).
- **Cutting him off**: a raider running for home is met where he can be caught. Each free defender works
  out where he would meet him on his run, still in his own half (`_intercept`), and the two who would meet
  him soonest go there flat out.
- **Reaction time**: each defender takes up a new role or a new place only after his own reaction time,
  0.12-0.38 s, quicker for agile players and a little different each time, so the shape moves like people
  and not like one machine.
- Players standing off in his way home do not dive at him from out there. Who dives, and when, is
  otherwise unchanged.
- **Debug overlay** (`game/debug_draw.gd`, `config.debug_draw`; on in `tests/defence_view.tscn` and in
  `tackle_check`'s view): each defender's place in the plan as a ring in his role's colour with a line to
  it, the holds' hand targets and held feet, and planted feet.

Before (milestone C) and after, `tests/ai_bench.tscn -- 4 1`, 12 matches each:

| | Before | After |
|---|---|---|
| Way home covered as he runs for it | 12-18% | 16-20% |
| Help after the first hold (footage 0.65-1.15 s) | 0.60-0.83 s | 0.80-0.97 s |
| A set defender's nearest team-mate | 1.40-1.64 m | 1.40-1.41 m |
| Pairs closer than 0.9 m (mean, unlinked) | 0.04-0.10 | 0.07-0.09 |
| Defenders within 2 m of the raider while he works | 0.56-0.63 | 0.53-0.57 |
| Raids successful / tackled / empty | 69% / 17% / 8% | 65% / 18.5% / 9% |
| Every match's points add up | (not checked) | yes |

Still open after milestone D:

- The way home is still open most of the time: a raider who touches and turns is usually quicker home than
  anyone behind him, as in the footage, where defenders went for him as he stepped in rather than chasing.
- The line's own shape (depth, spread) is the formation tuned to the footage in 0.7.5 and is unchanged.

## Milestone E: events, scoring and the last transitions

- **Every message has an event behind it** (`_event`). Each HUD message about play now goes up where a
  gameplay event is recorded, in the same place, so the record and the screen cannot disagree: holds,
  escapes (lion jump, dubki, dodge), a chain broken through, defenders out over a line, the dash, bonus
  points, named moves (`move`), touches and the raid's end.
- **Points given once, checked.** Each raid's log now says which team raided, and `ai_bench` checks every
  match:
  - each team's score equals its breakdown (raids, tackles, all outs, extras);
  - its raid points are the sum of its raids';
  - its tackle points are the sum of its defence's.

  The **touch** and **flurry** scenarios check one raid at a time: the score goes up by exactly what the raid
  gave, once, with every event in order.
- **Names that match**: a hold's message names the hold actually made (milestone C), and "Chain tackle!"
  comes once per hold.
- **Transitions**:
  - a standing holder (waist, block) knocked off by an escape staggers back on his feet instead of
    playing the get-up from the floor;
  - holders on the floor get up before they celebrate, and a tackled raider gets up before he walks off
    (milestone B).

**Checks.** `tests/test_runner.tscn` passes (184 checks); `tests/tackle_check.tscn` all twelve scenarios as
expected; `ai_bench`: points add up in every match (8 matches, 245 raids).

Still open:

- "Broke free!" goes up when a raider slips one of several holds, though the others may still bring him down
  ("Broke free!" then "Tackle!").
- Nothing new on screen marks a hold's slot or a defender's role outside the debug overlay.

## Review fixes (after the 0.7.5 gameplay recording)

A review of the recorded gameplay picked out five problems. Each fix below names the cause found in the code,
and is measured with `tests/tackle_check` (whose motion numbers were added for this, see Measuring) and
checked on a new recording of the same scenario.

### 1. The ankle hold: a struggle, not two still poses

**Seen**: the defender lay stretched out and still while the raider stood almost still for over three
seconds, then dropped all at once.

**Cause**:
- While held, the raider's struggle was one number, `raid.progress` (`Match._move_raider`). It rose evenly
  until it reached 1, and `_check_end` then ended the raid in a tackle.
- Nothing drew that number. The raider played one looping clip (`held_pull`), and the holder kept a fixed
  lying pose (`Athlete._pose`, "holding": `want_dive = 1.0`).
- The fall clip (`fall_trip`) then started from its own first, upright frame.

**Fix**:
- Each holder now hauls in his own rhythm (`Grapple.haul`, `PULL_PERIOD` about 0.9 s). A haul draws a held
  leg back toward him and lifts the foot a little (`Grapple._pulled`). His arms bend because his body does
  not follow the foot in (`_pull_in`).
- Each haul pulls the raider back (`Match._move_raider`). The struggle advances mostly during hauls; its
  pace over a whole haul is unchanged.
- The struggle is drawn (`HumanModel._apply_struggle`, on top of the clip):
  - the raider topples further over the free leg as his balance goes;
  - his hips sink and his arms go out for balance;
  - each haul jerks him back and twists him toward the held leg;
  - the lying holder's chest lifts and his knees draw up as he hauls.
- A fall clip starts from the frame nearest the pose he is in (`HumanModel.play_state`), but only from the
  part before the drop. A raider already toppling carries on from there.

| Ankle hold (`catch`) | Before | After |
|---|---|---|
| Holder's body motion while holding (median) | 0.10 m/s | 0.43 m/s |
| Raider's body motion while held (median) | 0.33 m/s | 0.58 m/s |
| Raider's lean from upright: early, halfway, end of the hold | 16°, 14°, 18° | 17°, 38°, 58° |
| Held foot dragged along the floor over the hold | 1.41 m | 0.45 m |
| Free foot sliding while down (90th percentile) | 1.02 m/s | 0.70 m/s |
| Hands to the held leg (median / 90th percentile) | 0.048 / 0.051 m | 0.056 / 0.075 m |
| Hold to takedown | 3.40 s | 3.57 s |
| Takedown to his waist on the floor | 0.70 s | 0.60 s |
| Fastest the torso tips / the waist drops, around the takedown | 201 deg/s / 2.65 m/s | 194 deg/s / 3.66 m/s |

Body motion is how fast the hands, shoulders, waist and feet move against the player's own root, so a
frozen pose reads near zero.

Visual check, frame by frame on the new recording:
- the raider bends further over the held leg on every haul;
- the held leg is drawn out behind him toward the holder's hands;
- the holder's chest lifts and his knees come up as he hauls;
- at the takedown the raider goes on down onto his hands from the bent-over pose, rather than dropping out
  of an upright one.

The grip is a little looser than before (it is now a moving target), and the last part of the drop is
quicker (the fall starts further on).

### 2. The chain tackle: every holder holding, together

**Seen**: the defenders were apart, but did not look as if each held and kept hold of the raider.

**Cause**:
- A raider held by three was down as soon as the struggle passed half (`Match._check_end`), whatever the
  holds' age. In the `chain` scenario the last helper's hands had been on him 0.23 s when he went down: the
  hold had no time to be seen.
- Each holder hauled on his own (fix 1), so a pile of three was three separate rhythms, and only the
  strongest haul moved the raider.
- A block (chest to chest, in front) hauled like the rest, leaning back, where it should drive into him.

**Fix**:
- A team-mate who takes hold falls in with the first holder's haul (`Grapple.add`). They heave together, his
  first haul with the next of theirs his hands are closed for.
- The raider is pulled back by all the hauls together (`Grapple.tug_total`), not only the strongest.
- He goes down only once every hold on him has been a hold for `ESTABLISH` (0.6 s, `Grapple.established`).
- A block drives into him as it hauls (`HumanModel.haul_drive`).

Measured with `tests/tackle_check`; the per-holder grip is the 90th percentile once his hands are on (under
0.1 m), after the time they took to close:

| Chain (`chain`, three holders) | Before | After |
|---|---|---|
| From the last helper's hold to the takedown | 0.23 s | 0.60 s |
| The whole hold | 1.00 s | 1.37 s |
| First holder's body motion while holding | 0.08 m/s | 0.50 m/s |
| Raider's lean: early, halfway, end | 19°, 17°, 17° | 20°, 28°, 32° |
| Ankle hold's grip | 0.125 m | 0.067 m |
| Thigh hold's grip (hands on in 0.13 s) | 0.121 m | 0.140 m |
| Block's grip (hands on in 0.10 s) | 0.230 m | 0.245 m |

| Four holders (`crowd`) | Before | After |
|---|---|---|
| From the last helper's hold to the takedown | 0.10 s | 0.60 s |
| Grips: ankle, thigh, waist, block | 0.15, 0.13, 0.17, 0.24 m | 0.08, 0.12, 0.05, 0.11 m |

A recording from above (`view chain plain high`) shows each holder on his own part of the raider. It also
showed the HUD's messages ("Ankle hold!", "Chain tackle!") drawn right over the pile, hiding it; see fix 6.

Still open: a block's hands are the loosest (about 0.25 m at the 90th percentile in `chain`). In the `join`
scenario the takedown now waits for the first hold to be established, so the team-mate running in gets hold
of him first; the scenario still checks that no hold is made after the takedown.

### 3. Falls and getting up

**Seen**: the fall and the recovery were abrupt; players stood or ran while still finishing a fall.

**Cause** (`Match._tick_post`, `Match._end_raid`):
- A tackled raider was told to get up 1.2 s after the takedown, however long his fall took. The falls take
  0.53-0.87 s to reach the floor, so he lay there about half a second.
- His get-up clip (1.4 s long) was squeezed into 0.9 s.
- He walked off the moment it ended.
- A holder on his feet (waist, block) went from holding to his cheer in the same frame (`recover` with no
  length), standing straight up while the raider fell.
- The thud played at the takedown, not when the body hit the floor.
- Holders got up where they had fallen, on top of the raider, and stood inside him.

**Fix**:
- A fall clip knows when it reaches the floor (`MocapClip.landing`). The body knows how long it has been
  down (`HumanModel.down_for`).
- The raider stays down `LIE_TIME` (0.9 s) from then, gets up over the clip's own length
  (`GETUP_RAIDER`, 1.4 s), and stands a moment (0.5 s) before he walks off (`Match._after_getup`).
- The thud plays as he hits the floor. The body gives with the impact for 0.3 s (`_apply_impact`).
- A holder on his feet goes down with the raider as he takes him down (`Athlete.bear`, set by the
  grapple), comes up out of the bend, then cheers. Holders off the floor get up over 1.2 s
  (`GETUP_HOLDER`).
- Anyone getting up next to the man on the floor steps off him.
- A fall starts from the frame nearest the pose he is in (fix 1), but always with at least half a second to
  go before it lands.

| Tackled raider, `catch` / `flurry` | Before | After |
|---|---|---|
| Takedown to his waist on the floor | 0.70 / 0.70 s | 0.60 / 0.60 s |
| On the floor before getting up | 0.50 / 0.50 s | 1.07 / 1.06 s |
| Getting up | 0.94 / 0.93 s | 1.40 / 1.40 s |
| On his feet before walking off | 0 / 0 s | 0.53 / 0.54 s |
| Fastest he moves along the floor while down or getting up | 0.76 / 0.76 m/s | 0.00 / 0.02 m/s |

| After the holds let go, while he is down: nearest a defender on his feet stands to him | Before | After |
|---|---|---|
| `thigh` | 0.14 m | 0.64 m |
| `chain` | 0.36 m | 0.53 m |
| `flurry` | 0.25 m | 0.33 m |
| `waist` | 0.37 m | 0.37 m |

The waist-hold fall reaches the floor in 0.43 s (0.53 s before), because it now starts from a toppling
pose. The waist holder's grip while the raider falls, 0.14 m at the 90th percentile, is looser than before
(0.06 m). He bends down with the raider rather than holding his body still.

Visual check on the `flurry` recording, before against after:
- the raider goes down onto his hands from the toppling pose;
- the holder goes down on him, gets up first and steps off;
- the raider lies still, then rises through his knees over about a second and a half, and only then walks.

### 4. The defence's shape

**Seen** (recording 12-16 s and 45-53 s): defenders stood in an unnaturally straight line.

**Cause**: while the raider works the cover, `DefenceCoach.update` put every defender on his formation spot
(`Match.formation_spot`: evenly spaced, all at one depth) and slid the whole line sideways with the raider. It
was a wall at one depth that moved as a unit. The raiding side's players waiting in their own half stood the
same way.

**Footage**: `tools/mocap/raid_events.py` now also measures how far apart defenders stand front to back (the
standard deviation of their depths). In the four clips it is 0.89-1.12 m: real defenders are not in a line.

**Fix** (`DefenceCoach.update`, "working the cover"; `Match.formation_spot`):
- The line curves round where the raider is about to be (`ANTICIPATE`, 0.35 s ahead). Those straight in
  front of him give a little ground (`WRAP_BACK`), and those well out to his sides come up (`WRAP_FWD`), so he
  is in the mouth of a curve. The curve deepens the further in he is.
- Every player has a place of his own in the line: a little deeper or shallower, a little to one side
  (`formation_spot`, both teams). A defender's depth drifts slowly about it (`DRIFT`).
- Roles, reaction times, spacing (no two places closer than 1.05 m) and lanes are unchanged.

`ai_bench`, four matches each:

| | Before | After | Footage |
|---|---|---|---|
| Defenders' depths, front to back (sd) | 0.12 m | 0.50 m | 0.89-1.12 m |
| Line depth (median) | 4.58 m | 4.44 m | 4.43-4.93 m |
| Nearest defender while he raids (median) | 1.90 m | 2.08 m | 2.26-2.51 m |
| Way home covered as he runs for it | 13% | 24% | |
| Pairs closer than 0.9 m (unlinked, mean) | 0.08 | 0.05 | |
| Defenders within 2 m of him (mean) | 0.53 | 0.45 | |
| Raids successful / tackled / empty / out of bounds | 64 / 19 / 11 / 6% | 63 / 20 / 7 / 9% | |

The `after` column is before each player's own place moved into `formation_spot`. A two-match check after
that move: 0.49 m front to back, way home covered 22%.

On the TV recording the defenders now make an arc with the raider in its mouth, rather than a ruled line.

Still open:
- They are still more regular than the footage (0.5 m against about 1 m front to back).
- Raids ending out of bounds went from 6% to 9%: with the corners further up there is less room along the
  sides. This needs watching.

### 5. Events that happen close together

**Seen** (recording at 80-83 s and 155-157 s, the follow-camera match at 73-76 s and 148-150 s): a hold, a
chain tackle, a dubki escape and a tackle within a second or two. The events were checked against the event
log and the code:

| Match time | Events | What was wrong |
|---|---|---|
| 72.60 | touch; thigh hold by the touched defender | the hold was given in the same frame as the touch, with no reaction and no check that his hands could reach |
| 73.60 | dubki escape releases the thigh holder; ankle hold kept | judged on the defender's tackle name, not the hold; "Broke free!" shown though he was still held |
| 74.37 | block hold; takedown; raid end, all in one frame | the newest hold had no time to be a hold |
| 147.30-148.57 | touch and thigh hold in one frame; block; dubki escape; thigh hold | as at 72.60 and 73.60 |

**Cause**:
- A touched defender's grab back (`Match._check_contacts`) called `_attach` there and then. It skipped the
  contact check every other hold goes through.
- An escape (`Match._raider_escape`) picked a random holder and judged the move by his tackle's name
  (`kind()`), not by the hold the grapple had made. A "wrong" move still succeeded 20% of the time (a dubki
  out of an ankle hold, a jump out of arms round the waist).
- "Broke free!" went up on every escape, even with other holds still on him.
- A takedown could come in the frame a new hold was made (fixed by 2).

**Fix**:
- A grab back is a committed reaction. The touched defender winds up (`telegraph`) and after `COUNTER_REACT`
  (0.18 s) takes hold only if the raider is still within reach of his hands plus a step
  (`Grapple.reachable`, `COUNTER_STEP` 0.5 m). Otherwise the event is `grab_missed` and his wind-up carries
  on into a tackle, whose dive is checked like any other.
- An escape is judged on the grapple's holds (`Grapple.ESCAPES`). A dubki ducks out of arms round his middle
  and sometimes a thigh hold, but never a held ankle. A lion jump kicks free of an ankle and sometimes a
  thigh, never arms round his middle. A move goes against the hold it suits best, and a move that suits none
  slips none.
- The escape event says which hold was slipped and whether he is free. "Broke free!" goes up only when he is.
- The AI raider and the escape hint read the holds the same way (`Match._held_low`).
- A sidestep out of a hold (`Match._raider_dodge`) had the same faults, and is judged the same way.
- No defender is given a part of the raider someone already holds. A helper's claim on a part was kept after
  a diver's hands took it, and a hold given a part did not check it was free (`Grapple.claim`,
  `Match._attach`); a recording showed two defenders on the same leg.
- New scenarios: `slip` (held at the ankle and round the waist, a dubki slips only the waist: still held, no
  "Broke free!", taken down) and `duck` (held only at the ankle, a dubki slips nothing). In `flurry` the
  touched defender now stands close enough to grab back: at the old 0.95 m his grab back is out of reach,
  so he dives instead.

`ai_bench` now checks the events of every raid it plays (`_event_checks`). Two matches each, before these
fixes (the chain and fall fixes already in) and after:

| | Before | After |
|---|---|---|
| Grabs back at a touch made in the same frame as the touch | 15 of 16 | 0 of 14 (after 0.20 s, median) |
| Escapes a move could not make (a dubki out of an ankle hold, a jump out of arms round him) | 3 of 23 | 0 of 15 |
| Escapes that left him still held, each with "Broke free!" | 8 of 23 | 5 of 15, with no message |
| Takedowns within 0.6 s of the newest hold still on him | 0 of 12 | 0 of 12 |
| Holds on a part already held | 0 of 59 | 0 of 57 (seen once on a recording before the fix) |

Visual check: the `slip` recording, from above. A dubki leaves the waist holder behind while the ankle holder,
lying on the floor, keeps hold throughout. The team-mate gets back on him and he goes down.

### 6. The HUD's messages over the play

The play-by-play messages ("Ankle hold!", "Chain tackle!", "Super tackle!") were drawn in the middle of the
screen (`Hud.events_box`), which is where the play is: on the recordings they covered the very holds they
named. They now sit under the raid strip at the top, a little smaller, two at most at a time.

## Second review (the V2 recording): the ankle hold as one interaction

The second review watched the ankle hold again (2:43-2:49 in the V2 video, the `catch` scenario) and asked for
it to be fixed as one interaction between two bodies before anything else. It saw a defender lying flat and
apparently being dragged behind the raider, and a raider who stayed steady too long before he fell.

**What was doing it** (measured with the new restraint numbers in `tests/tackle_check`, see Measuring):

- **The holder was a sled.** Every frame `Grapple.update` moved the holder's whole body (his root) to keep his
  shoulders 0.88 of an arm from the ankle. It moved him at up to 2.5 m/s plus the raider's speed, with his pose
  fixed as the lying dive (`Athlete._pose`, "holding": `want_dive = 1.0`). Over one hold he slid 3.8 m along the
  floor. At the takedown the same correction overshot every frame and he shook back and forth by 15 cm a
  frame: 16 reversals, and speed changes of 261 m/s².
- **The raider glided.** `Match._move_raider` slid his root toward the line all the time: up to 0.64 m/s at
  half push, more at full push. `Grapple.update` dragged the held foot along with him once it was 0.55 m from
  his root. Meanwhile `RiggedBody._plant_feet` held his free foot to the floor against that slide until it
  slipped and stepped.
- **He stood on the held foot.** `RiggedBody._ground` set the body on the floor by the lowest point of either
  leg, so he stood on the held leg's pose, and the leg IK then moved that foot to the hold. His free foot hung
  3 to 12 cm above the floor and was on it only 40% of the hold. The held-foot IK was skipped altogether in
  the air. The last re-grounding came after the held-foot IK and moved the foot off its hold: 8.8 cm at the
  90th percentile.
- **A frame behind.** The held raider was posed (process priority -1) before the match moved him that
  frame, so anything fixed in the world, like his planted foot or his held foot, lagged his body by a frame.

**What it is now.** An ankle hold is two bodies joined at the ankle (`Grapple._ankle`, `Grapple._footwork`):

- **Contact.** Both react at once. The diver's chest meets the floor (the body's impact give), and what is left
  of his dive dies away in his arms (`SETTLE`), never past the ankle. The raider's foot is caught while the rest
  of him carries on: he lurches onto the free foot (a jolt). If he was moving, he stumbles a hop the way he was
  going, and the held leg stops him.
- **The holder** lies where his dive put him. He turns on the floor to keep the ankle in front of him. Between
  hauls he stays braced: head and chest up off the mat, knees a little drawn up. He moves along the floor only
  when the raider drags him.
- **The ankle** is where both of them have it:
  - Between hauls the raider draws the foot back in under him (`LEG_REST`, `LEG_DRAW`), as far as the holder's
    arms let it go, and the holder's arms straighten.
  - On each haul the holder pulls it back out toward himself (`ARM_HAUL`, `HAUL_SPEED`) and lifts it
    (`ANKLE_LIFT`). His elbows bend, his chest comes up and his knees draw up.
  - The foot is never further from the raider's hip than his leg reaches with his hips as low as they go
    (`Grapple._span`). Whatever the haul pulls past that becomes tension on the raider.
- **The raider** stands on his free foot and sinks on it as low as the held leg needs to reach back
  (`Athlete.stance`, drawn by `HumanModel._apply_footwork`). He gets about only by hopping on the free foot
  (`HOP_*`), never by sliding:
  - A hop past the leg's reach stops short: the leg snaps taut and jolts him.
  - If he drives harder than the holder holds (`force` against `resist`, from `Match._move_raider`), the holder
    is instead dragged a little way with each hop (`DRAG_MAX`) and strains against it: arms out straight,
    chest and head down, knees dug in.
  - A haul that pulls the leg past its reach pulls him back, and he hops back toward the hold to stay up.
  - He turns only in the air. Turning on the spot would drag his planted foot round.
  - The longer the struggle goes, the shorter his hops, the deeper his lunge, the further he leans and the
    more his arms flail.
- **The takedown.** He goes down forward, away from the hold (`Grapple.away_from_hold`), with the foot still in
  the holder's hands. The holder keeps the ankle until the raider is down, and is pulled a little after it if
  the fall takes it past his reach (`TAKEDOWN_DRAG`).
- **A failed hold** (an escape, or the raid ending with him held) lets go without a takedown. The holder's
  hands open where they were, and the leg swings free of the hold over `LET_GO` (`Grapple._unpin`) rather than
  in one frame.

**The body behind it** (`RiggedBody._ground`):

- He stands on the free foot: a held leg is left out of what the body stands on, unless both legs are held.
- If the held leg cannot reach its hold, the hips come down until it can (`_sink_to_hold`). Standing, the free
  knee bends to keep its foot planted. In the air, the free leg tucks up, so a hop is only as high as the held
  leg allows.
- The held leg reaches for its hold last of all, so nothing moves it off afterwards.
- His legs are set against the body as a whole, not the hips. Leaning over bends him at the hip over a planted
  leg instead of swinging the leg back.
- His feet stay planted while he is bent right over one leg.
- He is posed after the match has moved him (priority 1), and his holders after him (priority 2).

**Order of the pose stages, and who moves what.** Only one system translates each body. In a hold that is:

- the raider: `Grapple._footwork` (hops), or `Match._move_raider` with `Grapple.leg_limit` when other holds are on
  him;
- the holders: `Grapple`.

Each frame the body is built in this order:

1. The pose is built in `HumanModel._process`: `_animate`, the running clips, the state clip, `_apply_struggle`
   with `_apply_footwork`, `_apply_impact`, then `_settle`.
2. `RiggedBody.drive` copies it to the skeleton, then grounds it: lowest free point to the floor, feet laid
   flat, planted feet (`_plant_feet`), the hips sunk for a held leg, and the held foot's IK last.
3. The hands reach their holds (`_reach_hands`).

No two of these move the same bone for different ends any more, and none of them moves the root.

**Smaller fixes found on the way:**

- Each holder's haul rhythm came from the engine's object id, so it changed with whatever was created before.
  It now comes from the player.
- Each body has its own random generator, seeded from the player, for its idle sway and where its loops start.
  The engine's shared generator is drawn on by everything else as well.
- A match given a fixed tackle style (the Training Ground's lion-jump lesson) wrote the rating into the
  player's shared data. So did `tackle_check`. Both now change a copy.
- Holders round the middle swing round with the raider as his body turns.
- A front or back hold can only be taken from that side of him.
- Holders give way in full to an ankle holder, who stays where he is.

| Ankle hold, `catch` (half push) | V2 | Now |
|---|---|---|
| Holder's body slid along the floor while holding (total, 90th-percentile speed) | 3.80 m, 4.35 m/s | 0.26 m, 0.03 m/s |
| Holder's body turning back on itself (frames) / sharpest change of speed | 16 / 261 m/s² | 0 / 22 m/s² |
| Held ankle from its hold (90th percentile / worst) | 0.088 / 0.111 m | 0.000 / 0.000 m |
| Free foot on the floor while not hopping | 40% | 98% |
| Raider's travel made sliding rather than hopping | 1.07 m (100%) | 0.01 m (2%) |
| Hops on the free foot | 0 | 5 |
| Planted foot's speed along the floor (90th percentile / worst) | 0.24 / 1.72 m/s | 0.15 / 0.27 m/s |
| Raider's lean from upright: early, halfway, end | 17°, 37°, 58° | 18°, 32°, 62° |
| Hold to takedown | 3.53 s | 3.43 s |
| Lies once down, against the way the hold pulls him (0 is straight away from it) | 5° | 5° |

| Ankle hold, `drag` (driving for the line as hard as he can, as the AI does) | V2 | Now |
|---|---|---|
| How it ends | reaches the line, 2.3 s into the hold | taken down, 6.2 s into the hold |
| Holder's body moved along the floor | 2.52 m, smoothly (90th percentile 1.88 m/s) | 0.51 m, a few cm at a time (0.37 m/s) |
| Held ankle from its hold (90th percentile / worst) | 0.132 / 0.153 m | 0.000 / 0.000 m |
| Free foot on the floor while not hopping | 49% | 99% |
| Raider's travel made sliding rather than hopping | 2.68 m (100%) | 0.01 m (1%) |
| Planted foot's speed along the floor (90th percentile / worst) | 1.07 / 2.01 m/s | 0.14 / 0.39 m/s |

The holder's own body still moves while holding: it is now his arms, chest and legs, as the haul,
the brace and the strain move them.

**Still not right:**

- With other holds on him as well (`chain`, `crowd`), the raider is still carried along by the struggle
  rather than stepping. The ankle holder lies still and the leg holds him.
- In those piles the other holders' hands come off as he falls. During the hold their grips are as before
  (90th percentile within a few centimetres of V2); in the last 0.3 s of the fall they open up to 0.3 m. That
  is the chain tackle's recovery, the next fix.
- A raider who reaches far forward, or is pulled far back, can only be met by the hips sinking 0.3 m at most
  (`MAX_SINK`). Past that the held leg falls short of its hold, although no scenario has needed it yet.
- A single ankle holder now stops a driving raider rather than being dragged to the line. That is what an
  ankle hold should do, but it changes how often raids end with the raider getting home held. The AI bench
  measures it (`docs/REALISM_REVIEW.md`).

## Measuring

```sh
godot --headless --path . --fixed-fps 30 res://tests/tackle_check.tscn -- [SCENARIO ...] [--json out.json] [--log]
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --write-movie catch.avi \
    --fixed-fps 30 res://tests/tackle_check.tscn -- view catch [plain]
```

`view` records one scenario from the side with the debug overlay on; `plain` leaves the overlay off; `high`
looks down from above, three-quarters on; `close` comes in closer, a little in front.

Each scenario is a scripted raid in the match's lab mode (`config.lab`). The raider moves as told, defenders go
in when told, and team-mates help once he is held. A chance (hold, escape, piling on) can be forced one way,
but contact never is. The scenarios:

- **miss**: an ankle dive reaches the leg, but its grip fails.
- **catch**: an ankle hold brings the raider down.
- **escape**: a lion jump out of an ankle hold.
- **whiff**: a dive from 2.6 m. No hand reaches him, so no hold may be given, even with the hold chance
  forced.
- **thigh**, **waist**: those holds bring him down.
- **chain**: a hold, then two team-mates come to help, each to a part of his own.
- **join**: he goes down while a team-mate is still running in. One takedown, no hold after it.
- **committed**: a holder is told to tackle again, and is refused.
- **crowd**: three team-mates help at once. No two on the same part, nobody inside anybody.
- **touch**: a hand touch and home. The points are given once, and the score goes up by exactly them.
- **flurry**: within a second or two, a touch, the touched defender grabbing straight back, another diving
  in, help, and a takedown. Every event comes in order, and the raid is scored once.
- **slip**: held at the ankle and round the middle, a dubki slips only the arms round him: still held, no
  "Broke free!", taken down.
- **duck**: held only at the ankle, a dubki slips nothing.
- **drag**: the `catch` hold with the raider driving for the line as hard as he can, as the AI does. He drags
  the holder a little at a time and is brought down.

Each scenario prints:

- the contact gap and the first frame's grip;
- the grip error of every holder while holding;
- holder jumps;
- how close the bodies' middles come, to the raider's and to each other;
- each player's states over time;
- the HUD messages and the gameplay events;
- the motion of the hold and the fall (`_motion`): hold time, the raider's and the holder's body motion,
  the raider's lean early, halfway and at the end of the hold, how far the held foot moves, how fast the
  free foot slides, and, for a takedown, the time to the floor and the fastest the torso tips and the waist
  drops;
- a leg hold as one interaction between two bodies (`_restraint`):
  - how far the holder's body slid along the floor, how often it turned back on itself, and the sharpest
    change of speed of either body;
  - the held ankle from its hold;
  - how far the held leg is stretched;
  - how much of the hold the free foot is on the floor, and how fast it moves while planted;
  - how much of the raider's travel was sliding rather than hopping, and the number of hops;
  - how soon he answers the hold;
  - which way he lies once down, against the way the hold pulls him;
- each holder's grip all through, and while the raider is still on his feet (`grip_each`, "held").

A scenario fails if the events are not what it must produce. The motion numbers are measured, not checked:
they are for comparing a change, alongside looking at a recording.
