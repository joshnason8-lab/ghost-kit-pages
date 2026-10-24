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

The owner sent two full 9-minute turns filmed from behind a pole (a day match, blue chasing yellow, from a steady
high camera; a night match, purple chasing white, handheld), and they were watched a second at a time (the footage is
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
→ 13.4 a minute, a dive every 21 → 18 s.

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
