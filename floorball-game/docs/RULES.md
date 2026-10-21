# The rules Floorstorm plays

Floorstorm plays the International Floorball Federation's **Rules of the Game, edition valid from 1 July 2026**
("Rules and Interpretations"), the edition in force as of October 2026. It was approved by the IFF Central Board on
11 December 2025 and published in February 2026; a corrected clean final is dated 31 May 2026.

- Clean 2026 edition: https://www.floorball.sport/wp-content/uploads/2026/02/IFF-Rules-of-the-Game-2026.pdf
- With all changes marked: https://www.floorball.sport/wp-content/uploads/2026/02/Rules-of-the-Game-2026-with-all-changes-260209.pdf
- Clean final, 31 May 2026: https://www.floorball.at/wp-content/uploads/2026/06/Rules-of-the-Game-2026-clean-final-version-updated-260531.pdf
- The IFF's "What's new": https://floorball.sport/rules-of-the-game-2026-edition-whats-new/
- The 2022 edition (for wording the 2026 extracts did not show): https://www.mixtuura.fi/floorballrules2022/

**How sure this is.** The build environment could not download the PDFs (the hosts were blocked), so the rules were
read from search extracts of the 2026 text, the IFF's own summary of the changes, and the 2022 and earlier editions.
Each line below says which: **[2026]** confirmed from the 2026 text; **[2022]** from an earlier edition, probably
unchanged; **[verify]** from knowledge of the rules, to be checked against the PDF. In October 2026 every [verify]
line was re-checked against extracts of the 2026 PDFs (search-result snippets of the floorball.sport files, not a
full reading): what the extracts showed is now [2026] (confirmed from extracts), what they contradicted has been
corrected, and what they did not show keeps its tag and is listed in "Still to check against the 2026 PDF" at the
end. The owner (or anyone) can tick them off against the PDF; each has a test in `tests/test_runner.gd` that names
its rule.

The game never names the IFF or any federation, league or competition (Play policy, as Takraw learned): in the game
these are "the international Rules of the Game". This document is not shipped.

Code: `game/rules.gd` (the pure rules module the match drives), `game/match.gd` (what happens on the rink),
`game/team_ai.gd` (how the teams play). Tests: `tests/test_runner.gd`.

## Chapter 1: the rink and equipment

| Rule | What it says | How the game does it | Source |
|---|---|---|---|
| 101 | Rink 40 x 20 m (at least 36 x 18), boards with rounded corners | 40 x 20 m, corner radius 1.5 m (the radius is set by board certification, not the rules: 1.5 m is typical) | [2026] |
| Material Regulations | Boards 50 cm high | 0.5 m; a ball over them is out | [verify] (no IFF text found) |
| 102 | Lines 4-5 cm; centre line and centre spot | 5 cm lines painted into the floor texture | [2026] |
| 102 | Face-off dots on the centre line and the goal lines' extensions, 1.5 m from the long boards (six, plus the centre spot) | `Rules.faceoff_dots()` | [2022] / six [2026] |
| 102.3 | Goal crease 4 x 5 m, 2.85 m from the end board | `CREASE_FRONT`, `CREASE_BACK` | [2026] |
| 102.4 | Goalkeeper area 1 x 2.5 m, 0.65 m in front of the crease's rear line; its rear line is the goal line (so 3.5 m from the end board) | `GK_AREA_FRONT`, `GOAL_LINE` | [2026] |
| 103 | Goal 160 x 115 cm (65 cm deep) | Red frame, white net, collision for posts, bar, net | [2022] |
| 104 | Substitution zones on one long side, including the benches, from 5 m from the centre line to the imaginary extended goal line (about 11.5 m on a 40 m rink; the 2022 "length of 10 m" is struck out), at most 3 m wide measured from the board | Simplified: the game's zone is 5-10 m from the centre line (`SUB_ZONE_FROM_CENTRE`, `SUB_ZONE_LEN`), on the far side, the benches behind | [2026] |
| 105 | Penalty benches opposite the substitution zones, at least 1 m from the centre line, 2 m long; secretariat between them | Near side, by the camera | [2026] |
| Material Regs | Ball 72 ± 1 mm, 23 ± 1 g, holes 10 ± 1 mm; 26 holes | `Ball.R`, the holes painted, a strong drag for its light, holed flight | Size and weight confirmed (older Material Regulations; 2026 edition not seen) / 26 holes [verify] |
| 403 | The goalkeeper has no stick, wears a mask/helmet; 2026: helmet and thin gloves allowed, padding shaped to the body | Goalkeepers are drawn with a caged helmet, padded trousers, no stick | [2026] |
| Material Regs | Stick at most 114 cm (set by the Material Regulations, not rule 406; players 190 cm or taller may be permitted 116 cm) | Shaft 96 cm plus the blade | Confirmed (Material Regulations 2010 change; current edition not seen) |

## Chapter 2: time

| Rule | What it says | How the game does it | Source |
|---|---|---|---|
| 201 | Three periods of 20 min, 10-min intervals, change ends each interval | Periods of 4, 8, 12 or 20 min (20 is the rules'; shorter suit a phone); the interval is a card you continue from; ends change | [2026] |
| 201 | Effective time: the clock stops at every whistle; 2026: "the last 3 minutes of regular game time shall always be effective" | Two clocks: **Effective time** (the IFF's) and **Running clock** (a league's: runs through stoppages except in the last 3 minutes of the third period) | [2026] |
| 202 | One 30-second time-out a team, called by the team at a stoppage | One a team from the pause menu; logged and signalled (the 30 seconds themselves are not shown) | [2022] |
| 203 | Overtime when a winner is needed: 10 min, not divided into periods, "played until one team scores" (sudden victory); the same clock rules as regular time; penalty time carries on into it; still level, penalty shots | `OT_IFF_S`; a league's regular-season 5 min with the running-clock option (SIBF 2025/26) | [2026] |
| 204 | Penalty shots after overtime: five different field players a team; then one each until decided; **2026: after the first five, any field player, more than once** | `State.shootout_shot`, `may_shoot`; decided early when one side cannot catch up; a shoot-out win counts one goal | [2026] |

203 also says: "Before overtime, the teams have the right to a 2-minute intermission, but no changing of ends shall
take place." The game plays overtime at the ends of the third period, as the rule says [2026]; the 2-minute
intermission is not shown as such.

## Chapter 3: the teams

| Rule | What it says | How the game does it | Source |
|---|---|---|---|
| 301 | At most 20 players; on the rink 5 field players and a goalkeeper | Squads of 20: two goalkeepers, three lines of five (centre, two forwards, two defenders), two reserves | [2026] |
| 302 | Substitutions at any time, any number, only in the team's own zone | Flying line changes every 40-60 s of play: the line skates to its zone, the next comes on there | [2026] |
| 303 | A goalkeeper wholly out of his crease is a field player | The goalkeeper stays in his area in the game | [2026] |

Not modelled: pulling the goalkeeper for a sixth field player (in the roadmap), team staff.

## Chapter 5: play

| Rule | What it says | How the game does it | Source |
|---|---|---|---|
| 501 | Face-off: two players face each other, feet square to the centre line, blades either side of the ball; the rest "at least 3 m from the ball, sticks included", without summons (501.4) | Centres face each other, the others take up their places 3 m+ off; won by stick skill, back to a team-mate | [2026 3v3 wording] / 3 m [2026] |
| 503 | A face-off at the nearest face-off dot to where the ball was; the centre spot to start periods and after goals | `nearest_faceoff()` excludes the centre spot | [2026] |
| 504 | Hit-in 1.5 m from the board where the ball left, never behind a goal line's extension (then the nearest dot on it); opponents 3 m; a goal may be scored directly | `hit_in_spot()`; the taker must hit it | [2026] |
| 505 | Out over the boards: the team that did not touch it last hits it in | The ball crossing the boards' top | [2022] |
| 506 | Free-hit where the offence was, never behind a goal line's extension and never within 3.5 m of the **goalkeeper area** (the small 1 x 2.5 m area; in 2026 terms the goal crease is the bigger 4 x 5 m area); one nearer is moved out to 3.5 m from the area's outer line, along an imaginary line from the centre of the goal line through the place of the offence; opponents 3 m, sticks included; may score directly | `free_hit_spot()` measures with `gk_area_distance()` against `FREE_HIT_FROM_GK_AREA` (3.5 m) and moves the ball out along that line; the defenders placed 3 m+ away | 3.5 m from the goalkeeper area, 3 m [2026] / the imaginary line [2022] / scoring directly [verify] |
| 507 | The offences that lead to a free-hit | `Rules.OFFENCES`, below | [2022] list, first and 3-second items [2026] |
| 2026 | A free-hit or hit-in taken from an obviously wrong place for advantage is incorrectly performed | The game always places the ball itself | [2026] |
| Advantage | The fouled team keeps the ball: play on, the referee signals advantage (glossary: play continues "if this benefits the non-offending team"); no fixed time in the rules | Advantage played for 2.6 s (the game's own choice), then forgotten; for a penalty, delayed until the other team touches the ball | [2026] signal / [verify] details |

### The offences (507)

The game calls these when they happen; the box score lists each penalty with its offence and rule.

| Offence | Rule | Consequence in the game |
|---|---|---|
| Hitting, blocking, lifting or kicking the opponent's stick; hooking | 507.1 | Free-hit; a tackle from behind is far more likely to be one |
| Stick above the waist in the swing | 507.2 | The game's swings never go above the waist (the animation is built to the rule) |
| Playing the ball above knee height with stick or foot | 507.3 | Free-hit when you swing at a ball in the air |
| Stick, foot or leg between the opponent's legs | 507.4 | Free-hit (from failed tackles) |
| Pushing (only shoulder to shoulder is allowed) | 507.5 | Free-hit |
| Obstruction | 507.6 | Free-hit |
| Head, hand, jumping, playing the ball lying or on two knees | 507.8-507.11 | Not done by anyone in the game, by design |
| Field player in the goalkeeper area; 2026: never through it; no reasonable effort to avoid colliding with the goalkeeper; following him to block his view | 507.12 / [2026] | Every player's movement is kept out of both goalkeeper areas (your joystick too) |
| Goalkeeper's throw over the centre line in the air | 507.15 | AI throws go along the floor or bounce short. 2026 kept it: an offence only if the ball touches nothing before it passes the centre line, and the entire ball must pass [2026] |
| Goalkeeper holding the ball over 3 seconds | 507.16 | Free-hit to the other team; a Rookie goalkeeper sometimes holds too long |
| Goalkeeper takes a deliberate pass from a team-mate in his hands | 507.17 | The AI never passes back to the goalkeeper. 2026 kept it: an offence only if the pass is intentional and the goalkeeper touches the ball with hands or arms; not an offence if the goalkeeper is wholly outside the goal crease (then a field player); never a penalty shot [2026] |
| Delay, passive play | 507.20 | Not called (in the roadmap) |
| Incorrect free-hit (dragged, flicked, lifted) | 507.21 | Not possible: restarts are always hits |

### Penalties (Chapter 6)

| Rule | What it says | How the game does it | Source |
|---|---|---|---|
| 604/605 | Minor bench penalty, 2 min, any field player serves it; ends if the other team scores while this team is outnumbered | `add_penalty`, `goal()` (the shortest minor ends) | 2 min [2026] / ending on a goal [2022] |
| 605 | Minors for: dangerous free-hit offences, holding, tripping, slashing, charging, lying down to block, too many players, protests | `sanction()`; trips, slashes and holds come from failed tackles | [verify] list |
| 606/607 | Major bench penalty, 5 min, served in full; for violent offences | `pen5` | [2022] |
| 608-610 | 10-min personal penalty: only "in connection with a minor bench penalty"; it affects only the offender, not the number on the rink; never ended by a goal; it starts once the team's bench penalties have expired or ended | `add_penalty("pen10")`: the offender himself sits 2 + 10, the minor first (the team short only for the 2), then the 10 minutes, when a team-mate may come on | [2026] |
| 611-614 | Technical match penalty (611) / match penalty (613, 614): out for the rest of the match; the team serves 5 min | `match`: the player gone, a team-mate serves 5 min | [2026] categories / 5 min [verify] |
| 603 | At most one bench penalty per player and two per team run at once, measured in the order imposed; the next starts when one ends | `_start_waiting()`; never fewer than three field players | [2026] |
| 602 | Delayed penalty: the referee's arm up while the fouled team keeps the ball; a goal cancels a delayed minor | Played as written; the box score records the penalty | Delayed penalty [2026] / goal cancels [verify] |
| 2026 | **Coincidental penalties no longer reduce the number of players on the rink** | `mark_coincidental()` | [2026] |
| 2026 | Instigating penalty: an extra minor for starting an altercation | Not modelled: there are no altercations in the game | [2026] |
| Goalkeeper's offence | A field player (chosen by the captain) serves a goalkeeper's minor bench penalty; "a goalkeeper incurring a major bench penalty, or a personal penalty shall serve the penalty themself", and leaves the penalty bench only at the next interruption | `_penalise()`: a field player serves his minor (and the 5 min of a match penalty); he sits his own major and personal penalties, and `_update_boxes()` brings on the reserve goalkeeper | [2026] |

Simplified: the penalised player's place is taken at once by a team-mate from the bench, and the team plays short by
leaving the wingers' places empty; he is not seen walking to the penalty bench.

### Penalty shot (508-510)

The penalty shot is in Chapter 5: 508 penalty shot, 509 delayed penalty shot, 510 offences leading to a penalty
shot. Taken from the centre spot [2026]; all players except the shooter and the defending goalkeeper stay in their
substitution zones throughout, the shot starts and ends with the referee's whistle, and one taken with the foot is
retaken [2026]; the clock stopped [2026]. The goalkeeper on his line, the ball kept moving toward the goal, one shot
and no rebound [verify]. A goal scored during a delayed penalty shot stands and the penalty shot is cancelled (509)
[2026]. When awarded: "when an offence leading to a penalty shot is committed" (508) [2026]; the list (510) [verify]
(2022: an offence that stops a clear goal chance). In the game it is used for the competition after overtime, and
the referees award one during play when an offence stops a clear chance (`_award_penalty_shot()`, `_clear_chance()`).

## Chapter 7: goals

| Rule | What it says | How the game does it | Source |
|---|---|---|---|
| 702 | The whole ball over the goal line from the front, played correctly with a field player's stick **or thrown by the goalkeeper (2026)**, no attacking offence | `judge_goal()`: stick, a deflection off a defender, an attacker's body without intent, a goalkeeper's throw | [2026] |
| 702 | An own goal counts however it went in | Yes | [verify] |
| 703 | Not if kicked, headed or put in by hand by the attackers, after an attacking offence, with too many players, or after time | No goal and a free-hit to the defenders (or a face-off) | [2026] first clause / [verify] rest |
| After a goal | Face-off at the centre spot (503) | Yes | [2026] |

## The officials (306)

Two referees, equal in authority, move up and down the long sides on the diagonal (one ahead of play on the near
side, one behind it on the far side). At a whistle the nearer one blows and signals: "the referees shall first show
the consequence sign and then a possible offence sign... always in connection with penalties" [2026]. In the game the
referee's body makes the sign and a card on the screen shows the consequence first, the offence and its rule under
it.

| Sign | The arms | Source |
|---|---|---|
| Free-hit | One arm out level toward the way it goes; the foot marks the spot | [2026] |
| Advantage | An arm forward and up, the way play goes, and the call | [2026] (shape [verify]) |
| Hit-in | An arm pointing down toward the floor, the way it goes | [verify] |
| Delayed penalty | One arm straight up, held | [verify] (2002 edition: the arm held vertically) |
| Goal | Pointing to the centre spot | [verify] |
| No goal | Both arms swept out sideways | [verify] |
| 2 / 5 minutes | An arm up showing two fingers / the open hand | [verify] |
| 10 minutes | Both hands up | [verify] |
| Match penalty | The red card held up | [verify] |
| Penalty shot | Pointing to the centre spot, then the arms crossed above the head | [verify] |
| Face-off | Pointing to the dot | [verify] |
| Time-out | The hands make a T | [verify] |

The signs' appendix of the 2026 PDF was not readable here; the shapes above are as referees are seen to make them.
The IFF Referee Playbook agrees that advantage and delayed penalty are the only signs held while play goes on.
How to Play > Referees' signs draws each one.

## How the AI plays (and the numbers it was tuned to)

- **Defence: 2-1-2**, the IFF's most common system (two forwards high, the centre in the middle, two defenders low in
  front of the crease), the nearest player pressing the carrier on his goal side; a **2-2-1 forecheck** when the
  ball is deep in the other end. Source: IFF coaching material via the market research
  (https://floorball.sport, "Tactics: defensive systems"), [verify].
- **Attack**: wingers wide along the boards and ahead, the centre to the slot, the defenders back as the safety; the
  carrier reads shoot, pass or carry a few times a second; passes picked for open lanes, never across his own goal.
- **Shifts**: three lines, changes on the fly every 40-60 s of play (top teams change about every 45 s).
- **The numbers** (men's World Championship 2016 analysis: about 10.2 goals a match, 10.6% of all shots scored, 27%
  of shots on target scored, so about 73% saved; 69% of possessions shorter than 15 s). Source: the study cited in
  the market research (research notes, "Tactics and stats").
- **Measured** with `tests/ai_bench.tscn` (AI v AI, per 60 minutes of play, 4 matches): **10.0 goals, 120 shots
  (62 on goal), 75.7% saved, 5 penalties, 30 face-offs.** Real: about 10 goals, about 95 shots, about 73% saved,
  4-6 penalties. Shots run a little high; noted for tuning.

## Where competitions differ (offered as options where they matter)

| Competition | Difference | In the game |
|---|---|---|
| World Championships | Group matches may be drawn (2 points a win, 1 a draw); knockout matches: 10-min overtime, then penalty shots | The World Finals; Quick match "A draw stands" / "Overtime, then penalty shots" |
| Swedish and Finnish top leagues | Every regular-season match decided: 5-min overtime then penalty shots; 3-2-1-0 points | "Running clock" option uses the 5-min overtime |
| National and junior leagues | Running time with the last 3 minutes effective (allowed by 201 since 2026), shorter periods | "Running clock" and the period lengths |
| 3v3 | A separate ruleset (22 x 11 m, 2 m distances) | Not in the game |

## Still to check against the 2026 PDF (October 2026)

- Material Regulations: boards 50 cm high.
- Material Regulations: the ball's 26 holes (and the 2026 edition's ball and stick figures).
- 102: face-off dots 1.5 m from the long boards.
- 103: goal 160 x 115 cm, 65 cm deep.
- 202: one 30-second time-out a team.
- 504/506: a goal may be scored directly from a hit-in or free-hit.
- 505: out over the boards, the team that did not touch it last hits it in.
- 506: the "imaginary line from the centre of the goal line" clause is still in the 2026 text.
- Advantage: details (no fixed time; the delayed penalty until the other team touches the ball).
- 602: a goal cancels a delayed minor.
- 603/604: a minor ends on a goal while the team is outnumbered (2026 wording; coincidental penalties too).
- 605: the list of minor offences.
- 606/607: major bench penalty 5 min, served in full.
- 611-614: the team's 5-minute bench penalty with a match penalty.
- 508: the goalkeeper on his line, the ball kept moving toward the goal, no rebound.
- 510: the list of offences leading to a penalty shot.
- 702: an own goal counts however it went in.
- 703: the rest of the no-goal list (too many players, after time, etc.).
- Referees' signs: every shape in the appendix.
- The 2-1-2 defence from IFF coaching material (not a rule).

What was tried: the October 2026 re-check could not download or open any 2026 PDF. curl through the proxy was
refused (CONNECT 403) by www.floorball.sport, www.floorball.at, floorball.de (the German 2026 translation),
bandyforbundet.no (the Norwegian 2026 text with changes marked), the other national federations' sites (Finland,
Sweden, Switzerland, Czechia, Slovakia, Denmark, Poland, Latvia, Estonia, the USA, Canada, Australia, the
Netherlands), web.archive.org, archive.org and Google's cache; the web fetcher failed on every host with a DNS error.
Everything marked [2026] in October 2026 rests on search-result extracts of the official PDFs, so the exact wording
may differ slightly. The owner should read the PDF (https://floorball.sport, Rules of the Game 2026) against the
lines above, and against the extracts quoted in this document.
