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
  otherwise unchanged. (Since 0.7.8, once he has touched someone they do, as he comes near: it is the last
  chance, and more go, from further, with less wind-up; `docs/REALISM_REVIEW.md`, "Fifth review".)
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
4. No bone turns faster than 1,200°/s, whatever turned it (`_limit_turns`, added for the audit of ordinary
   matches below).

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
| Holder's body slid along the floor while holding (total, 90th-percentile speed) | 3.80 m, 4.35 m/s | 0.26 m, 0.02 m/s |
| Holder's body turning back on itself (frames) / sharpest change of speed | 16 / 261 m/s² | 0 / 22 m/s² |
| Held ankle from its hold (90th percentile / worst) | 0.088 / 0.111 m | 0.000 / 0.000 m |
| Free foot on the floor while not hopping | 40% | 98% |
| Raider's travel made sliding rather than hopping | 1.07 m (100%) | 0.01 m (2%) |
| Hops on the free foot | 0 | 5 |
| Planted foot's speed along the floor (90th percentile / worst) | 0.24 / 1.72 m/s | 0.15 / 0.22 m/s |
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
| Planted foot's speed along the floor (90th percentile / worst) | 1.07 / 2.01 m/s | 0.14 / 0.36 m/s |

The holder's own body still moves while holding: it is now his arms, chest and legs, as the haul,
the brace and the strain move them.

**Still not right:**

- With other holds on him as well (`chain`, `crowd`), the raider is still carried along by the struggle
  rather than stepping. The ankle holder lies still and the leg holds him.
- A raider who reaches far forward, or is pulled far back, can only be met by the hips sinking 0.3 m at most
  (`MAX_SINK`). Past that the held leg falls short of its hold, although no scenario has needed it yet.
- A single ankle holder now stops a driving raider rather than being dragged to the line. That is what an
  ankle hold should do, but it changes how often raids end with the raider getting home held. The AI bench
  measures it (`docs/REALISM_REVIEW.md`).

### The chain tackle's fall and getting up (2:59-3:03)

**Seen:** the ground contact and the getting up in a chain tackle were too synchronised and mechanical. A
standing team-mate who had helped got up the same way as one who had been underneath.

**What was doing it:**
- Every holder let go in the same frame, `TRIP_HOLD` (0.7 s) after the takedown
  (`Grapple.update`). That was before the raider was even down.
- `Match._tick_post` then gave every leg holder the same 1.2 s get-up from lying on the floor, the kneeling
  thigh holder included. Every other holder was simply stood up ("ready").
- So the ankle and thigh holders rose in step, landmark for landmark, and the rest popped upright.
- On the way down, two things moved the holders:
  - The grapple's body-follow moved them all the way to their place each frame, and overshot.
  - After the raid, `Match._tick_post` also drove every player with his last velocity, holders included. Each
    was moved twice a frame, by two systems.
- The grapple's moves also fed back into the holder's pose: his running gait came from how fast he was moved.
  So the body shook back and forth by up to 0.2 m a frame, and the hands came 0.2-0.4 m off what they held
  in the last part of the fall.

**What it is now:**
- **Letting go.** Each holder lets go at his own moment, keyed to when the raider actually reaches the floor
  (the fall clip's landing; `Grapple.takedown`, `LET_AFTER`):
  - hands round a leg as it comes down;
  - an ankle a moment later;
  - arms round his middle once they have ridden him down.

  Each holder is a little sooner or later than the next, and all have let go by `LET_GO_MAX`.
- **Riding him down.** Every holder but the ankle holder goes down with him as he falls (`bear`), so the hold
  stays a hold until it is let go.
- **Getting up** depends on where each holder actually is when he lets go (`Match._get_up_from_hold`), at his
  own pace:
  - lying on the floor: the full get-up;
  - on his knees or crouched over a leg: up off his knees (`rise`, `RISE_KNEES`);
  - still on his feet, bent over the raider: straighten up (`rise`, `RISE_BENT`);
  - lying under the raider's trunk: he stays down until the raider gets off him.
- **Moving the holders' bodies:**
  - The body-follow takes up only part of the way each frame (`FOLLOW_TIME`), and a shove out of the way is
    spread over frames.
  - Holders still in the grapple are moved by the grapple alone.
  - A holder is not given a stride for being moved, and his own velocity is cleared when he lets go.
  - A tackled raider's velocity is cleared as he goes down.
- **The floor.** A body bent right over no longer flips between "standing" and "not standing" frame to frame
  (`RiggedBody._standing`).

| Chain tackle, `chain` (ankle, thigh, block) | V2 | Now |
|---|---|---|
| Let go after the takedown: ankle, thigh, block | 0.70, 0.70, 0.70 s | 1.00, 0.87, 1.07 s |
| How each got up | from the floor, from the floor, stood straight up | from the floor, off his knees, off his knees after riding him down |
| Up again: ankle, thigh, block | 1.90, 1.90, 0.73 s | 2.27, 1.67, 1.87 s |
| Grip, 90th percentile, all through (the fall included): ankle, thigh, block | 0.069, 0.119, 0.195 m | 0.074, 0.079, 0.018 m |

| Four holders, `crowd` | V2 | Now |
|---|---|---|
| Let go after the takedown | all at 0.70 s | 0.77-1.07 s |
| Up again | 0.73-1.90 s, the two leg holders together | 1.57-2.17 s, each on his own |
| Grip, 90th percentile, all through: ankle, thigh, waist, block | 0.112, 0.081, 0.103, 0.142 m | 0.077, 0.102, 0.034, 0.023 m |
| The raider moving along the floor while down (fastest) | 0.77 m/s | 0.00 m/s |

These are from the final build of this review. A held raider now turns more slowly (see "Ordinary AI matches,
audited"), so in `chain` he lands 0.1 s later, and each holder's times move with him.

### The lion jump out of an ankle hold (2:52-2:54)

**Seen:** the escape was announced, but the bodies did not show how he got free: the hold let go when the
button was pressed, before he had left the floor, and the holder was already getting up.

**What was doing it:**
- `Match._raider_escape` decided the escape and let go of the hold (`_release`) in the frame the jump was called
  for. The jump clip had only just started (its crouch, both feet on the floor), so the held foot came free
  before the jump could have pulled it out of the holder's hands.
- `Match._release` set the holder getting up (`recover`) in the same frame, and `Grapple._open_hands` left his
  hands where they had held. He was pushing himself up before the raider had left the floor, with nothing to
  show that the leg had been torn out of his hands.
- "Lion jump!" and "Broke free!" went up at the press too.
- When the last hold went, `_release` set the raider back to "raid", and `_raider_escape` then started the jump
  again. A dodge out of a hold was cut off the same way, and not started again.
- In the air, his body sped up from 0.8 to 6.9 m/s: `Match._move_raider` drove him toward the jump's speed all
  through it.

**What it is now:**
- **Decided at the press, done with the body.** `_raider_escape` rolls for the escape when the jump is called
  for, as before. Out of a hold, the raider first gathers himself for `JUMP_GATHER` (0.18 s):
  - he sinks on his free leg (`Grapple.GATHER_SINK`), the held foot still in the holder's hands;
  - the jump clip holds its first frame, the crouch it springs from (`HumanModel.play_state` with a wait).
- **The hold lets go as he springs** (`Match._tick_escape`): halfway from the end of the gather to the jump
  clip's own takeoff (`MocapClip.takeoff`, the first frame its lowest point is 3 cm off the floor).
  - The held foot comes out of the hands over `Grapple.TORN_FREE` (0.07 s), as the push-off lifts him.
  - His speed over the floor is set then and kept through the air.
- **The holder** keeps his hands on the leg as it is torn out of them, losing it over `TORN_GO` (0.3 s;
  `Grapple.release`, torn), so his arms are pulled out after it. He lies where it left him, reaching after it,
  for `LOST_GRIP` (0.3 s), then gets up. The get-up clip waits, unseen, until then.
- **"Lion jump!" and "Broke free!"** go up when the hold lets go, not at the press.
- **A jump that does not slip the hold** (the roll failed, or another hold is still on him) goes no further
  than the push-off: the hold stops him leaving the floor, and he comes back down onto his free foot, jolted,
  still held.
- `_release` no longer resets a raider in the middle of the move that freed him (a jump, a dubki or a dodge).

| Lion jump out of an ankle hold, `escape` | V2 | Now |
|---|---|---|
| From the jump called for to the hold letting go | 0.03 s (the next frame) | 0.23 s (0.18 s gathering, then the push-off) |
| Free foot off the floor when the hold lets go | 0.03 m | 0.06 m |
| From the hold letting go to both feet off the floor | 0.03 s | 0.03 s |
| His speed over the floor, landing against taking off | 5.1 m/s faster | the same |
| The holder's hands out from his shoulders, the 0.3 s after (median) | 0.42 m | 0.55 m |
| The holder lying where the leg left him, before getting up | 0.03 s | 0.30 s |
| "Lion jump!" and "Broke free!" | at the press | when the hold lets go |

A new scenario, `stopped`, is a lion jump that does not slip the hold. There is no escape and nothing is let go.
He is held again 0.20 s after the jump was called for, and brought down later.

### A dubki with the ankle still held (3:19-3:24)

**Seen:** the waist hold seemed to come off while the ankle hold went on, and the raider did not look held by
the ankle while he ducked.

**The mechanics, checked in the code:**
- Which hold a move can slip is `Grapple.ESCAPES`:
  - a dubki slips arms round his middle (a waist hold or a block), sometimes a thigh hold, never a held ankle;
  - `Grapple.best_escape` picks the hold the move suits best.

  Ducking out of the arms round him while the ankle stays held is meant to happen.
- The recorded `slip` raid was not what its caption said:
  - The second defender, sent in to hold round the waist, took the free leg instead. A helper claims the
    nearest free slot, and the hold's style follows the slot (a thigh hold).
  - The dubki slipped that thigh hold, and he took the raider round the waist only afterwards.
  - The scenario now brings him in from behind. It is the ankle and arms round the middle: a block in front, as
    the raider has turned away from the ankle hold.

**What was doing it:**
- `Match._raider_escape` let go of the arms at the press, before he had ducked.
- `Match._release` threw the holder back (3 m/s for a hold round the middle) and stood him up ("ready").
- The dubki took the whole body. `Athlete._pose` kept the one-leg stance only in the "held" state, so in the
  "dubki" state the dubki clip's legs and the hand-made squat came back. With one foot held:
  - he squatted on both legs, his hips dropping 0.36 m;
  - the free foot slid (planted half the time);
  - the held foot was pulled 4 cm off its hold.
- A sidestep did the same. `Match._move_raider` drove a dodging raider sideways at 1.9 times his top speed,
  held or not. Held at the ankle, he travelled 0.71 m in a quarter of a second, the held foot 0.14 m off its hold.
  The AI sidesteps when held as often as it ducks or jumps.

**What it is now:**
- **The arms slip as he ducks under them** (`Match._tick_escape`), when the dubki clip is at its lowest
  (`MocapClip.ducked`). "Dubki!" goes up then.
- **The holder's arms slide off his trunk** as it goes down (his hands go with it, as with a lion jump). He is
  left bent over where the raider was, and straightens up (`rise`, `RISE_SLIPPED`) rather than being thrown back.
- **A move made with the ankle held is made on the free leg.** The one-leg stance stays through a dubki, a
  sidestep and the gather for a lion jump (`Athlete._pose`).
  - He ducks his top half and dips on the free leg (`Grapple.DUCK_SINK`).
  - No hop starts in the middle of a move (`Grapple._footwork`).
- **A held raider's sidestep is not driven across the floor** (`Match._move_raider`): the holds move him as they
  do whenever he is held.
- `rise` ends during a raid as `recover` does (`Match._ai_defender`, `_user_defender`).

| Held at the ankle and round the middle, a dubki: `slip` | V2 | Now |
|---|---|---|
| Arms round his middle let go, after the dubki is called for | 0.03 s (at the press) | 0.13 s (as he is down under them) |
| On the free leg all through the duck | no | yes |
| His middle's drop in the duck | 0.36 m | 0.09 m |
| Held foot off its hold, through the duck (furthest) | 0.04 m | 0.00 m |
| Free foot planted through the duck | 50% | 69% |
| The slipped holder, the frame after | thrown back at 1.77 m/s | straightening up where he was, 0 m/s |
| Held ankle from its hold, the whole hold (worst) | 0.451 m | 0.000 m |

V2 and now have the same set-up. In V2 the helper took the waist from behind; now he takes a block from in
front, because the raider has turned away from the ankle hold.

| Held at the ankle only | V2 | Now |
|---|---|---|
| A dubki (`duck`): his middle's drop | 0.35 m | 0.06 m |
| ... free foot planted through it | 8% | 100% |
| ... held foot off its hold (furthest) | 0.031 m | 0.000 m |
| A sidestep (`sidestep`, new): his body moved along the floor | 0.71 m | 0.00 m |
| ... held foot off its hold (furthest) | 0.136 m | 0.000 m |
| ... free foot planted through it | 43% | 100% |

### Ordinary AI matches, audited

**Asked:** proof that the corrections hold in ordinary AI matches, not only in the scripted close-ups. That
means 100 or more deterministic AI-v-AI raids, with the distributions and the worst cases of:
- valid and invalid grapple contacts, and contact-anchor errors through each hold;
- unexplained position corrections and unnatural changes of speed;
- conflicting animation states, and animation or movement softlocks;
- duplicate grapple or scoring events;
- time spent in each tackle phase;
- bodies inside one another.

**How it is measured:** `tests/raid_audit` (see Measuring) plays four whole AI-v-AI matches on Pro, about 120
raids, headless at a fixed 30 fps. It samples every frame of every raid, for every player who was on the mat
when the raid began. The same audit ran on the V2 build for comparison.

- **Seeded.** A match now takes its random numbers from a seed in its config (`Match._ready`); it used to pick
  its own.
- **The defence coach's own numbers.** The coach drew reaction times (`DefenceCoach._react`) from the engine's
  global random numbers, which the sounds and the HUD draw on too. Even a seeded match therefore parted from
  itself within a raid or two. The coach now has numbers of its own, seeded from the match's.
- **Same in every process.** Two runs in separate processes give the same events and scores in all four
  matches (`--digest`). With `--trace`, a match is the same down to every player's place and state in every
  frame (checked on the first match: 10,356 frames).

**What it found in V2, and what was doing it:**

- **Holds.** Every contact was valid, but grips came off during holds:
  - an ankle holder's hands were up to 0.67 m from the leg;
  - a held foot was up to 1.5 m from where the hold had it;
  - holders' speed changed by more than 40 m/s² in 48% of the frames they held.

  These were the faults fixed in the first four tasks: the grapple sliding holders and overshooting at the
  takedown, the lion jump letting go at the press, and the dubki and sidestep moving a held body.
- **57 softlocks**, all after the raid's end:
  - `Match._tick_post` ended neither a wind-up (`telegraph`) nor a dive that the end of the raid caught, so
    the defender stood or lay frozen in that pose until the next raid (49);
  - a raider whose raid ended in the middle of his own move (a lion jump or a dubki over the line) walked back
    to his place held in that move's last frame (8).
- **A held raider shoved** (3 episodes of 13 frames): a dash (`Match._check_contacts`, `_dash_hit`) into a
  raider already held shoved him out from among his holders while the holds were still on him.
- **Bodies inside one another** (4,783 frames over 5 cm). `Match._separate`:
  - kept defenders apart from each other, but set defenders off the raider only while no one held him;
  - kept no one apart after the raid;
  - pushed players apart by 60% of the overlap in one frame, so they jumped (up to 9.7 m/s);
  - pushed bodies lying on the floor about too (lying down and moving faster than 2.5 m/s: 4 episodes).
- **Joint pops** (12,673 bone-frames turning more than 40° in a 30th of a second, the worst 180°), mostly
  forearms and feet:
  - a limb is swung onto the rig from the hand-made placeholder's limb, and where that direction flips, the
    twist about it flips with it (a forearm spinning half a turn in a frame as a player gets up);
  - a foot planted or let go, or a hand reaching for a hold, also turned a bone in one frame.

**Found once the first four tasks were done:**

- A held raider turned to face home as fast as a free one (`face_toward`, 8 rad/s). `Grapple.update` swings
  the holders round his middle with him, so a front waist holder was swung round at 9-12 m/s.
- The hips came up out of the held leg's sink in one frame when a hold let go (`RiggedBody._sink_to_hold`
  sank them only while the hold had the foot). In the scripted `escape` the raider is not pulled far back. In a
  match he can be: a lion jump out of the hold then threw his middle up 0.3-0.6 m in a frame, and so did a
  sidestep out of one.
- Coming out of a dubki or landing a jump, a raider's speed was cut to a third in one frame (the plant in
  `Match._tick_raid`): 8 m/s to 3 m/s, about 170 m/s².
- When a lion jump out of an ankle hold was stopped by another hold (a block, or arms round his middle), the leg
  let go of came back into what the body stands on in one frame (`RiggedBody._held_legs`). Posed reaching back
  and down below his low hips, it lifted him 0.35-0.48 m in a frame. A dubki that slipped a thigh hold did the
  same. The lion jump's own release dipped the hips first: for a frame the foot being let go of still pulled them
  down as he sprang (`_sink_to_hold`).
- An ankle hold caught a back kick by the leg the raider stood on in that pose. Left out of what the body stands
  on, the body dropped onto the other leg, raised mid-kick: 0.75 m in a frame.
- A hop on the free foot (`Grapple._footwork`) froze half-done when a second hold came on, and was taken up again
  where it had stopped when that hold was slipped. It yanked the raider 0.42 m along its old path in a frame
  (12.6 m/s), the held foot 0.1 m off its hold.
- At the end of a raid, `Match._put_out` and `_react` set players walking, slumping, arguing or celebrating in
  the frame the raid ended, whatever they were doing. A defender getting up from a dive snapped to his feet
  (0.47 m in a frame), and a tackled raider told to argue got up off the floor in an instant.
- A raider put out at the end of a raid stood frozen for a second (`_tick_post` left anyone off the mat to
  `_walk_to_positions`, which starts a second in). He then slid off toward the bench on the speed he had had,
  up to 7 m/s.
- The audit itself stopped watching a raider the moment he was put out, which a tackle does, so his fall and
  getting up went unchecked. It now watches everyone who was on the mat when the raid began, until the raid is
  over.

**What it is now:**

- **Moves the raid's end catches** (`Match._tick_post`): a dive lands and he gets up; a wind-up comes to nothing;
  any other move runs its course and he stands.
- **Reactions wait for the body** (`Match._react_as`). A player told to slump, argue, roar or celebrate while he
  is down or in the middle of a move does it once he is up, or down from the move (`_after_getup`). A player put
  out finishes what he is doing, then walks off (`_put_out`, `_to_bench`).
- **A dash into a held raider** only bumps into the struggle (`_check_contacts`).
- **Keeping apart** (`Match._separate`, `_apart`, `_nudge`):
  - standing players who are not holding keep off the raider while he is held, and step off bodies on the floor;
  - a body on the floor or in the grapple is never pushed;
  - nobody is moved faster than `NUDGE` (3 m/s);
  - after the raid, players walking back or cheering keep apart too.
- **No bone turns faster than 1,200°/s** (`RiggedBody._limit_turns`, the last pose stage), whatever turned it.
  A bone that would turn further goes as far as it may now and the rest over the next frames.
- **A held raider turns no faster than 1.5 rad/s** (`Athlete.turn_toward`, `HELD_TURN`).
- **Up at a push-off's pace.** The hips come back up out of a held-leg sink, and onto a leg let go of, no faster
  than `SINK_RISE` (2.5 m/s): he straightens as he springs, and the leg bends under him as it comes back. A
  foot being let go of no longer pulls them down. Held by the leg he stood on, he comes down onto the other no
  faster than `SETTLE_DROP` (3 m/s).
- **A hop is dropped when another hold comes on** (`Grapple.update`): the struggle moves him from then on.
- **The plant** out of a dubki or a jump sheds the burst over a step (`PLANT`, 40 m/s² for up to 0.15 s), not
  in a frame.
- **Players who are out** go to the bench from the moment the raid ends, slowing from where they were going.

| Four AI matches on Pro, every frame of every raid | V2 | Now |
|---|---|---|
| Raids (tackles, escapes) | 118 (20, 28) | 120 (27, 23) |
| Holds checked once the hands had closed: valid / invalid | 89 / 0 | 103 / 0 |
| Grip, hands from the part held: median / 99th percentile / worst | 0.061 / 0.231 / 0.674 m | 0.066 / 0.123 / 0.212 m |
| Held foot from where the hold has it: 90th / 99th percentile / worst | 0.474 / 1.343 / 1.506 m | 0.000 / 0.000 / 0.078 m |
| Frames with a speed change over 40 m/s² (share of all body-frames; of holders' frames) | 3,740 (0.8%; 48%) | 1,575 (0.3%; 4%) |
| Sharpest speed change | 410 m/s² | 261 m/s² |
| A body moving over 9 m/s in a frame | 10 | 7 (sidesteps) |
| A body's middle moving more than 0.2 m beyond the body in a frame: frames / worst | 124 / 0.46 m | 132 / 0.32 m |
| Joint pops, bone-frames over 40° in a 30th of a second / worst | 12,673 / 180° | 8,891 / 40° |
| Bodies inside one another, frames over 5 cm / 99th percentile depth | 4,783 / 0.23 m | 3,621 / 0.21 m |
| Conflicting states, episodes: a held raider shoved / lying on the floor and moving over 2.5 m/s | 3 / 4 | 0 / 3 (a frame each) |
| Duplicate or impossible events / matches whose points do not add up | 0 / 0 | 0 / 0 |
| Softlocks | 57 | 0 |

The tackle phases, in seconds (median, 90th percentile, worst, and how many):

| Tackle phase (s): median, 90th percentile, worst | V2 | Now |
|---|---|---|
| Winding up | 0.37, 0.43, 2.97 (336) | 0.37, 0.43, 0.70 (318) |
| The dive | 0.30, 0.30, 2.83 (354) | 0.30, 0.30, 0.30 (360) |
| The hold, first hold to the takedown or the last let go | 1.60, 3.33, 4.53 (50) | 2.30, 3.47, 3.97 (43) |
| Takedown to his middle at the floor | 0.67, 0.70, 0.73 (17) | 0.60, 0.63, 1.03 (26) |
| On the floor | 1.07, 1.10, 1.10 (17) | 1.10, 1.17, 1.17 (26) |
| Getting up | 1.40, 1.40, 1.40 (17) | 1.40, 1.40, 1.40 (26) |
| Each holder letting go, after the takedown | 0.73, 0.73, 0.73 (56) | 0.93, 1.10, 1.23 (79) |
| Each holder up again, after the takedown | 1.93, 1.93, 1.93 (56) | 1.77, 2.13, 2.37 (79) |
| A lion jump's gather out of a hold | none: it let go at the press | 0.17, 0.17, 0.17 (12) |

In V2 every holder let go 0.73 s after the takedown and was up at 1.93 s; now each does so at his own moment
(Task 2). A wind-up or a dive no longer runs on past the end of the raid (V2's 2.97 s and 2.83 s). Holds last
longer, now that a lone ankle holder stops a driving raider rather than being slid to the line (Task 1).

**Still not right:**

- **Middles jumping.** In 132 frames a body's middle moved more than 0.2 m beyond the body, about as many as
  V2's 124. The worst is lower (0.32 m against 0.46 m), and only 5 pass 0.3 m:
  - about half (63) are the hand-made ankle dive. As the diver goes down onto his chest, the body is grounded on
    his chest and arms instead of his feet (`RiggedBody._ground`), and drops up to 0.3 m in a frame. A hold
    taken at the bottom of the dive carries it on (16). V2 does the same;
  - getting up off the floor, as the get-up clip takes over (23, and 7 straightening up);
  - out of a lion jump's gather. The one-leg stance lets go of a deep crouch in a sixth of a second
    (`Athlete._pose`, `one_leg`), and a jump stopped by a hold blends from the crouch into the held clip
    (`held_pull`): up to 0.31 m in a frame.
- **Speed changes.** 1,575 frames still change speed by more than 40 m/s², each for a frame or two:
  - a dive's launch, its speed set at once (`DIVE_LAUNCH`) whichever way he was going: 13% of dive frames;
  - a dive meeting the raider and becoming a hold;
  - a defender nudged out of the way (`_nudge`), the nudge starting and stopping at once;
  - the spring of a lion jump out of a hold, his speed over the floor set as he leaves it.
- **A sidestep** reaches 9.6 m/s for the quickest raiders: 1.9 times top speed, as the move is designed.
- **Bodies inside one another.** There are 3,621 frames over 5 cm (99th percentile 0.21 m), most of them round a
  held raider. The audit's three spheres to a body are a rough shape, and bodies in a struggle are meant to
  touch, so some of this is contact.
- **Joint turns.** The last pose stage holds back 0.65% of bone-frames. It hides the flips rather than removing
  their cause (a limb's twist flipping with the placeholder limb's direction).
- **A new hold's sink.** A hold that catches a leg reaching far back sinks the hips up to 0.3 m in one frame
  (`_sink_to_hold`), so that the held foot is never off its hold. Easing it in would leave the foot short of the
  hands for a frame or two.
- **The worst grips**, for a frame or two: an ankle holder's hands 0.21 m from the leg, a thigh holder's 0.20 m
  (the 99th percentile of all grips is 0.12 m).
- **With two holds on him**, the raider is still carried along by the struggle between hops: in `slip`, 0.57 m
  of his travel slid.
- **What the audit sees:**
  - An audited match is repeatable, but it was not, frame for frame, the match the same seed played as a
    recording, and a replay of the first match in the same process (`--again`) parted from it by a millimetre.
    This was put down here to the audit's reads of the skeletons. It was not them: see "What the audit left,
    fixed" below.
  - It does not sample the setup between raids, or a player put out in an earlier raid walking to the bench.

### What the audit left, fixed

**Asked:** fix what the audit of ordinary matches still found (the "Still not right" list above): bodies' middles
jumping in a frame; speed changing in a frame (a dive's launch, defenders nudged aside); joint flips that the last
pose stage only hid; a raider with two or more holds on him carried along by the struggle rather than stepping;
and the audit's own effect on the match it watched.

**The audit's own effect: there was none.** An audited match and the same seed played without the audit's reads of
the bodies are the same, frame for frame (`--digest` and `--trace`, a run with the reads against one without). Two
other things made the audited match differ from the recording of the same seed:

- **The audit re-seeded the match** (`m.rng.seed` set after `add_child`), after `Match._ready` had already drawn
  the coin toss from its seed. Every other run (the recording, the game) takes the seed from the config only, so
  the audit played a different match from the same seed. It no longer re-seeds.
- **The engine's first frames are not a 30th of a second**, even at a fixed frame rate: 0.025, 0.033, 0.042,
  0.029, 0.030 and 0.0325 s, then steady (its physics sync settling in). A match begun in them, the first in any
  process, plays its first moments on those steps: the bodies' clip times and footing come out a fraction of a
  millimetre different from the same match begun later, and the difference grows (a replay in the same process
  parted from the first at the third raid). The audit and the recording script (`tests/match_record`) now begin
  a match only once the steps are steady (`raid_audit._steady`).

The explanation given above (the reads bringing the poses up to date early) was wrong.

**Joint turns.** `RiggedBody._swing` turned each limb bone onto the hand-made placeholder's limb by the shortest
turn from the bone's rest direction. That turn is undecided when the limb points nearly opposite its rest
direction, and its twist flips half a turn as the limb passes it: a forearm held up in front of the chest (its rest
is down at the side), the foot of a man lying face down. The last pose stage then spread the flip over a few
frames rather than removing it.

- Each bone is now swung from where its parent, already turned, carries it. An elbow or a knee folds about its own
  axis; the turn would be undecided only for a joint folded right back on itself, which none is.
- A foot laid flat on the floor (`_flatten`) is left alone while it points nearly straight down (on its toes):
  laid flat from there, which way it lies flipped end for end as it passed the vertical.

**Middles jumping.** The body is put on the floor by its lowest point every frame (`RiggedBody._ground`). When what
is lowest changed (a diver's chest going lower than his feet), or the pose changed quickly (a get-up clip blended
in over three frames, a hold's sink, a spring out of a crouch), the hips moved 0.2-0.35 m in a frame.

- `RiggedBody._limit_height`, after the grounding and the sink: the hips rise no faster than 4 m/s (`RISE_MAX`) and
  come down no faster than 5 m/s (`FALL_MAX`) against the body's root. Held down, a foot that would go through the
  floor is lifted out of it (the knee bends); held up while standing, a foot that was on the floor reaches down to
  it, as far as the leg goes.

**Speed changes.**

- **The dive** drives off the floor over its first 0.14 s (`DIVE_PUSH`), from the speed the diver had (`move_vel`,
  how he was moving over the floor) up to 4.5 m/s, then slows to land as before. It covers the same ground (0.8 m)
  in the same time; its sharpest change is about 32 m/s² instead of 117 m/s².
- **Keeping players apart** (`Match._separate`, `_apart`, `_nudge`, `_push_all`). A player who steers himself steers
  round anyone he is about to walk into (`Athlete.avoid`, added to where he means to go in `Athlete.drive`): no
  further toward them, and out of their way within 0.15 s (`AVOID_TIME`), at his own pace. It looks 0.2 s ahead at
  how players are going (`SEPARATE_LOOK`), so they turn aside before they meet; a free raider is taken where he is,
  not where he is going, so no one gives way to a touch. A player standing still is eased aside instead: no faster
  than 3 m/s, and getting up to that speed no quicker than 15 m/s² (`NUDGE_ACCEL`). Players getting up off the
  floor next to another body there shuffle out from under it, no faster than 0.6 m/s (`SHUFFLE`). Pushed aside in
  one frame, as before, a player was knocked (90 m/s²); pushed against his own steering, he walked into the other
  first.
- **The lion jump out of a hold** drives off the free leg up to its speed at 35 m/s² (`SPRING`), not in a frame.
- **Caught on the move** (any hold but the ankle), the raider carries on into the hold, his speed dying away at
  35 m/s² (`Grapple.carry`, `CARRY_STOP`), rather than stopping dead. Caught by the ankle, his stumble onto the free
  foot starts at the speed he had and dies away.
- **A holder's body** is brought round to his place no quicker than 35 m/s² (`HOLD_ACCEL`): a diver who has just
  taken hold is slowed and brought back over a few frames, not turned round in one. Keeping clear of the raider
  and the other holders is not limited.
- **An evasion** that would reach a line pulls up short of it (`Match._evade`, `evade_to`) instead of running into
  the court's edge, which stopped him dead.
- **Taken down with arms round him** as well as an ankle held, the raider no longer turns to fall away from the
  ankle (`Grapple.ankle_only`): his drawn body turned at up to 900°/s, and the arms round his middle were swung
  round with it at 11-12 m/s.

**Held by more than one, he gets about only as his legs let him** (`Grapple.footwork`, `pinned`, `_steps`;
`Match._move_raider`):

- **One leg held**, at the ankle or the thigh, whatever else holds him: he hops on the free foot (`_footwork`). Each
  hold round his middle as well shortens his hops (`HOP_HELD`), and he turns no faster than the holds let him
  (`HELD_TURN`), the arms round him swinging round with him.
- **Both legs held:** he cannot take a step, nor turn on the spot. He stays where he is and fights the holds with
  his trunk; the struggle goes on to the takedown as before.
- **Held only round the middle** (a waist hold, a block): he steps (`_steps`). The struggle sets how far he could go;
  he covers it a step at a time (`STEP_TIME`, `STEP_MAX`), his trailing foot coming through (`RiggedBody.step`: up,
  across, down, planted where it lands) while his body goes over the planted one, both feet down between steps. He
  turns only as he steps, at half the held rate (pivoting on the planted foot). The held clip's own leg work would
  fight the steps, so his legs are the braced stance underneath (`HumanModel.clip_legs`), with no running stride.

**In numbers.** `raid_audit` on the last round's build ("Before": the build the list above was written for, run
with this round's audit) and now, four matches each from the same seeds. A change anywhere plays the matches
differently, so the counts move with how many tackles and dives a run happens to have; rates per frame of the
state they belong to compare better.

| Four AI matches on Pro, every frame of every raid | Before | Now |
|---|---|---|
| Raids (tackles, escapes) | 122 (23, 34) | 120 (21, 30) |
| Holds checked: valid / invalid | 94 / 0 | 83 / 0 |
| Grip, hands from the part held: median / 99th percentile / worst | 0.059 / 0.122 / 0.157 m | 0.062 / 0.122 / 0.146 m |
| Held foot from where the hold has it: 99th percentile / worst | 0.000 / 0.054 m | 0.000 / 0.102 m |
| A body's middle moving more than 0.2 m beyond the body in a frame: frames / worst | 113 / 0.35 m | 4 / 0.20 m |
| Frames with a speed change over 40 m/s² (per 1,000 body-frames) / sharpest | 1,490 (3.21) / 231 m/s² | 408 (0.91) / 243 m/s² |
|   of them defenders standing ready (nudged aside): frames over / share of that state's frames | 576 / 0.3% | 88 / 0.0% |
|   of them diving: frames over / share of that state's frames | 342 / 12.2% | 109 / 4.1% |
|   of them holding: frames over / share of that state's frames | 218 / 3.9% | 36 / 0.7% |
|   of them the held raider: frames over / share of that state's frames | 42 / 1.8% | 6 / 0.3% |
|   of them winding up: frames over / share of that state's frames | 67 / 2.0% | 49 / 1.5% |
|   of them evading a touch: frames over / share of that state's frames | 25 / 7.1% | 1 / 0.3% |
|   of them the raider, free: frames over / share of that state's frames | 133 / 0.5% | 96 / 0.3% |
| Joint pops (bone-frames turning 40° in a 30th of a second, all at the last stage's cap) | 8,554 | 5,297 |
| Bone turns the last pose stage held back (share of bone-frames) | 42,267 (0.65%) | 18,801 (0.30%) |
| Bodies inside one another, frames over 5 cm | 2,922 | 2,374 |
|   the raider and a defender (per held frame) | 0.45 | 0.42 |
|   the raider and his holder; two holders (per holder's frame) | 0.158; 0.042 | 0.110; 0.032 |
|   anyone else (per 1,000 body-frames) | 1.53 | 1.77 |
| A body moving over 9 m/s in a frame | 2 | 14 |
| Conflicting states (episodes) | lying on the floor, moving over 2.5 m/s: 6 | lying on the floor, moving over 2.5 m/s: 2 |
| Duplicate or impossible events / matches whose points do not add up | 0 / 0 | 0 / 0 |
| Softlocks | 0 | 0 |

| Tackle phase (s): median, 90th percentile, worst (how many) | Before | Now |
|---|---|---|
| Winding up | 0.37, 0.43, 0.67 (320) | 0.37, 0.43, 0.43 (308) |
| The dive | 0.30, 0.30, 0.30 (329) | 0.30, 0.30, 0.30 (318) |
| The hold, first hold to the takedown or the last let go | 1.90, 2.87, 4.97 (51) | 1.53, 3.13, 4.80 (45) |
| Takedown to his middle at the floor | 0.57, 0.67, 1.17 (22) | 0.67, 0.77, 1.23 (21) |
| On the floor | 1.10, 1.10, 1.17 (22) | 1.07, 1.10, 1.10 (21) |
| Getting up | 1.40, 1.40, 1.40 (22) | 1.40, 1.40, 1.40 (21) |
| Each holder letting go, after the takedown | 0.93, 1.07, 1.23 (60) | 0.93, 1.17, 1.23 (51) |
| Each holder up again, after the takedown | 1.80, 2.20, 2.33 (60) | 1.80, 2.37, 2.43 (51) |
| A lion jump's gather out of a hold | 0.17, 0.17, 0.17 (13) | 0.17, 0.17, 0.17 (8) |

The joint turns the last pose stage still holds back are almost all turns just over its 1,200°/s, which it slows a
little: a clap, a foot rolling through a step. Counted over a whole match (seed 1), every body on the mat and off
it, by how far the bone was asked to turn in a 30th of a second:

| One match, every body: bone turns the last pose stage held back | Before | Now |
|---|---|---|
| All | 16,116 | 7,656 |
| Asked to turn 80° or more in a 30th of a second | 2,444 | 168 |
| Asked to turn 120° or more (a flip) | 565 | 0 |

Held, in the scripted scenarios (`tackle_check`). "Free foot" is a foot not held by anyone:

| Held by | How he gets about | A free foot on the floor sliding along it (m/s, 90th percentile) | Times a free foot leaves the floor |
|---|---|---|---|
| A thigh hold (`thigh`) | slid 0.84 m → 4 hops (0.03 m slid) | 1.05 → 0.23 | 3 → 5 |
| Arms round his middle, a block in front (`waist`) | slid 0.50 m → 0.42 m in steps | 0.72 → 0.09 | 4 → 6 |
| The ankle, and arms round him (`slip`) | 0.37 m slid between hops → 0.03 m | 0.57 → 0.09 | 3 → 4 |
| Both legs (`join`), and a block (`chain`), and arms behind (`crowd`) | slid 0.24, 0.71, 0.85 m → stays where he is (0.03 m) | | |
| The ankle alone (`catch`, as before) | hops (5) | 0.15 → 0.25 | 4 → 5 |

| | Before | Now |
|---|---|---|
| Sharpest change of speed of the first holder: `thigh`, `waist`, `chain` (m/s²) | 60, 68, 39 | 35, 37, 31 |
| Sharpest change of speed of the raider: `thigh`, `waist`, `chain` (m/s²) | 3, 3, 12 | 31, 31, 5 |
| Hold to takedown: `catch`, `chain`, `thigh`, `waist`, `slip` (s) | 3.43, 1.63, 3.23, 2.60, 2.93 | 3.43, 1.90, 3.23, 2.60, 2.93 |

(The raider's sharpest change under a thigh or a waist hold is now his speed dying away into the hold, 31 m/s²;
before, he slid on at the struggle's pace.)

**Checks.**

- The audit with all its reads and the same audit with none (its per-frame work cut to the state bookkeeping),
  in separate processes: byte-identical traces, every player's place to a micrometre, state and timer, every frame
  of four matches (43,468 frames), and the same 894 events.
- The first match played again in the same process (`--again --trace`): the same, frame for frame.
- A recording (`tests/match_record`, rendered with the movie writer) against the audit's trace of the same seed:
  the same match, every player's place, state and timer identical in all 10,506 frames of its 32 raids, through
  to the final whistle.
- `tackle_check`: all 17 scenarios as expected; `test_runner` at a fixed 30 fps, as CI runs it: all checks pass;
  `compile_check`: no broken scripts.

**The game itself.** `ai_bench`, eight matches on Pro each (random seeds), before and now: more raids end in a
tackle (35 of 237, 15%, against 53 of 247, 21%) and fewer out of bounds (30, 13%, against 20, 8%); the share of
successful raids is the same (65%). Raid points 260 and 272, defence points 69 and 83. A raider held by both legs
no longer travels, so the struggle can no longer carry him over a line; he is brought down instead.

**Still not right:**

- **Speed changes** are down to 408 frames over 40 m/s² (0.9 per 1,000 body-frames, against 3.2). What is left:
  - a dive's first frames (4% of dive frames, against 12%);
  - a holder kept clear of the raider in the first frames of a hold, while the raider is still carried on by his
    speed (keeping clear is not limited; 0.7% of holders' frames);
  - a raider's own sidestep, built at 1.9 times his top speed (it also passes 9 m/s for the quickest raiders: 14
    frames in these matches, how many depending on how many sidesteps a run has).
- **Bodies inside one another**: fewer than before (2,374 frames over 5 cm, against 2,922), and fewer in the
  struggle, but players outside it still meet a little more often than when they were pushed apart in a frame
  (1.77 against 1.53 frames per 1,000 body-frames): two defenders stepping into the same place, a helper running
  in past a holder. Steering round takes a few frames once they have met head on.
- **Middles jumping:** 4 frames just over 0.2 m (worst 0.20 m), a holder's dive coming down into his hold.
- **A held foot** can be short of its hold for a frame or two (worst 0.10 m, the 99th percentile still 0): a new
  hold's sink now comes in at 5 m/s rather than in one frame.
- **An ankle dive's first grip** is looser than before (0.21 m from the ankle as the hands close, within the 0.3 m
  contact): the dive now reaches him two frames later in its arc. Through the hold it is as before (median 0.05 m,
  90th percentile 0.07 m).
- **The steps** of a raider held round the middle are made by the body, not a captured clip: the trailing foot comes
  through on an arc while the other stays planted. They start once the speed he was caught at has died away.

### The rest of the list, and what the last fixes broke

**Asked:** keep going: the last middles jumping, what was left of a dive's launch, and the three things the last
round made worse (players outside the struggle meeting more often, an ankle dive's looser first grip, a held foot
short of its hold).

**A body sent off to infinity (found on the way).** In one of sixteen benchmark matches a raider's body went to NaN for
good: millions of warnings, the model gone. The cause was older than this round. Held by one leg and standing on the
other, he had his standing leg caught in the same frame as the hold on the other let go of it. `RiggedBody._ground`
then looked for the lowest point of a body with both legs out of what he stands on (the one let go of, coming back
into it, and the one just caught), found none (INF), and took that as a sink to come up out of: an endless one. Last
round's limit on the hips let them down at 5 m/s, so he sank through the floor at that speed for the rest of the
raid; this round's limit on the middle subtracted the infinity, and the body went to NaN. Fixed where it starts:
nothing left to stand on is no sink at all. The middle's limit and the new keeping apart also leave a body that is
not finite alone, rather than spreading it to anyone else. `tests/test_runner` now checks it (section 8a): the left
ankle held, then let go of in the frame the right is caught. Without the fix the check fails (the middle off to
infinity, the freed ankle 0.22 m in the air); with it, the middle stays where it was and the ankle is back on the
floor.

**An all out with the last man still held (found on the way).** When a tackle put out a team's last man, the all out
brought the whole team back at once and set every one of them walking: the tackled raider too, in the frame he began
to go down. He stood where he was with the holders still on him and, a second later, walked off to his place; arms
round his middle were swung round with him as he turned (`Grapple.update`), 0.3-0.5 m a frame, the fastest anything
moved in these matches (up to 14 m/s). The all out has done this since it was written; it came up three times in this
round's first four matches. Now a player brought back while down or in the middle of a move finishes it first (the all
out in `Match._end_raid`, and `_revive`): the raider goes down, lies there and gets up like any tackled raider, then
walks back.

**Keeping apart by the body's shape.** Players were kept apart by where their feet were. A holder bent over the raider
reaches well past his feet, and a diver on the floor is a body's length along it: a defender walked into a holder,
and two divers getting up side by side lay inside one another, their feet a body's width apart.

- Each body is its trunk, from his middle to the top of his head, where it is about to be (`Match._trunk`), and a
  player on his feet keeps 0.4 m from the trunk of anyone on the floor, getting up or in the grapple (`_nudge_body`,
  `BODY_GAP`), in three dimensions: a helper stepping in past a team-mate lying at the ankle is a body's height above
  him, and goes on to his hold. (Kept apart along the floor only, the helper in `tackle_check slip` never got there.)
- After the raid too, and the players put out with them: they walked off to the bench straight through their
  team-mates (`_tick_post`).
- A player standing over a man lying flat is not moved: his trunk is a body's height above the other's. His legs can
  be in the other man's body (as they could before: kept off a body's feet only, he stood about as close, waist to
  waist, in `tackle_check`).
- Bodies inside one another outside the struggle, over eight matches: 1.82 → 1.47 frames per 1,000 body-frames
  (on the four matches of last round's table, 1.77 → 1.18; 1.53 the round before).

**What was left of a dive's launch** was three things:

- **A defender against the sideline.** The defence's place for a corner defender can be past the line's margin, and
  he ran at it every frame, the clamp holding his position but not his speed. In his wind-up (not clamped) he was off
  sideways at that speed, and the dive's first frame snapped him back: a lurch of up to 9 cm. Now the clamp takes the
  speed into the line with it (`Match._clamp_defender`), and runs after he is moved aside as well as on his own step.
- **A frame late.** Out of the wind-up the dive did not move in its first frame (`_ai_defender` returned before it).
  It does now.
- **The push-off** gets him to the dive's speed from however he was moving, no quicker than the push off a
  standstill (`_dive_motion`): stepping across or back as he went, he is no longer turned round in a frame. It covers
  the ground the old dive did: out of the wind-up (4.0 m/s, the sharpest change 31 m/s²) to within 4 cm at every
  frame; at the player's button (5.0 m/s, 38 m/s²), where the old dive went in its first frame and so always reached
  further (0.95 m against 0.81), to within 4 cm from the fifth frame. Last round's push (4.5 m/s for both) put the
  defence's dives a few centimetres ahead mid-flight, and they held more often (32 tackles against 21 in the same four
  matches); the player's dives fell 15 cm short (the scripted ankle dive missed him altogether).
- Frames with a speed change over 40 m/s², eight matches: diving 195 → 16 (3.5% → 0.3% of dive frames), winding up
  84 → 2, the free raider 208 → 0. What is left of the dive is its first two frames, all under 63 m/s².

**The ankle dive's first grip** came with it: the scripted ankle dive (`tackle_check catch`) takes the near ankle at the
moment it always did (0.77 s), its hands 0.086 m from it on the first frame (0.075 m before last round; last round
0.208 m, on the other leg, three frames later). The thigh and waist dives reach at their old moments too (0.77 and
0.73 s), but their hands are further from the part on the first frame than in either of the last two rounds: thigh
0.12 m (0.06 before last round, 0.09 last round), waist 0.15 m (0.13, 0.11).

**Middles jumping.** The fall limit held the hip joint, but a trunk tipping forward lowers the middle (most of the way
from the hips up the spine, where the audit measures it) as well, and a dive still dropped it 0.2 m in a frame. The
limit is on the middle now (`RiggedBody._limit_height`): over eight matches, frames with a middle moving over 0.2 m
14 → 0 (worst 0.21 → 0.17 m).

**The free foot in a held dubki.** Planting a foot judged where the floor is from the lower of the two feet, held or
not. A dubki that put the held foot lowest had the free one off the floor and never planted: in `tackle_check duck`
the free foot was planted for 8% of the dubki (all of it before last round), in `sidestep` 63%. The held foot is left
out now, as the body's grounding already left it out, and a free foot caught mid-stride is planted once the body has
come down onto it, not in the air (`_plant_feet`). It is planted all through again, and a held raider's feet slide
less: 90th percentile, last round and now, 0.25 → 0.07 m/s (`catch`), 0.21 → 0.07 (`drag`, `stopped`), 0.24 → 0.08
(`duck`, `sidestep`), 0.23 → 0.18 (`thigh`); 0.09 → 0.13 held round the middle (`waist`). (The measure of a free foot
on the floor reads 0.88-0.97 now, against 1.0, in `catch`, `drag`, `stopped`, `sidestep` and `slip`: in the frames
it counts as up, the foot is 3.0-3.2 cm above the floor, against a limit of 3 cm.)

**Smaller things:**

- After a raid, from a second in, nearly everyone was moved twice a frame: by his own post-raid logic (standing still,
  or jogging over to slap hands) and by the walk back to his place; holders letting go were moved by the grapple and
  driven as well. Each is moved once now.
- An ankle diver's slide into his hold stops over a few frames as his elbows give (no quicker than 38 m/s²,
  `Grapple.SLIDE_STOP`), not dead in one as his shoulders reach the ankle.
- The raider's plant out of a dubki or a jump sheds speed at 38 m/s², not 40 (counted over the limit by rounding).
- An evading defender pulled up short of a line by easing in over the last 0.9 m, which he could not do from a
  sprint: he ran on into the court's edge, and the clamp, now taking his speed into the line with it, stopped him
  dead. He now runs no faster than he can stop by the line at his own acceleration (`_ai_defender`, "evade").
- The audit counted a body's second frame of a raid against a first frame it had not measured (as standing still):
  28 of last round's 408 speed changes. It no longer does, and both columns below are measured that way.

**In numbers.** `raid_audit` on last round's build ("Before", run with this round's audit) and now, eight matches
each (seeds 1-8; four, as last round, swing too much from one set of seeds to the next: a raider and a defender
inside one another went from 0.42 to 0.64 per held frame between two sets of four on the same build).

| Eight AI matches on Pro, every frame of every raid | Before | Now |
|---|---|---|
| Raids (tackles, escapes) | 240 (45, 70) | 247 (45, 56) |
| Holds checked: valid / invalid | 181 / 0 | 172 / 0 |
| Grip, hands from the part held: median / 99th percentile / worst | 0.06 / 0.12 / 0.22 m | 0.06 / 0.12 / 0.30 m |
| Held foot from where the hold has it: 99th percentile / worst | 0.000 / 0.10 m | 0.000 / 0.18 m |
| A body's middle moving more than 0.2 m beyond the body in a frame: frames / worst | 14 / 0.21 m | 0 / 0.17 m |
| Frames with a speed change over 40 m/s² (per 1,000 body-frames) / sharpest | 705 (0.77) / 243 m/s² | 246 (0.27) / 211 m/s² |
|   of them diving: frames over / share of that state's frames | 195 / 3.5% | 16 / 0.3% |
|   winding up | 84 / 1.2% | 2 / 0.03% |
|   the raider, free | 208 / 0.4% | 0 |
|   holding | 60 / 0.55% | 70 / 0.64% |
|   the held raider | 19 | 8 |
|   defenders standing ready | 112 / 0.03% | 116 / 0.03% |
|   evading a touch | 0 | 4 / 0.6% |
|   getting up | 7 | 8 |
| Joint pops (bone-frames at the last stage's cap); bone turns it held back | 11,067; 0.32% | 12,298; 0.33% |
| Bodies inside one another, frames over 5 cm | 5,754 | 5,520 |
|   the raider and a defender; the raider and his holder; two holders (per holder's frame) | 0.218; 0.117; 0.040 | 0.212; 0.133; 0.039 |
|   anyone else (per 1,000 body-frames) | 1.82 | 1.47 |
| A body moving over 9 m/s in a frame | 17 (a raider's sidestep, or its last frame) | 10 (the same) |
| Lying on the floor and moving over 2.5 m/s (episodes) | 5 | 6 |
| Duplicate or impossible events / matches whose points do not add up / softlocks | 0 / 0 / 0 | 0 / 0 / 0 |

Tackle phases are as before (winding up 0.37 s, the dive 0.30 s, on the floor 1.07 s, getting up 1.40 s, each
holder letting go 0.93-0.97 s after the takedown: medians, both builds).

**The game itself.** `ai_bench`, sixteen matches on Pro each (random seeds), last round's build and now: much the
same. Successful raids 63% and 64% (301 of 478, 302 of 473), tackles 20% and 21%, out of bounds 10% and 8%, empty
raids 7% and 6%; raid points 511 and 515, defence points 157 both. The defence's shape (its line's depth and spread,
the way home covered as the raider runs for it) is as it was, so players walking back once a raid is over, moved
once a frame now, still get to their places. (The bench's own check of the events stopped at a broken chain's event,
which names both defenders; it reads it now.)

**Checks.**

- `test_runner` at a fixed 30 fps, as CI runs it: all 185 checks pass, the new one among them (it fails on the code
  before the fix: the middle off to infinity, the freed ankle 0.22 m up).
- `tackle_check`: all 17 scenarios as expected.
- `compile_check`: no broken scripts.
- The audit and the diagnostic build of it (its extra prints) on the same four seeds: the same 450,439 body-frames and
  every count the same.
- The audit run again in a separate process, traced: the same four matches entry for entry, every player's place,
  state and timer in each of the 41,481 frames, and every event and score change (42,428 entries in all).

**Still not right:**

- **A thigh hold's grip, at its worst.** A few tenths of a second into a thigh hold, the hands can be up to 0.30 m
  off the thigh for a few frames (0.22 m before), just inside what still counts as a hold (all 172 were). The median
  and 99th percentile are as before (0.06 and 0.12 m). All of the worst grips, before and now, are thigh holds; in
  the scripted scenarios the thigh and waist dives' first grips are looser too (above). Not found yet.
- **A held foot in a lion jump's first spring frame.** The hold lets go halfway from the end of the gather to the
  takeoff, so the leg leaves the hands as he leaves the floor; in the frame before, the foot is still held while the
  body has begun to rise off it: up to 0.18 m off its hold in these matches (0.10 m before). One frame per jump out
  of a hold; the 99th percentile is 0.
- **The raider and his holder** are inside one another a little more often (0.117 → 0.133 per holder's frame, both
  sets of four higher than either before), and holders' speed changes are about as before (0.55% → 0.64% of their
  frames): the struggle's own contact, not looked into yet.
- **Speed changes** left (246 frames, 0.27 per 1,000 body-frames): defenders standing ready (116, as many as before);
  holders (70, 55 of them in a hold's first 0.2 s); a dive's first two frames (16, under 63 m/s²); getting up (8, up
  to 79 m/s²: mostly a holder letting go, who stops in the frame he starts to get up, what the grapple last moved him
  by dropped at once); an evasion stopped by a line (4: two of them a sprint with no line within the evasion's planned
  reach, which carried him to one).
- **A raider's sidestep** passes 9 m/s for the quickest raiders (10 frames): it is built at 1.9 times his top speed.
- **Standing over a man lying flat**, a player is not moved off him (see above), and his legs can be in the other's
  body. The audit's own measure (spheres round each pelvis, chest and head) does not see legs either.
- **The steps** of a raider held round the middle are made by the body (the trailing foot on an arc), not a captured
  clip.

### The thigh hold's grip

**Asked:** fix the thigh hold's grip. In AI matches a thigh holder's hands came up to 0.30 m off the thigh for a few
frames (0.22 m the round before), and in the scripted scenarios the thigh and waist dives' first grips read looser.

**The scripted first grips** were the hands still closing on the hold's first frame: in `tackle_check thigh`, 0.12 m
on the first frame and 0.055 m on the next, as close as ever after that.

**In matches it was two things,** each measured frame by frame on the worst holds (seeds 2, 3 and 5).

- **The arms.** A hand reaching for a hold was turned onto it from the hand-made pose by the shortest turn
  (`RiggedBody._ik_two`). The hand-made pose does not know where the hold is: in a hold, the forearm the reach wanted
  pointed 90-110 degrees off the pose's, and as a raider hopped toward his thigh holder (the thigh 0.13 m from the
  holder's shoulder) 145-161 degrees. Near opposite, the shortest turn is undecided, so the forearm's twist flipped
  from one frame to the next, and with the arm folded right up the elbow flipped from one side to the other. The last
  pose stage held turns of 80-150 degrees in a frame back to 40 (`_limit_turns`), and the hands trailed the thigh by
  up to 0.4 m for four or five frames. The same twist left every hold's hands a few centimetres off the part they
  held all through (median 0.06 m): the hand's grip point was turned away from it.
  - A hand reaching for a hold now starts each frame from the arm as it was drawn the frame before
    (`RiggedBody._reach_hands`), and the reach turns it from there: a frame's change, never a half turn. The hand
    keeps the pose's bend at the wrist, and the fingers their grip.
  - Folded right up, or straight, an elbow says nothing of which way it bends: it bends the way it did
    (`_ik_two`, `BEND_MIN`).
  - Where the hand goes is unchanged: while a hold closes (`CLOSE_IN`, a helper's 0.2 s) or lets go (`LET_GO`), the
    hand is put between where the pose has it and the hold, by how far the hold has closed. Only the arm starts from
    where it was drawn. Tried with the hand put between where it was drawn and the hold, a helper's hands closed in
    half his time, and a hand letting go stayed on the hold all through the let-go, then went back in a frame or two
    (at 8-14 m/s, in `tackle_check`).
- **The holder's body.** A thigh diver who lands with his shoulders right on the thigh is backed off to his place, an
  arm's length off it (`Grapple.update`), coming round to it no quicker than `HOLD_ACCEL`. Being kept clear of the
  holder on the other thigh (`HOLDER_GAP`) was added to his speed as well, and carried into the next frames; he went on
  past his place, out of his arms' reach by 0.3 m, before `HOLD_ACCEL` had taken it off. Being kept clear now moves him
  without becoming speed he carries.

**In numbers.** `raid_audit`, eight matches (seeds 1-8). The arms alone change nothing but the drawn arms: the same
matches, every place, state and event the same, so they compare frame for frame. Keeping the push out of the holder's
speed moves holders a little differently, and the matches play out differently from there.

| Eight AI matches on Pro | Before | The arms (the same matches) | Now (the arms and the holder's speed) |
|---|---|---|---|
| Grip, hands from the part held: median / 90th / 99th percentile | 0.06 / 0.10 / 0.12 m | 0.02 / 0.04 / 0.10 m | 0.02 / 0.03 / 0.10 m |
| Worst grip | 0.30 m, a thigh hold | 0.24 m, a thigh hold | 0.15 m, a thigh hold as a dubki ducks it out of reach |
| Holds valid / invalid | 172 / 0 | 172 / 0 | 191 / 0 |
| Holders' speed changes over 40 m/s² (share of their frames) | 0.64% | 0.64% | 0.57% |
| Bodies inside one another: raider and holder; two holders (per holder's frame) | 0.133; 0.039 | 0.133; 0.039 | 0.131; 0.040 |
| Bone turns the last pose stage holds back | 0.33% | 0.33% | 0.33% |

In the scripted scenarios the hands are on the part all through once they have closed: the median grip is 0.02 m in
every hold, against 0.05-0.07 m (`catch` 0.061 → 0.019, `thigh` 0.063 → 0.022, `join` 0.073 → 0.021), and a thigh
helper's, once his hold has closed, 0.021-0.022 m against 0.053-0.057 m. A thigh helper's hands close over his hold's
0.2 s and reach the thigh as it closes: under 0.1 m after 0.17 s, where before they were under it after 0.13 s but
stayed 0.05-0.06 m off it. What is left of the 90th percentile in the holds with a helper (`join` 0.118 → 0.110,
`chain` 0.083 → 0.062, `crowd` 0.087 → 0.060) is those closing frames, and a thigh helper's last 0.2 s before he lets
go, as the raider lands: the thigh drops out of his reach, up to 0.13 m from his hands, as it did before (`raid_audit`
leaves the fall out). A waist hold reads 0.02 m now against 0.00: its measure counts from the middle's surface (0.12 m
round its centre line), and the hands now sit on their marks just outside it, where before they reached inside it. All
17 scenarios are as expected; the holds with more than one holder (`chain`, `crowd`, `join`) play a frame or two
differently, as their holders are no longer carried along by being kept clear.

The worst grips left are all a hold the body cannot reach: a dubki ducking a held thigh or the arms round a middle
out of reach (as it is meant to; a dubki slips arms round the middle), and an ankle holder at full stretch, the ankle
0.70-0.74 m from his shoulders against an arm of 0.57-0.59 m, his hands 0.12 m short of it.

**Checks.**

- `test_runner` at a fixed 30 fps, as CI runs it: all 185 checks pass (the fingers' grip among them).
- `tackle_check`: all 17 scenarios as expected. `compile_check`: no broken scripts.
- The audit run again in a separate process, traced: the same four matches entry for entry (43,274 entries: every
  player's place, state and timer in every frame, and every event and score change). Run on the code as it is now
  against the run before the hands' closing and letting go were put back as they were, the same 43,274 entries:
  where the hands go changes nothing in play.
- `ai_bench`, sixteen matches on Pro (random seeds): every match's points add up, and every event check is clean (no
  grab back in the frame of a touch, no takedown within 0.6 s of a new hold, no escape the move could not make, no two
  holds on one part). 61% of 491 raids succeed, 21% are tackled, 11% go out of bounds and 7% are empty; last night's
  runs had 64% and 63% succeeding and 21% and 18% tackled. A run before the hands' closing and letting go were put
  back (the same play, above) had 60% of 486 succeeding and 23% tackled: the spread between runs.

**Still not right:**

- **An ankle holder at full stretch** has his hands 0.12 m short of the ankle (above). Kept closer, the struggle
  itself (where the held ankle can be dragged to) would change.
- **A thigh helper as the raider lands** keeps hold at full stretch while the thigh drops away from him, up to 0.13 m
  off it, for the last 0.2 s before he lets go (`join`, `chain`, `crowd`; as before).
- **Letting go to get up from the floor,** an ankle holder's hands swing back to the get-up pose over the let-go's
  0.15 s however far that is: up to 1.3 m in five frames in `slip` (17 m/s at the fastest), as before.
- **A defender getting up outside the sideline's margin** (a dive that carried him past it) is put back inside it in
  the frame he stands: 0.3 m in a frame, once in these eight matches. The clamp has done this all along.

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
- **slip**: held at the ankle and round the middle (the helper comes in from behind, the back kept for him
  whichever ankle the diver catches), a dubki slips only the arms round him: still held, no "Broke free!", taken
  down.
- **duck**: held only at the ankle, a dubki slips nothing.
- **drag**: the `catch` hold with the raider driving for the line as hard as he can, as the AI does. He drags
  the holder a little at a time and is brought down.
- **stopped**: a lion jump out of the ankle hold that does not slip it. The hold stops him leaving the floor;
  he is held still, and brought down.
- **sidestep**: held only at the ankle, a sidestep slips nothing. He twists on his free leg where the hold has
  him, and is brought down.

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
- however he is held, how fast a foot of his on the floor moves along it (a foot held aside), and how often one
  leaves it (`feet_slide`, `foot_lifts`): carried along with his feet down reads high, stepping or hopping near 0;
- each holder's grip all through, and while the raider is still on his feet (`grip_each`, "held");
- after a takedown, when each holder let go, how he got up and when he was up (`recovery`);
- a lion jump out of the hold (`escape_timing`): when the hold lets go after the jump is called for, the free
  foot's height then, when both feet leave the floor, how much his speed changes in the air, how far out the
  holder's hands reach after the leg, and how long he lies before getting up;
- a dubki or a sidestep with the ankle held (`dubki_held`): when the arms round him slip, whether he stays on
  the free leg, the held foot from its hold, how far his middle drops, how much of it the free foot is planted,
  how far his body travels, and what the slipped holder does;
- which holds the escapes slipped (`slipped`).

A scenario fails if the events are not what it must produce. The motion numbers are measured, not checked:
they are for comparing a change, alongside looking at a recording.

`tests/raid_audit` plays whole AI-v-AI matches instead of scripted raids:

```sh
godot --headless --path . --fixed-fps 30 res://tests/raid_audit.tscn -- [MATCHES] [FIRST SEED] [--json out.json] \
    [--digest FILE] [--again] [--trace]
```

Four pairings take turns (MUM v DEL, PAT v BLR, IND v IRN, KOL v JAI), on Pro, with seeds counting up from the
first. It measures every frame of every raid, for every player who was on the mat when the raid began:

- **contacts**: a hold given is valid if a hand is on the part it holds (within 0.3 m) once the hands have had
  0.25 s to close. The dive's own contact gap is recorded too;
- **grip**: each holder's hands from the part he holds, every frame after that;
- **held foot**: a foot held at the ankle, from where the hold has it;
- **corrections**: a body moving faster than 9 m/s in a frame (past any run, dive or jump), and a body's middle
  moving more than 0.2 m further than the body itself;
- **speed changes**: how sharply each body's speed over the floor changes, and the frames past 40 m/s²;
- **joint pops**: a bone of the drawn body turning more than 40° in a 30th of a second, and how often the last
  pose stage (`RiggedBody._limit_turns`) held one back;
- **conflicting states**, counted in episodes:
  - held with no one holding him, or holds on him in a state that cannot be held;
  - a holder not holding;
  - hands left on a body after letting go, or a foot held by no one;
  - lying on the floor while moving;
  - standing on one leg with no leg held;
- **events**:
  - a hold given twice, or on a part already held;
  - a release or an escape from a hold that was not there;
  - a hold after the takedown;
  - two takedowns or raid ends in one raid;
  - points that do not add up;
- **tackle phases**:
  - winding up, the dive, the hold, the fall to the floor, on the floor, getting up;
  - each holder letting go and getting up after a takedown;
  - a lion jump's gather;
- **bodies inside one another**: three spheres for each body (pelvis, chest, head), and the deepest overlap of
  any two bodies' spheres, by pair (the raider and his holder, two holders, the raider and another defender,
  anyone else);
- **softlocks**: a timed state running 1.5 s past its length, a hold over 20 s, a raid over 75 s, a match that
  does not finish.

It prints:
- each measure's distribution (median, 90th and 99th percentile, worst);
- the frames over each limit, by state;
- the five worst cases, with where they happened (match, raid, seconds in, player, state).

The options:
- `--json` writes all of it to a file.
- `--digest FILE` checks the run against an earlier one in another process, event for event. The first run
  writes FILE.
- `--trace` adds every player's place (to a micrometre) and state, every frame, to what is compared.
- `--again` plays the first match a second time in the same process, which must come out the same.

Each match is begun once the engine's frame steps are steady (its first half-dozen frames are not a 30th of a
second, even at a fixed frame rate). `tests/match_record` plays a match for recording the same way, and with
`trace=FILE` writes the same per-frame trace, so a recording can be checked against the audit's own run of that
seed, frame for frame:

```sh
godot --headless --path . --fixed-fps 30 res://tests/raid_audit.tscn -- 1 1 --trace --digest /tmp/audit.json
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 --write-movie m.avi \
    res://tests/match_record.tscn -- 600 seed=1 home=MUM away=DEL trace=/tmp/rec.json
```

The digest's "frame" entries, up to its "final" entry, are the audited match's frames in order; the recording's
trace is the same list.
