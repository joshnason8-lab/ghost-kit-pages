# The rules of kho kho, as Khamba Dash plays them

Khamba Dash plays two rule books:

- **Classic**: the national federation's game, as played at the senior national championships in India.
- **Fast**: the seven-a-side game of the 2025 world championship (New Delhi, 13-19 January 2025) and of the
  franchise league.

This page lists every rule the game implements. For each it gives where the rule comes from, how the game
does it (`game/rules.gd` is the pure rules module the match asks), and anything simplified, with the reason.
`tests/test_runner.gd` (`_rules`) checks each rule headless on every CI run.

## How the rules were researched, and what to check

The federation's rule book is published as a PDF on the Khelo India site
(https://web.kheloindia.gov.in/download/file/fid/4396) and copied on Scribd
(https://www.scribd.com/document/432565405/KKFI-Rule-Book; a 2026 48-page edition at
https://www.scribd.com/document/1032760331/Kho-Kho-Rule-Book-48-Pages-2026). The franchise league's Season 1
rule book is at https://www.ultimatekhokho.com/static-assets/pdf/rules-season1.pdf.

The build environment's network proxy refused every one of those sites. So the rules below come from search
excerpts of the cited pages, not from reading a rule book end to end. The only rule number confirmed is **Rule 1**
("the play field is marked as shown in Part 1"). Rule numbers are therefore not given. Where sources disagree,
this page says so (**conflict**) and records the reading the game uses. **The owner should check the conflicts
against a printed rule book** before the release.

## The field

| | Classic | Fast | Sources |
|---|---|---|---|
| Field | 27 m × 16 m | 22 m × 16 m | Wikipedia (Kho kho; Ultimate Kho Kho), khokhochampions.com/kho-kho-court-measurements, the league's rule book |
| Central lane | 30 cm wide, pole to pole | 30 cm | all sources |
| Between the poles | 24 m | 19 m (22 m less two 1.5 m free zones) | Wikipedia; derived for the fast field |
| Cross lanes | 8, each 16 m × 35 cm | 6, each 16 m × 40 cm | khokhochampions.com; the league's rule book (40 cm) |
| Cross lane spacing | first 2.55 m from each pole, then 2.30 m apart | the same | Wikipedia (Kho kho) |
| Free zones | 1.5 m × 16 m behind each pole | 1.5 m | Wikipedia; the league's rule book |
| Lobby | 1.5 m round the field | 2 m (a 26 × 20 m ground) | khokhonms.org; the league's rule book; the international federation's notice of 7 Jan 2025 (26 × 20 m) |
| Poles | 120-125 cm high, 9-10 cm thick, smooth wood | the same | khokhonms.org; khokhochampions.com (posts) |

How the game does it: `KhoRules.field(fmt)` returns the measurements and each square's position along the lane,
and `game/arena.gd` marks out exactly that field. Tests check 27/22 × 16 m, 8/6 squares, 30 cm, 35/40 cm,
2.55 m and 2.30 m, 1.5 m free zones, 24 m between the poles, and that the fast field's six cross lanes fit its
19 m.

- **Conflict:** some sources give a 29 × 16 m field with 23.5 m between the poles and 2.75 m free zones
  (khokho.net, gameonfield.in). The two layouts add up the same way (23.5 + 2 × 2.75 = 29). The game uses
  27 m / 24 m / 1.5 m, which most sources give and whose spacings add up exactly
  (2 × 2.55 + 7 × 2.30 + 8 × 0.35 = 24.0).
- **Derived:** no source gave the number of squares on the fast field. It has seven attackers (one active, so six
  seated). Six cross lanes at the classic spacing fill its 19 m exactly (2 × 2.55 + 5 × 2.30 + 6 × 0.40 = 19.0), so
  the game uses that.

## The sides

- **Classic:** 12 in a squad, 9 on the field. The chasers are 8 seated in the squares, each facing the opposite
  side line from the one beside him, plus 1 active chaser. The defenders come on in batches of 3.
  (Olympics.com, "Kho kho: history, rules, how to play"; khokho.net; LatestLY.)
- **Fast:** 15 in a squad, 7 attackers on the field (6 seated, 1 active). Up to 12 defend, in batches of 3.
  (Wikipedia, Ultimate Kho Kho; the international federation's notice reported by Hindusthan Samachar, 7 Jan 2025.)
- **The game:** each side brings 9 players (classic) or 12 (fast). The best chasers chase: the active chaser plus 8
  or 6 in the squares. The defenders go on in batches of 3, best first, and when every batch has been out the order
  starts again (`KhoRules.batch`).
- **Simplified:** there are no substitutions within a match. The squad's best 9 or 12 play.

## The kho

- **Rule:** the active chaser passes the chase by touching a seated chaser on the back with his palm and calling
  "kho" loudly. Calling before the touch, or touching without calling, is a foul. The seated chaser must not rise
  before the kho. A seated chaser offering an arm or a foot for the kho is acting illegally. The kho must be given
  before the active chaser has passed that chaser's cross lane, or it is a late kho.
  (Khelo India rule text; Wikipedia; bharatiyakhel.in; sportsmatik.com; LatestLY.)
- **The game:** `KhoRules.kho_check` allows a kho only from behind the seated chaser (on the side his back is to),
  within reach, and not past the far edge of his cross lane (15 cm of grace for the umpire's eye). Your KHO button
  touches and calls in one press, so the touch-and-call foul cannot happen. The kho takes a moment: the palm, the
  call, then the seated chaser rises and is the active chaser. The giver takes his square, facing the same way.
- **Late kho:** the umpire whistles the foul and the kho does not stand. The giver has passed the seated chaser and
  cannot turn back, which is the real price of it. The AI's chasers give a late kho now and then (rarer at higher
  difficulty), so the call is seen.
- **Early rise:** the AI's seated chasers now and then rise before the kho. The umpire whistles, and the chaser goes
  back down.

## The active chaser's direction, the lane and the free zones

- **Rule:** once he has set off toward one pole the active chaser must keep going that way. He may not turn back.
  He may turn his shoulder line only so far. He may not cross the central lane except through a free zone, where
  he may go round the pole and come out either way on either side.
  (Wikipedia, Kho kho and its glossary; medium.com/sporcial; sportsmatik.com.)
- **The game:** `KhoRules.step_chase`, every frame of the active chaser's run:
  - He takes his direction with his first run from where he rose.
  - Running backwards along the lane faster than 0.45 m/s is turning back, a foul. Moving across the field (along
    his shoulder line) is not.
  - Crossing the lane between the poles is a foul.
  - In a free zone his direction is free and his side can change. He comes out toward the middle.
- **Fouls are whistled until put right**, as the umpires do (continuous short whistles, an arm pointing the way):
  - A turning-back foul is put right by running 0.8 m his proper way.
  - A lane foul is put right by getting back to his side.
  - A defender touched while a foul is on is not out (`touch_counts`). Tests check each of these.
- **Lane assist** (Settings, on by default) keeps your chaser from turning back or crossing the lane by mistake. Off,
  you play every rule yourself and the umpire whistles you.
- **Simplified:** the shoulder-line limit is judged from his run, not from how his shoulders turn. Newer rules
  reportedly allow more sideways play (**conflict**), and the game's reading allows any sideways movement.
- **Not touching across the lane:** the game does not let the active chaser touch a defender on the far side of the
  lane between the poles. The rule texts found do not say this outright. It follows from the lane rule and is how
  matches are seen to be played.

## Outs

- **Rule:** a defender is out when:
  - he is touched by the active chaser's hand without a foul (a sky dive or pole dive counts the same);
  - he goes out of the field's limits (loses ground contact inside them);
  - he enters late.
  (Wikipedia glossary; sportzyogi.com; khokhochampions.com.)
- **The game:**
  - A touch is the active chaser's hand reaching the defender: the hand is 0.4 m in front of him, a sky dive's
    1.35 m, a pole dive's 1.9 m from the pole.
  - Out of limits is past a side or end line (`out_of_limits`). The line is in, and so is the free zone.
  - Late entry (`late_entry`): classic, the next batch is late if the successful chaser has given a kho before they
    are in (the glossary's wording); fast, 30 seconds after the last of the batch before is out (the league's rule).
- **Conflict:** one source says a defender is out only with both feet out. The game uses the line: past it, out.

## Sky dive and pole dive

- **Rule:** in a sky dive the active chaser dives full length to touch a defender, within the direction rules. In a
  pole dive he holds the pole with one hand and reaches past it with the other. (Wikipedia glossary.)
- **The game:**
  - DIVE throws your chaser at the nearest defender. If it misses, he is down for about a second (the dive, a moment
    on the ground, getting up).
  - In the free zone by a pole, DIVE is a pole dive.
  - The AI's chasers dive when a defender is just out of reach, most often at the lines. They pole dive when a
    defender is close round the pole.
  - In the classic game an out by a dive scores the same as any other. In the fast game every out is 2 points; the
    league's first season gave dives 3, its second season a flat 2.

## Turns, innings and the score

- **Rule:** a match is two innings. In each, each side chases one turn and defends one, so four turns.
  - Classic: turns of 9 minutes for seniors (7 for sub-juniors), 1 point an out. (khokhochampions.com;
    Olympics.com.)
  - Fast: turns of 7 minutes, 2 points an out. (The Bridge on the 2025 world championship; Wikipedia, Ultimate Kho
    Kho.)
- **The game:**
  - Match setup offers turns of 3 minutes, 5 minutes, or the real length (9 classic, 7 fast). Four real turns take
    half an hour on a phone.
  - `points_for_out` gives 1 classic, 2 fast.
  - The toss is held in setup. The winner chooses to chase or defend first. The AI captain, winning it, mostly
    defends first, to know the target.
- **Simplified:** the intervals between turns (5 and 9 minutes classic; 3 and 4, or 2 and 3, at the world
  championship: **conflict**) are a card you dismiss.
- **Not implemented:** the chasing captain's right to end a turn early.

## Dream runs (fast)

- **Rule:** a batch that stays on the field for 3 minutes scores its side a point, and another every 30 seconds after.
  That was the rule at the 2025 world championship and from the league's second season. The league's first season
  gave 2 points at 2 minutes 30, and 2 more every 30 seconds.
  (The Bridge; Sportskeeda; ANI's guide to Season 2.)
- **The game:** `dream_points` gives 1 at 3:00, then +1 each 30 s. The HUD shows the batch's time and a bar
  filling to 3:00. Tests check 179 s (0), 180 s (1), 210 s (2), 245 s (3), and none in the classic game.

## Wazir and power play (fast)

- **Rule:** the wazir is the one attacker who may change direction freely. He may still not cross the central
  lane, and he must still give and take a proper kho. A power play gives the attackers two wazirs for one batch,
  ending when all three of that batch are out. (The Bridge on the world championship; Wikipedia glossary;
  Sportskeeda; khelnow.)
- **The game:**
  - The chasing side's best chaser is its wazir. The step_chase direction rule does not apply to him; the lane rule
    does (tested).
  - Once each chasing turn, when a batch comes on, the side may call a power play. The next best chaser becomes a
    second wazir until that batch is out. You get a POWER PLAY button for 8 seconds as each batch comes on. The AI
    calls it on the second batch, or now and then the third.
- **Conflict:** sources give one power play a turn (Wikipedia glossary), one an innings (myKhel), or two a match
  (one summary of the Season 1 rule book). The game uses one a chasing turn. No source confirmed a power play at the
  world championship; the game uses it in the fast rules, and Settings can turn it off.

## Follow-on (classic)

- **Rule:** after the first innings, the side that chased first may make the other follow on if it leads by enough:
  the other side chases again at once. If they are still behind after it, the leading side wins without its second
  chase ("by an innings").
- **Conflict:** sources give "more than nine points, and it must be enforced" (khokhochampions.com), "9 or more,
  optional" (others), or "over six or eight" (Olympics.com).
- **The game:**
  - A lead of 9 or more lets the side choose. You are asked; the AI always enforces it.
  - On turns shorter than the real 9 minutes, the lead scales with the turn's length, never below 3 (a 3-minute turn
    needs 3). A 9-point lead in a 3-minute turn would hardly ever happen.
  - Settings can turn the follow-on off. `chase_order` and `over_after` make the order A B B A and end the match
    after the third turn if the follower is still behind. Tested.

## Ties

- **Rule:** a tied knockout match goes to one more innings, each side chasing a turn. If still tied, minimum
  chases: each side chases until its first out, and the quicker wins, again and again if level. A league match may
  stand as a tie. (khokho.co.in; khokhonms.org; the league's Season 1 rule book.)
- **The game:**
  - Knockout matches (the championships' quarter-finals on) play the extra innings, then minimum chases
    (`min_chase_winner`, tested).
  - Group matches may be tied: 1 point each, 2 for a win, as league stages give.
- **Not implemented:** the classic rule book's replay by lots for tied league matches; the game counts the tie.

## The officials

- **Rule:** two umpires, each controlling play in his half while moving in the lobby. A referee is overall in
  charge. A timekeeper starts each turn with a long whistle and a short one, and ends it with a long whistle. A scorer
  keeps the score and the order of entry. An out is a short whistle; a foul is short whistles again and again until
  it is put right. (khokhochampions.com, "Officials for management of the match"; khokho.co.in; khokhoskills.com.)
- **The game:**
  - The two umpires walk the side lines, one on each, each covering the half of the field from the centre to his
    pole. For an out, the umpire of that half gives a short whistle and raises his arm, facing the defender. For a
    foul, short whistles go on until it is put right, his arm pointing the way.
  - The timekeeper (seated at the table) whistles the start. The referee signals the end with both arms up, and the
    long whistle sounds.
  - The scorer sits at the table.
- **Not implemented:** yellow and red cards (the game has no misconduct), and the league's video reviews.

## Where the competitions differ

| | Classic (national championships) | Fast (2025 world championship, franchise league) |
|---|---|---|
| Field | 27 × 16 m, 8 squares, 35 cm cross lanes | 22 × 16 m, 6 squares, 40 cm cross lanes |
| Attackers | 9 (8 seated) | 7 (6 seated) |
| Turn | 9 min | 7 min |
| Points an out | 1 | 2 |
| Dream run | none | 1 at 3:00, +1 each 30 s |
| Wazir / power play | no | yes / yes (once a turn) |
| Follow-on | yes (9-point lead) | no |
| Next batch | before the next kho | within 30 s |
| Reviews | none | league: one an innings (not in the game) |

In the game, Quick Match lets you pick either rule book. The world championship mode is played to the fast rules,
the national championship to the classic rules.
