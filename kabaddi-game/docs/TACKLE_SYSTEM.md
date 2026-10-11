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

## Measuring

```sh
godot --headless --path . --fixed-fps 30 res://tests/tackle_check.tscn -- [SCENARIO ...] [--json out.json] [--log]
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --write-movie catch.avi \
    --fixed-fps 30 res://tests/tackle_check.tscn -- view catch
```

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

Each scenario prints:

- the contact gap and the first frame's grip;
- the grip error of every holder while holding;
- holder jumps;
- how close the bodies' middles come, to the raider's and to each other;
- each player's states over time;
- the HUD messages and the gameplay events.

A scenario fails if the events are not what it must produce.
