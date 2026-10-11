# How real raids play: India v Pakistan, Asian Games

Four highlight clips (about 45 s of live play), used with permission, measured with `tools/mocap`: the
players are tracked, put on the court in metres, and the moments that decide each raid (touch attempts,
dives, blocks, help arriving) were marked frame by frame and measured from the tracking.
`tools/mocap/footage/` holds the marked events and every number below; `tests/ai_bench.tscn` measures
the game's AI the same way.

| Clip | Raid | Outcome |
|---|---|---|
| 1 | India's raider against seven Pakistan defenders | walks the baulk area, crouches 2 m from the chain, one reaching hand touch, sprints home |
| 2 | India's raider (#12) against three (a linked pair and #3) | low and busy, an attempt every second or so; steps in and is held at the thigh, #3 piles on |
| 3 | Pakistan's raider against India's chain | toe kick, then hand reaches every 2-3 s; steps in deep, blocked at the waist, swarmed |
| 4 | India's raider (#12) against two linked pairs | long probe between the pairs, hops over a dive; caught at the ankle by the far pair |

## What the raiders did

- **They take their time.** The first touch attempt came 0.7-8.8 s after they were in, and a tackled
  raider had worked the cover for 9-11 s first, making 3-4 attempts.
- **Attempts come in bursts**, 0.4-2.9 s apart (median 1.4 s), about one every 2.5-4 s overall for the
  busy raiders.
- **They stay about 2.3 m from the nearest defender** while working (median of each raid 2.3-2.5 m), and
  go for a touch **from about 2 m** (1.6-3.1 m): the touch is a lunge, a step that carries the hand or
  foot in, not a reach from where they stand.
- **Speeds:** 1.2-2.0 m/s while probing, side-steps up to 2.5-4.9 m/s, 4.1-5.6 m/s at full escape
  (best half second).
- **Depth:** 3.6-4.8 m in, around the baulk line (3.75 m) and up to the bonus line.

## What the defenders did

- **The line stands 4.4-4.9 m from the midline**, about a metre behind the baulk line, and spreads
  6-9.4 m across (5.7 m even with three defenders).
- **They link hands in pairs** and shuffle slowly while the raider works (median 0.5-1.2 m/s).
- **They answer a reach with a reach** within about 0.25 s, and give ground when he comes close.
- **They go for him as he steps in:** dives and blocks started 1.4-3.2 m from the raider (median about
  1.9 m), at the same moment as his step, not after it. Ankle dive, thigh hold and waist block, one each.
- **Help arrives 0.65-1.15 s after the first hold**, the run in included, and two or three more join.

## The game against the footage

`godot --headless --path . --fixed-fps 30 res://tests/ai_bench.tscn -- 4 1` (four AI matches, normal
difficulty) prints this comparison. Medians:

| | Footage | Game before | Game now |
|---|---|---|---|
| Defensive line from the midline | 4.4-4.9 m | 3.7 m | 4.6 m |
| Line's spread across | 5.7-9.4 m | 7.5 m | 8.3 m |
| Raider's gap to the nearest defender | 1.8-2.5 m | 1.4 m | 1.9 m |
| Nearest defender when he goes for a touch | 2.0 m | 1.4 m | 1.7 m |
| Raider's speed working the cover | 1.2-2.0 m/s | 1.8 m/s | 1.8 m/s |
| Raider's top speed (best half second) | 4.1-5.6 m/s | 6.8 m/s* | 5.0 m/s |
| First attempt after coming in | 0.7-8.8 s | 4.3 s | 5.7 s |
| Between attempts | 1.4 s | 1.9 s | 1.2 s |
| A defender goes for him from | 1.4-3.2 m | 1.4 m | 1.6 m |
| First hold after coming in | 9-11 s | 2.1 s | 6.3 s |
| Help after the first hold | 0.65-1.15 s | 0.27 s | 0.77 s |

\* measured from the top instantaneous speed then; the bench now takes the best half second, as the
footage does.

Outcomes at normal difficulty: raids succeed 69% of the time (62% before; the difference is within the
noise of a few matches), 17% end in a tackle (18%) and 9% are empty (10%). More raids now score two or
more points (23%, was 8%): with the line deeper, more dives miss and more holds are broken.

## What changed in the AI (game/match.gd)

- **Defensive line deeper and wider** (`formation_spot`): 4.35-4.7 m from the midline instead of
  3.35-3.85, and three or four defenders spread across the court instead of bunching in the middle.
- **The raider works further out** (`_ai_probe`): he sways about 2.4 m in front of the man he is testing,
  closing to 1.9 m as the raid wears on (was 2.0 to 1.6), and keeps 1.8 m clear of the rest.
- **Touches are lunges** (`LUNGE`): an AI raider goes for the touch from up to 0.45 m further out and
  steps in as he reaches. Defenders who sense it pull back from that further distance too.
- **Defenders go from further** (`_ai_defender`): they consider a tackle from 1.9-2.1 m (was 1.6-1.8),
  the range the dives in the footage started from.
- **A lunge goes for one man** and is easier to grab back: the step in puts the raider in the defender's
  grasp, as it did in the footage.
- **Help comes from further** (`hold_age`): team-mates pile on from up to 4.2 m away (was 3.2 m), so
  from the deeper line help takes about as long as it did in the footage. The first hold stops the raider
  dead and he only gets going again after about a second, so he can't simply drag one man home.
- **Fewer cheap toe taps**: the raider pokes a foot at a defender in range half as often. Hand touches
  were 8 of the 11 attempts in the footage.
- `raid_crouch_hunt`, a raider's low standoff taken from clip 3, joins the raiders' stances.

## Limits

Four clips is a small sample, and highlights favour tackles (three of four here). Distances are good to
about half a metre: the high side-on camera squashes depth, and players' feet hide each other in a
crowd. Each clip begins with the raid already under way, so times from "coming in" are from the start of
the clip.
