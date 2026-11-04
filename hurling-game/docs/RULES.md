# The rules of hurling, as Hurling Heroes plays them

The game plays the **GAA Official Guide, Part 2 (Playing Rules)**, the edition in force from **27 March 2026**
(with the hurling dissent rule passed at Congress in February 2026, in force from 28 March 2026). The rules live in
one pure module, `game/rules.gd` (and the pitch's measurements in `game/pitch.gd`); the match asks it what the rules
say, and `tests/test_runner.gd` checks each rule on its own (the "Test" column names the check).

**Sources.** Every rule below was checked against excerpts of the Official Guide's editions and the GAA's own
explainers. Rule numbers move between editions, so each is given as the Guide groups it (Rules of Specification,
Rules of Control, Playing Rules of Hurling), with the number used in the 2024-2026 editions where known.
- Official Guide Part 2, 27.03.2026: https://usgaa.org/wp-content/uploads/2026/04/Official-Guide-Part-2-03-27-2026.pdf
- Official Guide Part 2, 15.04.2026 (gaa.ie): https://www.gaa.ie/api/images/image/upload/t_q-best/prd/xi4oyuttzqpaqr2vfhbn.pdf
- Official Guide Part 2, 2026 (Galway copy): https://www.galwaygaa.ie/wp-content/uploads/2026/02/Official-Guide-Part-2.pdf
- Official Guide Part 2, 10.03.2025: https://www.gaa.ie/api/images/image/upload/t_q-best/prd/brrkask6svudmn1i7nyf.pdf
- Official Guide Part 2, 2024: https://gaelicgameseurope.com/wp-content/uploads/2024/05/GAA_Official-Guide-Part-2_2024.pdf
- Official Guide Part 2, 2019: http://usgaa.org/wp-content/uploads/2019/03/2019-Official-Guide-Part-2-Corrected-032719.pdf
- Official Guide Part 2, 2016: https://learning.gaa.ie/sites/default/files/2016%20Official%20Guide%20-%20Part%202.pdf
- GAA umpires: https://www.gaa.ie/my-gaa/match-officials/umpires
- New hurling dissent rules explained (GAA, 2026): https://www.gaa.ie/article/new-hurling-dissent-rules-explained
- Penalty shoot-out format (RTÉ, 2019): https://www.rte.ie/sport/gaa/2019/0604/1053472-penalty-clause-inserted-into-championship-this-weekend/
- The black card in hurling (Irish Times, June 2026): https://www.irishtimes.com/sport/gaelic-games/2026/06/11/can-we-all-just-admit-we-havent-a-clue-how-the-black-card-works-in-hurling/
- The 2015 penalty change (The42): https://www.the42.ie/hurling-penalty-rule-3249953-Feb2017/
- Camogie and hurling rule differences (GAA Learning): https://learning.gaa.ie/sites/default/files/Camogie-Hurling_Rule_Differences_2018-2021_0.pdf
- 2021 playing rule changes FAQ: https://camogie.ie/wp-content/uploads/2021/06/Playing-Rule-changes-2021-FAQ.pdf
- GAA referee guidance on advantage (2021): https://gaa.ie/api/images/image/upload/t_q-best/oxdbyhv1zhtgqfsue5zj.pdf

**Checked against the full text, 4 November 2026.** The network now reaches `www.gaa.ie`, and every rule below was
read against the whole of the Official Guide Part 2 effective 27 March 2026 (the gaa.ie copy above). The four that
rested on a single excerpt hold: the puck-out's 13 m travel (Rule 2.6), the dissent advance of 30 m up to the 20 m
line (6.4), advantage for up to five seconds (5.44) and the black card (5.45). The check corrected: the distance at a
free and a 65 (20 m, not 13, and for the taker's teammates too), the sideline's 13 m (teammates too), the free from
the centre of the 20 m line (laid out as a penalty), the black card's grades and its zone, a yellow after a black (a
red), and the temporary substitutes (blood and head injuries only). Three differences are left for the owner (below,
"Left as they are").

## The field, goals and equipment (Rules of Specification)

| Rule | What it says | In the game | Test |
|---|---|---|---|
| 1.1 Field | 130-145 m long, 80-90 m wide | 140 × 85 m (`Pitch.LENGTH`, `WIDTH`) | "Pitch: 130-145 m by 80-90 m" |
| 1.2 Lines | Lines across the field at 13, 20, 45 and 65 m from each end line; a halfway line; flags at the corners and the lines | All drawn; the corner and line flags stand off the field | "Lines at 13, 20, 45 and 65 m" |
| Rectangles | Small rectangle 14 × 4.5 m (sides 3.75 m outside each post), large rectangle 19 × 13 m (sides 6.25 m outside each post) | As written; puck-outs from the small rectangle, the large rectangle decides penalties | "Rectangles" |
| Arc | A semicircle of 13 m radius on the centre of each 20 m line, outside it | Drawn; used for penalties, 20 m frees and the black-card zone | "The arc" |
| 1.3 Goalposts | Two posts 6.5 m apart (inside), at least 7 m high; crossbar 2.5 m up; a net | Posts 10 m high, bar 2.5 m, net about 2 m deep | "Goals" |
| 4.2 Helmets | A helmet with a face guard, mandatory at every grade (since 2010) | Every player wears one | (visual) |
| The sliotar | 110-116 g (2022 specification), 69-72 mm across | 113 g, 71 mm; flies with air drag so a 40 m/s puck-out carries 80-100 m | "Sliotar: a 40 m/s puck-out carries 70-110 m" |
| The 40 m arc, 2-point scores, the 11 m spot | **Football only** (2025) | Not used | - |

## The team (Rules of Control, Rule 1)

| Rule | What it says | In the game |
|---|---|---|
| Fifteen a side | A goalkeeper and fourteen outfield players; by convention 1 / 2-3-4 / 5-6-7 / 8-9 / 10-11-12 / 13-14-15 | Each county's 15 starters and 11 substitutes; team sheets laid out this way |
| Substitutes (2.3, Rules of Control 1.5(b)) | Five in normal time, three more in extra time; temporary substitutes for a blood or a suspected head injury do not count; a player sent off is not replaced, and a senior player in the sin bin is not replaced either (a temporary substitute for the sin bin is for Under-18 and younger, 6.4) | `Rules.subs_allowed` (tested). A sin-binned or sent-off player's side plays a man short. No injuries yet, so no temporary substitutes (next steps). |

## Scoring (Playing Rules of Hurling, Scores)

| Rule | In the game | Test |
|---|---|---|
| A goal (over the goal line, between the posts, under the bar) is worth 3; a point (over the bar, between the posts) 1; the score is written goals-points (2-18) | `Rules.total`, `Rules.fmt`, `Pitch.score_kind`; the scoreboard shows "1-14 (17)" | "Scores: ..." |
| No goal from a hand-pass; a legal hand-passed point stands; nothing thrown or carried over the line | `Rules.score_counts`; a hand-passed goal is waved off by the umpires and restarted with a puck-out | "no goal from a hand-pass", "a hand-passed point stands" |
| A ball over the posts' tops, inside their line, is a point | Any height counts | "high over the posts" |
| Off a post or the bar it stays in play | The sliotar rebounds | (match) |

## Time (Rules of Control, Rule 3)

| Rule | In the game | Test |
|---|---|---|
| Senior inter-county 2 × 35 minutes, half-time up to 15; everything else (club, minor, U-20, junior) 2 × 30, half-time up to 10 | Settings > Grade: Senior county (2 × 35) or Club (2 × 30). The clock runs faster than real time to fit Settings > Match length (8-70 minutes; 70 is real time) | "Time: halves ..." |
| Time added for stoppages; the referee keeps the time (a public clock and hooter "where available", subject to Central Council regulations, 3.2: not in Part 2 for hurling) | Added time shown in whole minutes a minute before the half ends, from the half's stoppages; the referee ends the half at the first break, or when the ball is out of the scoring zones, once it is up | (match) |
| The throw-in at the start of each half (and of each period of extra time), between two players from each side "one behind the other in their own defensive sides of the halfway line"; "all other players ... in their respective positions behind the 45 m lines" (2.1) | The two midfielders side by side beside the referee, the rest in position out of the centre. **Not yet as the Guide has it:** both a one-behind-the-other pair and the rest moved behind the 45s changed where the opening play goes, enough that the gliding note's camera saw no feet; it waits for a way that keeps the note able to see | "Throw-in: two from each side" |
| A drawn game that needs a winner: extra time, 2 × 10 minutes; then a penalty shoot-out: five takers each, goals only, then sudden death with the same takers | Match setup: "A draw: Extra time, then penalties"; championship knock-out games always | "Shoot-out: ..." |
| Cards carry into extra time (Congress 2024) | Yes: a player's yellow stands | - |
| The sin bin: ten minutes "irrespective of delays", through normal time, added time and extra time (Rules of Control 1.2(ix)(d)) | Timed on the referee's watch over the whole match (`Match.watch`), added time included; the man comes back at the next break after it | "sin bin: back after 10 minutes on the watch" |

The 2019 format had two further 5-minute periods before penalties; recent games (the 2025 southern provincial final
went straight from extra time to penalties) show they are gone, so the game goes straight to penalties.

## The play (Playing Rules of Hurling, The Play; technical fouls)

| Rule | In the game | Test |
|---|---|---|
| Four steps with the sliotar in the hand, or holding it no longer than four steps take | Steps are counted from the player's own strides (a foot put down); over four is a free against him; 2.4 s standing still. The HUD shows the steps as dots | "Carry: a fifth step is a foul", "held longer" |
| Caught (taken into the hand) at most twice before it is played away | A catch, a solo onto the hurley, a second catch, then he must strike, hand-pass or keep it on the hurley; a third catch is a free | "Carry: a third catch is a foul" |
| Carried on the hurley (balanced or hopped) as far as he likes | Solo: no limit, a little slower | "Carry: on the hurley, no limit" |
| Not lifted off the ground with the hand (with the hurley or the foot) | Ground balls are lifted with the hurley (LIFT) or pulled first time (PULL) | "Ground: ..." |
| A hand-pass released and struck with a definite striking action of the hand; no throwing | The hand-pass is struck from the left hand; there is no throw | "Hand-pass: struck, not thrown" |
| Released and caught again without playing it on the hurley is a foul | The game never lets a player do it | "Recatch" |
| Fouls by the player in possession are a free to the other side where they happen | Yes | - |

The autumn 2026 third-level **trial** (six steps, no two hand-passes in a row, a 2-point sideline cut, puck-outs past
the 45, 65s from the attackers' own half) is **not in force** and the game does not play it. It could be a match
option if it is adopted.

## Restarts (Playing Rules of Hurling, Set Play)

| Rule | In the game | Test |
|---|---|---|
| Puck-out after a score or a wide: from inside the small rectangle, struck by the goalkeeper (from the hand); everyone else, both sides, outside the 20 m line until it is struck; it must travel 13 m before another of the taker's side plays it | As written: players walk to legal places (`Rules.position_ok`, `legal_spot`); no teammate may touch it inside 13 m. The keeper chooses short (to a free back) or long (to the middle third): 37% and 55% of puck-outs in the 2026 league | "Puck-out: ..." |
| A 65 when a defender puts it over his own end line wide: from the 65 m line opposite where it crossed | As written; the free-taker usually goes for the point | "65: ..." |
| A sideline cut to the other side, where it crossed; struck off the ground; every other player, both sides, 13 m away (2.8, 4.11(b)) | As written | "Sideline: ..." |
| A free where the foul happened; lifted and struck (or struck on the ground), not from the hand; every other player, both sides, 20 m away (2.4(a), 4.11(a), 4.17(a)); a 65 is a free puck, the same | As written; within range the free-taker goes for a point, else it is struck to a teammate | "Free: where the foul was", "20 m is far enough" |
| A foul by a defender inside his 20 m line, outside the large rectangle: a free on the 20 m line opposite | As written | "Inside the 20 m line ..." |
| A technical foul by a defender in the large rectangle: a free from the centre of the 20 m line, laid out as a penalty but with up to five defenders on the goal line (2.2(a), 2.4(c)) | As written: the keeper and the full-back line on the goal line, everyone else outside the 20 m line and the arc | "Technical foul in the large rectangle", "laid out as a penalty" |
| A penalty for an aggressive foul by a defender in the large rectangle, or (senior inter-county, 5.45) a foul denying a goal chance inside the 20 m line (but not within 25 m of a sideline) or the arc: struck on or outside the 20 m line (placed up to 7 m back for a run-up); one defender on the goal line; everyone else outside the 20 m line and the arc | As written (2015 rule) | "Penalty: ..." |
| A throw-in for simultaneous fouls, or a penalty struck inside the 20 m line | The rule is in the module; the game's penalty taker always strikes from the line | - |
| Dissent: the free moves 30 m on, no nearer goal than the 20 m line (2026) | Now and then a player protests a free and the referee moves it on | "Dissent: ..." |

## The tackle and fouls (Playing Rules of Hurling, Fouls)

Fair: a side-to-side shoulder on a player with the ball (or both going for it); hooking or blocking his hurley;
flicking the sliotar off his hurley or out of his hand; clashing hurleys when both are striking. In the game: TACKLE
chooses the shoulder, the hook (from behind as he strikes), the block (from in front) or the flick (as he solos).

Fouls: pulling down, tripping, holding, pushing, charging from behind or the front, a careless hurley, striking an
opponent's hurley when he is not playing the ball, charging the goalkeeper in his small rectangle, striking an
opponent. In the game each tackle can be a foul: more often from behind and when a defender is desperate to stop a
goal. Technical and aggressive fouls are kept apart (`Rules.TECHNICAL`, `Rules.AGGRESSIVE`).

**Advantage** (2015, reworded 2021): the referee may play on for up to five seconds, one arm straight up; for an
aggressive foul only with a clear goal chance or time and space; if nothing comes of it he brings it back for the
free. In the game: as written; a shot, a score or the fouled side losing the ball ends it.

## Discipline (Rules of Control, Rule 6; Playing Rules of Hurling 5.45)

| Rule | In the game | Test |
|---|---|---|
| Yellow card: a caution; any two of a yellow and a black is a red (1.2(ix)(e)), sent off, not replaced | Cynical pull-downs, trips and holds, careless hurleys, charging the goalkeeper | "A second yellow is a red", "A yellow after a black" |
| Red card: striking an opponent, kicking, stamping, dangerous use of the hurley ... | Striking an opponent | "Striking an opponent: red" |
| **Black card** (5.45): pulling down, tripping or a careless hurley on a player in possession that denies a goal chance inside the 20 m line (not within 25 m of a sideline) or the arc (Definitions 9): a penalty, and ten minutes in the sin bin; after a yellow or a black, a red. It applies "only to Inter-County Senior, Under 20 and Minor (Under 17)" games: **not in club hurling** (nor inter-county junior) | Grade: Senior county has it. Club does not: there the foul is a free by the ordinary rules (a penalty only inside the large rectangle, a free on the 20 m line inside the 20 m line) | "Denying a goal chance (senior county): black", "Club hurling has no black card", "Club: a denial ... not a penalty" |

## The officials (Rules of Control)

A referee (who keeps the time and gives every decision), two linesmen and four umpires (two at each end, in white
coats). In the game:
- **Referee**: follows the play on a diagonal behind it, whistles, and signals: an arm out toward the goal a free
  attacks, one arm straight up for advantage, both arms toward the 20 m line for a penalty, the card held up, and ten
  fingers for the sin bin; he throws the ball in.
- **Linesmen**: along each side line with the play; flag held out the way a sideline cut goes.
- **Umpires**: beside the posts; the white flag waved for a point, the green flag for a goal, arms crossed over the
  head for a wide (a score that does not stand: the flags crossed at the centre of the goal, Rules of Control 2.2(i)(d)), an arm straight up and then pointing in for a 65.
- Hawk-Eye is used "at Croke Park and at other venues approved by Central Council"; the game shows it at the stadium
  (a close point or wide over the bar: the card, then TÁ or NÍL). The game's umpires never err.

## Where competitions differ

- **Senior inter-county** (championship and league): 2 × 35, half-time 15, the black card. The game's default.
- **Club** (and inter-county junior): 2 × 30, half-time 10, no black card. Settings
  > Grade.
- **Knock-out games** need a winner on the day (extra time, then penalties); group games and league games can end
  level. Match setup offers both; the championship uses both, as the real one does.
- **The championship format** (the game's own Summer Championship: two groups of five, a round robin, then group
  finals, quarter-finals for the losers against the other group's third, semi-finals and the final) follows the shape
  of the senior championship (two provincial round robins, then the knock-outs) without its names. The real
  tie-breaker between level counties is head-to-head first; the game uses score difference (simpler to show), noted
  in the table.

## Camogie

Camogie is governed by the Camogie Association, with its own rules (60 minutes, a 45 instead of the 65, hand-passed
goals allowed, a lighter sliotar, different contact rules). The game does not play it yet; it would need those rules
done properly, not a re-skin.

## Left as they are (for the owner)

Three places where the full text differs from what the game does, left alone because each changes how matches play:
- **Which fouls are a yellow.** The Guide cautions every pull-down, trip and careless hurley (5.1, 5.2, 5.6), and
  holding and charging on the second time (5.10, 5.11); the game cautions only the cynical ones.
- **Scoring with the hand.** "A player on the team attacking a goal and who is in possession of the ball may not
  score ... with the hand(s)" (3.1, 4.13): no hand-passed point either, only a ball in flight struck with the hand
  (3.2), and the foul is a free out where it happened. The game lets a legal hand-passed point stand and waves off a
  hand-passed goal with a puck-out.
- **Advantage for technical fouls.** Rule 5.44 plays advantage when "an Aggressive Foul is committed"; the game also
  plays it for technical fouls.
