# Tackles and holds

Milestones B to E of the realism plan (see `MOTION_REALISM.md` for milestone A, movement): making a hold
real contact between two bodies, then building every tackle, the team's defence and the match's events on
it. Each milestone is measured before and after with `tests/tackle_check.tscn` (see "Measuring").

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
| Hand to leg when the hold is given ("contact gap") | 0.66-0.74 m | 0.05-0.12 m |
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

**Gameplay.** `tests/ai_bench.tscn -- 4 1`, AI matches at normal difficulty: being measured.

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

## Measuring

```sh
godot --headless --path . --fixed-fps 30 res://tests/tackle_check.tscn -- [miss catch escape whiff] [--json out.json] [--log]
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --write-movie catch.avi \
    --fixed-fps 30 res://tests/tackle_check.tscn -- view catch
```

The scenarios: **miss** (an ankle dive that reaches the leg but whose grip fails), **catch** (an ankle hold
that brings the raider down), **escape** (a lion jump out of an ankle hold), **whiff** (a dive from 3 m:
no hand reaches him, so no hold may be given, even with the hold chance forced). Each prints the contact
gap, the grip error while holding, holder jumps, how close the two bodies' middles came, each player's
states over time, the HUD messages and the gameplay events, and fails if the events are not what the
scenario must produce (one hold, a takedown only for a tackle, nothing held after a miss).
