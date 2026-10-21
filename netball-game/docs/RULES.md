# The rules the game plays

Centre Pass Netball plays the **Rules of Netball, 2024 Edition**, published by World Netball (the sport's governing
body) in December 2023, in force for international matches from 1 January 2024 and in every member nation by
1 September 2024. As of October 2026 it is still the edition in force: there is no 2025 or 2026 edition. World
Netball opened a minor rules review in May 2026, to go to its Congress before the 2027 world championship.

- Rulebook (PDF): https://netball.sport/wp-content/uploads/2024/01/World-Netball-Rules-Book-2024.pdf
  (mirror: https://netball.com.au/sites/default/files/2023-12/World%20Netball%20-%20Rules%20of%20Netball%202024.pdf)
- The rules page: https://netball.sport/game/the-rules-of-netball/
- What changed in 2024: https://netball.com.au/news/changes-world-netball-rules ;
  https://vic.netball.com.au/sites/vic/files/2024-02/NV%202024%20Rule%20update%20resource.pdf ;
  https://netball.sport/wp-content/uploads/2024/02/World-Netball-Congress-Approves-Changes-to-the-International-Rules-of-Netball.pdf
- The minor review: https://netball.sport/world-netball-launches-minor-rules-review/

**Rule numbers.** These were confirmed for the 2024 book by national bodies' summaries: R3 Team, R4 Match officials,
R6 Sanctions and actions, R7 Advantage, R8 Centre pass, R9 Scoring a goal, R10 Stoppages, R12 Short pass,
R13 Obstruction, R16 Contact. The others below are named by their subject; the research could not open the PDF itself
(the build machine's network blocked it), so a reader with the book should add the remaining numbers.

The rules live in `game/rules.gd` (pure functions) and `game/court.gd` (the court). The match (`game/match.gd`) calls
them; `tests/test_runner.gd` checks each one (`_rules`, `_footwork`) and sees them work in real play
(`_rules_in_play`, `_matches`). Each section says which test covers it.

## The court and equipment

| Rule | Value | In the game |
|---|---|---|
| Court | 30.5 × 15.25 m, lines 50 mm and part of the court | `Court.LENGTH`, `WIDTH`, `LINE_W`; drawn to measure (`game/arena.gd`) |
| Thirds | Two transverse lines: three equal thirds (10.17 m) | `Court.THIRD_X` |
| Centre circle | 0.9 m across, in the middle | `Court.CENTRE_R` |
| Goal circle | A semicircle of 4.9 m radius on the goal line's middle | `Court.CIRCLE_R`, `in_circle` |
| Goal post | 3.05 m, at the goal line's middle, no backboard | `Court.RING_H` |
| Ring | 380 mm inside, on a 150 mm arm, net open at both ends | `RING_R`, `RING_OUT` |
| Ball | Size 5, 690-710 mm round, 400-450 g | `Ball.R` (0.112 m radius) |
| Run-off | 3.05 m clear round the court (international) | `Court.RUNOFF` |

Sources: https://netball.sport/game/facilities-and-equipment/ ; https://en.wikipedia.org/wiki/Rules_of_netball.
Test: `_rules` ("court 30.5 x 15.25 m", "the circle's edge at 4.9 m" ...).

## Teams and positions (R3)

Seven a side: GS, GA, WA, C, WD, GD, GK, each wearing her position's letters front and back, each kept to her areas
(numbered from the end her team attacks: 1 the attacking circle, 2 the rest of the attacking third, 3 the centre
third, 4 the rest of the defending third, 5 the defending circle):

| Position | Areas |
|---|---|
| GS Goal Shooter | 1, 2 |
| GA Goal Attack | 1, 2, 3 |
| WA Wing Attack | 2, 3 |
| C Centre | 2, 3, 4 |
| WD Wing Defence | 3, 4 |
| GD Goal Defence | 3, 4, 5 |
| GK Goal Keeper | 4, 5 |

- In the game: `Rules.AREAS`, `may_enter`; the bibs carry the letters (`game/body.gd`, from
  `assets/ui/bib_letters.png`). How to Play shows each position's areas on a little court.
- A squad of up to twelve; at least five on court (`Rules.MIN_PLAYERS`, `enough_players`). The game's squads have
  twelve: seven starters and five on the bench.
- Substitutions and team changes are unlimited, at an interval, during a stoppage for injury or illness, and (since
  2024) straight after a goal if an on-court player asks. **In the game:** team changes at every interval (the break
  screen), during an injury stoppage, at a time-out, and at any time with the Rolling changes option. *Simplified:* the
  2024 after-goal tactical change on request is not offered separately (PROGRESS.md "Next").
- Test: `_rules` ("GS may enter area 1" ... "GK is offside in area 3"), 35 checks.
- Source: https://israelnetball.org.il/en/what-s-netball.html (the numbering), the rulebook.

## Offside

A player who enters an area her position may not, with or without the ball, is offside: a free pass to the other
team where it happened. Landing is what counts (in the air above an area is not offside). A foot on a line is in the
area the line bounds, so a GS with a toe on the transverse line is in the centre third.

- In the game: `Rules.offside` on the player's foot each frame; called when she **steps** into the area
  (`Match._check_offside`). The AI's players keep to their areas: they pull up at a line as a player does
  (`Player._room_along`, the "fence"). Your player does too while **Keep me onside** is on (Settings); with it off,
  step over a line and the umpire calls it. A few AI mistakes are made on purpose (`TeamAI._slips`).
- Two players of opposite teams offside together: a simultaneous infringement (below).
- Tests: `_rules` ("GS on the transverse line: offside", "WA on the circle's line: offside" ...); `_rules_in_play`
  ("offside called, a free pass to the other side").

## The centre pass (R8)

- Every quarter starts with a centre pass, and so does play after every goal. They **alternate** between the teams
  whoever scored. The team that wins the umpires' toss takes the first (or chooses the end).
- Before the whistle the C taking it stands with at least one foot wholly inside the centre circle; the other C is
  anywhere in the centre third; everyone else is in her own goal third, free to move there. Entering the centre third
  early is "breaking": a free pass.
- After the whistle the C passes within three seconds. The pass must be caught or touched in the centre third, by a
  player standing wholly in it or whose first landing foot is wholly in it: otherwise a free pass to the other team.
- 2024: any on-court player may ask the umpire whose centre pass it is, before it is taken.
- In the game: `Rules.centre_pass_team`, `centre_setup_faults`, `centre_pass_ok`; the AI lines up in its thirds
  (`TeamAI.place_centre`); the scoreboard's arrow shows whose centre pass is next (it answers the 2024 question at a
  glance). *Simplified:* the C's foot in the circle and the others' thirds before the whistle are checked by the
  rules module but the AI never breaks, and your player waits on her spot until the whistle.
- Tests: `_rules` (alternation, line-up, breaking, the catch); `_rules_in_play` ("centre passes alternate after each
  goal").

## Playing the ball, footwork and the three seconds

- **Three seconds**: a player with the ball must pass or shoot within three seconds: "held ball", a free pass.
  `Rules.held_ball`; the HUD shows the three seconds running out round the ball. Test: `_rules_in_play` ("held ball
  after three seconds").
- **Footwork**: landing on one foot, she may step with the other and pivot on the landing foot; once she lifts the
  landing foot she must release the ball before it touches the ground again. Landing on both, she chooses which is the
  landing foot. No dragging or sliding the landing foot, no hopping, no jumping from both feet and landing on both
  with the ball: a free pass. `Rules.Footwork` (a small state machine). In play, the player with the ball cannot run
  (your stick turns her); the AI's footwork faults come at a real rate (`_slips`). Test: `_footwork`.
- **Short pass (R12)**: there must be room for an opponent to deflect or intercept between the thrower's and the
  catcher's hands (the 2024 wording; before 2024, "room for a third player"). `Rules.short_pass` (0.9 m). Test:
  `_rules`.
- **Over a third**: the ball may not cross a whole third without being caught or touched by a player in it: a free
  pass where it crossed the second line. `Rules.over_third`; the AI never tries it; your pass can. Test: `_rules`.
- **Replayed ball**: she may not catch her own throw before another player (or the goal post) has touched it.
  `Rules.replayed_ball`. *Simplified:* the game's passes always go to a team-mate, so it cannot happen in play; the
  rule is in the module and tested.
- Not in the game because the game's players never do them: striking with a fist, kicking, rolling the ball to a
  team-mate, falling with it, throwing from the ground, using the post for support.

## Obstruction (R13) and contact (R16)

- **Obstruction**: a defender trying to intercept, deflect or defend the player with the ball must have at least
  0.9 m on the ground between her nearer foot and the attacker's landing foot. Closer without defending is fine; she
  may jump from 0.9 m and land closer if she did not leap toward the attacker. A penalty pass. Obstruction of a player
  without the ball (arms out to block her movement) and intimidation are penalised too.
  In the game: `Rules.obstruction`; the AI's defenders defend from 0.9 m (a little more on the lower levels); your
  DEFEND inside 0.9 m is called (the umpire sees most of them), and the HUD rings the landing foot green or red.
  Tests: `_rules`; `_rules_in_play` ("obstruction from 0.6 m: penalty pass").
- **Contact (2024: "interference" and "causing contact")**: no contact that interferes with an opponent's play:
  pushing, tripping, holding, charging, a hand on the ball she holds, not giving a player who has won the ball in the
  air room to land. Incidental contact that does not affect play is not penalised. A penalty pass.
  In the game: `Rules.contact`; contact comes from a defender's challenge on a pass (`cut_result` "contact"), your
  lunge at a player holding the ball (INTERCEPT on the holder), and the AI's real-rate slips.

## Free pass, penalty pass, penalty pass or shot, throw-in, advantage

- **Free pass**: for minor infringements (offside, breaking, held ball, footwork, short pass, over a third, replayed
  ball, a centre pass fault), taken where the infringement was by any player allowed there. A free pass in the
  attacking circle may not be shot. `Rules.INFRINGEMENTS`, `award`, `takers`; `from_free` stops the shot.
- **Penalty pass**: for obstruction, contact, intimidation; taken where the infringer stood. The **penalised player
  stands out of play beside the thrower** until the ball is released (2024: unless she has been suspended or ordered
  off). In the game she walks to the thrower's side and stands still with her arms down (`Poses.out_of_play`).
  Test: `_rules_in_play` ("the penalised player is out of play until the pass").
- **Penalty pass or shot**: a penalty in the goal circle the fouled team attacks, taken by its GS or GA, may be a
  pass or a shot. `award` sets `shot`. Test: `_rules`.
- **Simultaneous infringement (2024: no more toss-up)**: when players of both teams infringe together, the team last
  in possession keeps the ball, where it was. `Rules.simultaneous`. The toss-up is not in the game because the 2024
  rules removed it. Test: `_rules`. Source: https://netballhamilton.org.nz/media/1731/toss-up-removal-pdf.pdf
- **Out of court and the throw-in**: the ball is out when it touches the ground (or anything) outside the court; the
  team that did not touch it last throws it in from where it crossed the line, standing outside with a foot within
  15 cm of the line, within three seconds. Since 2024 she need not wait for players to be back on court.
  `Rules.throw_in`, `throw_in_spot`. Test: `_rules`. Source:
  https://netball.sport/wp-content/uploads/2024/01/Throw-In-PDF.pdf
- **Advantage (R7)**: the umpire plays on when stopping would cost the fouled team, calling "Advantage" and the
  infringement. In the game: a penalty against the defence while the attacking team's shooter has the ball in her
  circle is played as advantage more often than not (`Match._infringe`); the HUD shows "Advantage" and the call.

## Scoring (R9)

A goal is scored when the ball goes over and right through the ring from a shot by GS or GA from anywhere in the goal
circle (its line included), not from a free pass. A defender's touch does not stop it counting. Every goal is worth
one. 2024: a shot that has left the shooter's hands before the whistle ending a period counts if it goes in.

- In the game: `Rules.may_shoot`, `goal_value`, `goal_counts`; the shot's chance follows the distance from the post,
  the shooter's skill and a defender's arm over the ball (`Match.shot_chance`); a shot in the air when time runs out
  is let land (`_end_period` waits for it).
- Tests: `_rules` ("GS and GA shoot from the circle", "nobody else may", "a free pass in the circle may not be shot"
  ...); `_matches` ("only GS and GA score").
- Source: https://netball.sport/wp-content/uploads/2024/01/Goal-After-Whistle-PDF.pdf

## Time, intervals, extra time (and R10 stoppages)

- Four quarters of **15 minutes**; intervals of **4 minutes** after the first and third quarters and **12 minutes** at
  half-time (8 if both teams and the organiser agree). The teams change ends every quarter.
- When a match needs a winner and is level: **extra time of two halves of not more than 7 minutes**, with **1
  minute** between them (the teams change ends), then **play goes on until one team leads by two goals**.
- Time is held only for stoppages (R10): injury or illness (the player off within **30 seconds**), blood (a bleeding
  player must leave; dry blood no longer has to, 2024), an emergency, foul play.
- In the game: `Rules.period_length`, `interval_after`, `ends_for_quarter`, `next_period`, `match_over`. The clock
  runs on through goals and restarts, as the real one does; the break screen shows the interval's real length, and
  Continue skips it. *Simplified:* quarters default to **5 minutes** for a phone session (8, 10 and the real 15 on
  offer, Quick Match > Quarters; extra time scales with them: 7 of 15). **Injury stoppages**: now and then a contact
  hurts a player; the umpire holds time (the T signal) and the team has 30 seconds to help her off, both teams free to
  make changes (the AI replaces its injured player when the bench has one for the position). Blood is treated the same.
  Test: `_sanctions_and_injury` ("time is held for the injury").
- Tests: `_rules` (intervals, extra time, ends, "until a team leads by two"); `_matches` ("a knockout has a winner").
- Sources: the rulebook; https://www.bucs.org.uk/rules-and-regulations/sport/netball.html (extra time as played).

## Sanctions (R6)

2024: the umpires' ladder is proactive advice, warning, **suspension** (two minutes of playing time, the team a
player short), **ordering off** (no further part; since 2024 she may be replaced after four minutes of playing time).
Cautions are gone. Umpires may also **advance** a pass up to half a third or **escalate** a free pass to a penalty
pass. In the game (`Match._sanction`, `suspend`): a player is **warned** at her fourth penalty-pass infringement
since her last sanction, and **suspended** at the third after a warning: she walks to her bench and her team plays a
player short for two minutes of playing time (the clock held through stoppages does not count), then she comes back
on to her own area, walking round the outside of the court; no one stands out of play for a penalty she was suspended
for. The HUD shows each warning and suspension. *Simplified:* ordering off (`ORDERED_OFF_REPLACE`, 4 minutes) and
the advance and escalate options are in the module but the umpires do not use them: the game's players commit no
dangerous play. Test: `_sanctions_and_injury`. Source:
https://netball.sport/wp-content/uploads/2024/01/Game-Management-PDF.pdf

## The officials (R4)

Two umpires. Each controls one half of the court, divided by the centre line across it: one goal third and half the
centre third, with one side line and one goal line, and keeps it all match. For each decision: whistle, call, signal
the infringement, point the award's direction (and, for a penalty, where the infringer stands).

In the game (`game/umpire.gd`): each umpire walks her side line level with play in her half, outside the court; the
umpire whose half it is in makes the call (`Umpire.controls`), blows, and signals, then points the direction
(`Poses.umpire_signal`), while the HUD shows the call, the award and to whom. The signals drawn, after World Netball's
official signals (reference copies: https://thenetballumpire.com/rules/hand-signals/ ;
https://nsw.netball.com.au/sites/nsw/files/2022-10/HandSignals.pdf):

| Decision | Signal |
|---|---|
| Held ball | Arm straight up |
| Footwork | Hands palms down, rolling past each other |
| Short pass | Hands a short way apart, one moving to the other |
| Obstruction | Hands palms in, a short way apart, in front |
| Contact | One hand tapping the other forearm |
| Over a third | An arm sweeping up in an arc in the ball's direction |
| Offside, breaking, throw-in | An arm angled down to the line or area |
| Penalty | The arm pointing down beside the thrower (out of play) |
| Direction of award | The arm out level toward the team's attacking goal |
| Goal | The arm raised |

*Simplified:* the finger detail (three fingers for held ball) is too small to draw on the code-built hands.

## Variants: the leagues' rules, as options

Real leagues change a few rules. The game offers them under its own names, never the leagues' or their trademarks:

| Game option | What it is | Who plays it (facts, October 2026) |
|---|---|---|
| **Double Zone** (Quick Match setting) | In the last five minutes of each quarter (and of extra time), a goal from the outer zone of the circle, 3.0 to 4.9 m from the post, counts two | Australia's top league since 2020 (its "Super Shot", 3.0-4.9 m, the last 5 minutes of each quarter); England's top league since 2025 (last 5 minutes, about 3 m); New Zealand's since 2025 (3.5 m and out, last 5 minutes) |
| **Rolling changes** (Quick Match setting) | Team changes at any time (in the game, from the pause menu) | Australia's top league |
| **Time-outs** (Quick Match setting) | 90-second team time-outs after a goal, time held; the game gives two a team each half and resets them at half-time; the AI calls one now and then when four or more behind | Australia: two a team each half; England: one a team a match; New Zealand: one a team each half |

Sources: https://netball.com.au/sites/netballnation/files/2025-12/2026%20SSN%20&%20SN%20Reserves%20Rules%20of%20the%20Game%20FINAL.pdf ;
https://www.netballsl.com/learn-the-game/ ; https://www.rnz.co.nz/news/sport/544090/ ;
https://www.skysports.com/netball/news/12415/13267746/

In the game: time-outs in `Match.call_timeout` (`Rules.TIMEOUT_LEN`, `TIMEOUTS_PER_HALF`; test `_league_options`), rolling changes in the pause menu (`HUD._rolling_changes`); the Double Zone in `Rules.DZ_FROM`, `DZ_LAST`, `goal_value`, `double_zone_live`; the scoreboard says DOUBLE ZONE while it is
live and a two-point goal is called as one. Shorter quarters scale the window (its last third). The AI's GA takes a
long two now and then. Test: `_rules` ("the Double Zone: two from 3.5 m ..."). Fast5 (five a side, 6-minute quarters,
1-2-3 point shots) is a different game and not offered.

**Men's and mixed netball** play the same rules; mixed competitions only limit line-ups (typically at most three men
on court, one per third). The game is women's netball, as the sport mostly is; mixed could come later
(https://netball.sport/wp-content/uploads/2024/02/WN-Position-Statement-Male-Participation.pdf).

## Competitions

The **Nations Cup** is the game's own competition (no real competition's name): eight nations near yours in the
ranking, two pools of four (seeded 1-4-5-8 and 2-3-6-7) played round robin, the top two of each to the semi-finals,
then the bronze-medal match and the final, as world championships finish. Two points for a win and one for a draw;
level teams are split by **goal percentage** (goals for ÷ goals against × 100), as netball tables are. Knockout matches
go to extra time. `game/cup.gd`; test `_cup`. The real world championship has 16 teams, two group stages and play-offs
(2023), and adds Cup and Plate competitions in 2027
(https://netball.sport/wp-content/uploads/2025/06/World-Netball-Introduces-Cup-and-Plate-Competitions-to-Netball-World-Cup-2027-Final.pdf).

## How the AI plays: the numbers

The AI (`game/ai.gd`) plays the positions as they are played: attackers lead into space and hold it, the GS works
round the post and the GA at the circle's edge, the WA wide and in the pocket by the circle, the C in support;
defenders mark their opposite number goal-side, a beat late, and defend the ball from 0.9 m; the centre pass goes to
the GA or WA driving into the centre third (C to GA to WA to GS is the commonest sequence). It is tuned to these real
numbers:

| Number | Real value | Source |
|---|---|---|
| Goals a team, 60 minutes, equal sides | 50-65 | Hersant & Oates 2024, https://www.tandfonline.com/doi/full/10.1080/24748668.2024.2350282 |
| Mismatches | up to 101-32 (world championship 2023) | https://netballscoop.com/2023-netball-world-cup-team-stats/ |
| Centre pass to goal | about 75% (top internationals), 72% (Australia's league), best team about 80% | Davies & Webb 2025, https://www.tandfonline.com/doi/full/10.1080/24748668.2025.2537473 ; https://netballscoop.com/netball-scoop-2025-ssn-grand-final-preview/ |
| Shooting | GS about 86% on 34 shots a match, GA about 77% on 16.5 | https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2021.743612 |
| Gains a team a match | 9-12.5 | Netball Scoop 2025 |
| Turnovers a team a match | 15-17 | Netball Scoop 2025 |
| Penalties a team a match | 50-58 | Netball Scoop 2025 |
| Commonest centre pass sequence | C → GA → WA → GS | https://reference-global.com/article/10.2478/ijcss-2019-0004 |
| Time on the ball | under three seconds; the game's AI passes after 0.3-1.2 s, sooner the better its passing | design assumption |
| Possessions a team | about 75-90 in 60 minutes | derived (one centre pass a goal, plus turnovers) |

**Choices against the real numbers**: the AI gives away penalties at about a third of the real rate (one every
70 seconds or so a team rather than one every 65 seconds of play), so a match is not mostly whistles; the rate is in
`TeamAI._slips` and can be raised. Shot chance: about 95% under the post, 87% at 2.5 m, 62% at the circle's edge for
an 85-rated shooter, up to an eighth off with a defender's arm over the ball (`Match.shot_chance`).
