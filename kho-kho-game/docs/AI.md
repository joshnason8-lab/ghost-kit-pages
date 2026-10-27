# How the AI plays, and the numbers it uses

The AI plays both sides in `game/match.gd`. It plays the game the way it is played: the chase passed along the lane by
kho after kho, dives at the lines, turns at the poles; defenders keeping behind the active chaser, away from the
seated chasers who could rise at them, and slipping past him at the last moment.

## The real matches it is measured against

| | Real | Source |
|---|---|---|
| Senior women's final, January 2026 | Maharashtra 23, Odisha 22, over four 9-minute turns | uniindia.com |
| Senior men's final, January 2026 | Railways 26, Maharashtra 21 | uniindia.com |
| 2025 world championship, men's final | India 54, Nepal 36, over four 7-minute turns, 2 points an out | Wikipedia; Olympics.com |
| 2025 world championship, women's final | India 78, Nepal 40 | Olympics.com |
| Women's quarter-final | India 109, Bangladesh 16 | ianslive.in |

Close classic finals put out about 23-26 defenders in 36 minutes of chasing: **about 1.3 a minute**. The fast
final, at 2 points an out with some dream-run points, came to about 1.6 a minute. A mismatch runs far higher: India's
109 against Bangladesh is about 3.9 a minute.

## Watched: two real matches (October 2026)

The owner sent two full 9-minute turns filmed from behind a pole, both from a fixed camera (a day match, blue chasing
yellow, from higher up; a night match, purple chasing white, from behind the fence, the steadier of the two: measured
shake 0.8 px a fifth of a second against 1.0, with a few small pans), and they were watched a second at a time (the footage is
not kept). What they show, the same in both:

- **A defender out of danger stands still and watches.** Most of the time only one defender is under threat; the
  others stand, often 4-8 m off the lane on the side away from the active chaser or at the far end, facing the play,
  and move only when the chase comes their way by a kho. The AI's defenders did the opposite: they jogged from spot
  to spot at 3.4 m/s or more, with a wander "so that he keeps moving".
- **The defender under threat plays tight round the pole and the end chasers.** Dodging a metre or two from the
  pole, with the pole or a seated chaser between him and the active chaser, slipping round as the chaser comes round;
  the chasers answer with pole turns and pole dives there (one at 0:32 of the day match, missed). The AI does this
  already (reach_time round the pole, the chain bias, pole dives).
- **Fresh defenders go straight in near the pole**; those put out stand behind the end line.
- Khos could not be counted reliably at that size of picture, so the kho rate is not measured from them.

What changed (0.8):

- **Settling.** Out of danger (the chase over 3.2 s away, `SAFE_S`), a defender keeps his spot unless another is
  clearly safer (`STAY_BONUS`), stands once within 1 m of it (`SETTLE_M`), walks rather than jogs to move, and faces
  the active chaser, his head following him; the wander is only for a defender in danger. Out-of-danger time spent
  standing: 52% → 76% (classic), 46% → 73% (fast); speed then 1.5 → 0.8 m/s. `tests/test_runner.gd`'s motion audit
  checks it stays over 60%.
- **The chaser and a foul.** While a foul is being whistled none of his touches counts, so he now goes straight for
  the kho (any seated chaser ahead) or the pole that puts it right, instead of chasing; and the foul's bar at the foot
  of the screen no longer stays up when a foul outlasts its fade.

Outs a minute, before → after (6 classic matches of 3-minute turns; 4 fast): classic 1.60-1.78 → 1.38-1.65 (real
close finals 1.3-1.6); fast 1.83 → 2.08 (real fast final about 1.6; four matches vary by about that much). Khos 12.8
→ 13.4 a minute, a dive every 21 → 18 s. Ten matches later gave 1.32 classic and 1.68 fast.

### Watched again, end to end (25 October 2026)

For 0.8 about a quarter of the two matches was looked at. Both were then watched in full, all 18 minutes a second
at a time, to see whether the play changes late in a turn. It does not change with the clock. It changes with how
many of the batch are left:

- **Three in:** one plays the pole and the chain while the other two wait wide, standing still 4-6 m off the lane,
  most often one on each side (in the night match one waited ~50 s in one spot).
- **One left:** he lives on the chain and round the poles, crossing between the seated chasers, and never goes wide.
  The day match's last man did this for 48 s (7:28-8:16) until a pole dive got him.
- **At the pole:** a defender holds it with a hand and swings round as the chaser comes; the chasers answer by
  passing the kho to the chaser nearest the pole, so the attack comes from the far side.
- **Outs that could be seen:** 3 at a side line (a chaser running at a wide defender from the inside) and 2 at a
  pole. Many outs at the far end were out of shot, so this is not a count of where outs happen.
- A new batch comes on together at the pole and is attacked straight away. A chaser who dives stays down a moment.

`tests/match_sim.gd` now measures these (10 matches of 3-minute turns each, classic / fast):

| | AI (0.8) | The real matches |
|---|---|---|
| Last defender's time on the chain or by a pole | 83% / 84% | nearly all |
| Three in: the two waiting on opposite sides | 50% / 48% | most of the time |
| Outs at a pole / at a side line / elsewhere | 40% / 1% / 59% | of those seen: 2 / 3 / 0 |
| Outs a minute | 1.32 / 1.68 | 1.3-1.6 / about 1.6 |

Three changes were tried against this and none was kept:

- **Cross the lane to wait on the other side** from a waiting team-mate (a cost for sharing a side, the mirror spot
  as a choice): 50 → 59-62% on opposite sides, but the crossings cut standing out of danger (76 → 71%) and put the
  fast game's outs up to 1.8-2.0 a minute.
- **Come at a wide defender from the lane's side** (the chaser's line 0.35 m inside him for every metre between
  them): side-line outs stayed at 1%.
- **A fresh batch spreads to both sides as it comes on:** no change; once in, defenders choose their spots afresh.

So the AI stays as in 0.8. Its outs a minute, standing out of danger and play with one man left match the real
games. Its waiting defenders still pick their side of the lane at random, and chasers do not drive defenders to the
side line. Both are left for a change that moves them without costing the rest.

## The pole turn (0.10, from the owner's video)

The owner sent a 33-second clip of chasers turning at the pole. Watched at 10 frames a second, each turn goes: the
chaser runs at the pole, takes hold of it with both hands at chest height, leans out from it, steps quickly round it
close in (about half a metre), and lets go running back down the other side of the lane. Half a turn takes about
half a second, and he comes out without having stopped. Before 0.10 the game's chaser braked and turned about
near the pole (about two seconds), with only the "turn" clip played.

Now (`match.gd` `_pole_turn`, `athlete.gd` `pole_swing`): when his direction turns about at a pole and he is within
1.6 m of it with at least 70 degrees still to turn, he takes hold where he is and swings round the far side of the
pole on to the side the play needs (the AI's plan, your stick, or the side he is on). He is drawn in to a 0.55 m
circle over a quarter of a second, and his speed rises evenly from his speed in to 5% more (at least 4.6 m/s), so it
never jumps. His legs run, his hands hold the pole (`ModelBody.Grip` turns both arms to it) and he leans out. In AI
matches it happens about 3 times a minute.

It made chasers much better (classic outs 1.5 to 2.0 a minute, because turning at the pole no longer cost two
seconds), so the defenders' last-moment swerve was raised to match (`SWERVE_TOUCH` 0.72 to 0.78). Ten matches each:
classic 1.51 outs a minute (real 1.3-1.6), fast 1.82 (real about 1.6; it was 1.7-2.1 before this round).

## Tags that slip, and difficulty (0.10)

The owner saw chasers run right past defenders, on the hardest difficulty too. By design most touches slip off at
the last moment (the swerve above), which holds the AI's outs to real rates, and a chaser who misses may not turn
back (the direction rule), so he runs on past. But nothing showed the attempt, and against your defender the slip
barely changed with difficulty (64% on Beginner, 54% on International). Now:

- Every touch the chaser gets to is seen: his arm goes out for it (the reach), landed or slipped.
- Against your defender, as you steer him, the slip is set by the difficulty (`USER_SLIP`): Beginner 70%, Club 55%,
  State 40%, International 25%. Six matches with the playtest's steering: your side lost 5-8 defenders a match on
  Beginner and 11-17 on International.

## What `tests/match_sim.gd` measures

`godot --headless --path . --fixed-fps 30 res://tests/match_sim.tscn -- 2 classic 180` plays AI-v-AI matches and
prints outs a minute, how each out came, khos, dives and fouls. Between equal sides (state sides, 3-minute turns),
21 October 2026:

| | Classic | Fast (7-minute turns) |
|---|---|---|
| Outs a minute | 1.5 (0.75-2.3 a match) | 1.75 |
| Of them: touches / dives / pole dives / limits | ~66% / ~7% / ~27% / 0 | ~58% / ~9% / ~32% / 0 |
| Khos a minute | 13.3 | 11.8 |
| A dive every | 22 s | 16 s |
| Fouls a minute (AI chasers) | 0.56 | 0.77 |
| Dream runs | — | about one a match |

Measured again for 0.2 (21 October 2026, after the playtest's fixes). Two changes moved the numbers:

- **The chain.** Defenders play close to the lane, beside a seated chaser who faces away (`_chain_bias`), as real
  defenders do, so the chasers give many more khos (5 a minute before, 13 now).
- **The brake at the line.** A defender turning back from a side line spent his grip on turning and ran over it: a
  quarter of the AI's outs were out of limits. He now brakes his speed toward a line at his full braking as soon as
  he needs it all to stop inside (`_brake_at_line`); the same brake keeps your own defender in with the assist on.

The classic game is now at the real rate (1.3-1.6 a minute). `tests/match_sim.gd ... user` and `... bot` play the
home side as yours (your thumb off the stick, or steered as the phone playtest's tester steers), and print your
side's outs by kind (docs/PLAYTEST.md).

## The numbers

**Speed.** Flat out, a player's top speed is 5.7 + 2.3 × (speed rating / 100) m/s: 7.7 m/s at 87, 8.0 at 100. Elite
kho kho sprints are 7-8 m/s over a few strides. A tiring defender loses up to 18% of it.
- He gathers speed at 9 m/s² and sheds it at 13 m/s² (Athlete.ACCEL, DECEL).
- A defender turns sharper than a chaser: his acceleration is ×1.15 to ×1.6 by his turn rating, against the
  chaser's ×0.9.
- His run (the owner's Mixamo running clip, 3.5 m/s at its own rate) plays at his speed over that, up to 1.9 times,
  so his feet keep near pace with the ground; under 2.6 m/s he walks (`ModelBody.rate_for`).

**The chaser.** Every 0.1-0.32 s (quicker with a higher read rating) he weighs three plans and takes the quickest:
- **Chase** the defender where he is (only if he may: on his side and ahead of him).
- **Kho** the seated chaser whose back is to him, ahead of him, nearest the defender's side.
- **Round the pole**, when what he wants is behind him.

How he carries them out:
- He slows into a kho so as not to pass the cross lane.
- He dives, 8% of the time each time he thinks, when a defender is 1.1 m to 1.3 + 0.6 × reach m away and near a line
  or not escaping. After a dive he must wait 3 s for another.
- In the free zone he pole dives at a defender within 2.4 m of the pole.
- A late kho is given now and then: 5% of the chances at Beginner, 1.2% at International. A seated chaser rises
  early about as rarely.

**The defender.** Every 0.16-0.42 s (by read rating) he picks the safest spot within 3.2 m, on rings of 1.6 and
3.2 m.
- **Safety** is how soon the chase could reach the spot, `reach_time`:
  - the active chaser straight there, if his direction lets him;
  - round the pole if it does not;
  - or a kho to a seated chaser facing that side, plus 0.45 s for the kho and the rise.
- **Less** for being within 1.4 m of a line, or near a team-mate.
- **Plus** a little wander when he is in danger, so he is hard to pin.
- **Out of danger** (the chase over 3.2 s away) he keeps his spot unless another is clearly safer, stands, and faces
  the active chaser (Watched, above).
- **Pace:** he walks (1.6 m/s) to a new spot when safe, jogs at 3.4 m/s once the threat is within 4.2 s, rising to
  flat out as it comes.

The defender's reactions:
- **The juke.** When the active chaser closes inside 2.4 m, the defender waits for him to commit (0.06-0.4 s, his read
  against the chaser's), then slips behind him, back past his direction, where he cannot turn.
- **The swerve.** As the hand comes, the defender twists away from it with a chance of 0.72 + (turn - reach) / 150 for
  a touch, 0.42 + ... for a dive, between 0.15 and 0.85. This is the one number that calibrates the out rate.
- **Reading a dive:** 0.12-0.32 s to react, then a hard step aside.
- **Pulling up:** he stops before the lines with room to stop, v² / 2a.

**Difficulty** changes the other side's ratings: Beginner −16, Club −7, State 0, International +5. Every rating feeds
speed, turning, reactions and reads.

**Captains.** The AI captain who wins the toss chooses to defend first two times in three: to know the target. Ahead
by the follow-on lead, it always makes the other side follow on. It calls the power play as the second batch comes on
(sometimes the third).
