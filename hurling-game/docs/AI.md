# How the computer plays hurling

The AI (`game/team_ai.gd`, with the match's own loose-ball and tackle logic in `game/match.gd`) plays the game as it
is played at senior inter-county level. This is what it does and the numbers it is built on.

## The numbers it is tuned to

From the GAA's Games Intelligence Unit, sports-science papers and match analysis (2023-2026):

| What | Real hurling | Source |
|---|---|---|
| Shots a game (both sides) | about 77, 60.2% scored | GIU 2026 season analysis, https://www.gaa.ie/article/games-intelligence-unit-s-2026-season-analysis-gives-hurling-a-baseline ; https://www.irishexaminer.com/sport/gaa/arid-41923912.html |
| Conversion | 54.9% from play, 74.6% from placed balls | same |
| Where shots come from | mostly 20-45 m ("the D inwards"); about 10% from a side's own half | same; https://www.gaa.ie/hurling/news/2023-allianz-hurling-league-statistics-paint-a-revealing-picture |
| Goals and points | 2.5-3 goals and about 42 points a game (both sides) | 2019 and 2025 championships, https://www.southernstar.ie/sport/denis-hurley-column-cork-hurlers-have-potential-to-become-a-goal-scoring-team-again-4204561 |
| Scores from play | about 65% | 2023 league statistics (above) |
| Frees | about 26 a game | GIU 2026 |
| The free-taker | takes 86-87% of his side's placed balls | https://www.irishtimes.com/sport/gaelic-games/hurling/gaa-statistics-how-peter-duggan-has-transformed-this-clare-team-1.3546048 |
| Sideline cuts at the posts | 18-23% scored | https://www.balls.ie/gaa/stats-strengthen-two-points-sideline-cut-argument-394599 |
| Puck-outs | about 33 a side a game; 37% short, 55% long; long ones kept about half the time | https://www.irishexaminer.com/sport/gaa/arid-41908957.html |
| Players' top speed | 8.4 m/s (30 km/h) | GAA Learning, match-play demands of hurling |
| Distance a game | 7.6 ± 1.2 km; 22 sprints of about 19 m | https://researchonline.ljmu.ac.uk/6310/ ; https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6481817/ |
| A shot's speed | about 120 km/h on average (33 m/s); the record 181 km/h | Smart Sliotar data, research_play notes |
| The sliotar | 110-116 g, 69-72 mm (2022 specification) | https://www.gaa.ie/news/16-sliotar-suppliers-now-compliant-with-official-gaa-specifications/ |
| The referee | 9-9.6 km a game, top speed about 27 km/h | https://statsports.com/article/the-man-in-the-middle |

## What it does

- **Shape.** Each side keeps its lines (goalkeeper; full-backs about 22 m out; half-backs 45 m; midfield at the
  middle; half-forwards and full-forwards 95 and 117 m up), the whole side sliding up and down with the ball, the
  lines tighter when defending, the wings drawn toward the ball's side.
- **Marking.** Man to man by the numbers, as hurling is marked: 2 on 15, 3 on 14, 4 on 13, 5 on 12, 6 on 11, 7 on 10,
  the midfielders on each other. A defender stays goal-side of his man, closer the nearer the ball, and drifts back
  to his zone if his man wanders.
- **Pressing.** The nearest defender closes down the man on the ball from the goal side; inside the defence's own
  45 a second one comes too.
- **The tackle.** Pressers try for the ball about once a second when within reach: a shoulder, a flick off the
  hurley of a soloing man, a hook from behind or a block from in front of a striker. Each can be a foul (more often
  from behind); in their own large rectangle defenders go in more carefully; the cynical pull-down that stops a goal
  is rare (it costs a penalty and the sin bin).
- **The man on the ball** looks again every quarter to half a second, at once when pressed:
  - a **point** when his chance from there (by distance, angle, pressure and his accuracy) is high enough: about
    50% from 60 m out, 40% inside 20 m;
  - a **goal** only when he is inside about 25 m, in front, with no outfield defender within 3.5 m, and then only
    about three times in five (most clear chances are still taken as points);
  - a **pass**: struck long to a free teammate further up (dropping in front of the square, never into the net),
    or hand-passed to one close by when he is pressed, avoiding lanes a defender can cut out;
  - else he **carries** it, bending away from the nearest defender: three steps in the hand, then the solo onto the
    hurley; on the hurley as far as he likes.
- **Support.** The nearest teammate comes to about 6 m off his shoulder for the hand-pass; forwards run into space
  away from their markers.
- **The loose ball.** The sliotar's flight is worked out ahead (with drag and bounces); each side sends the two who
  can reach it first; whoever is nearest when it comes within reach goes for it: a catch in the air, a lift off the
  ground, contested if an opponent is there too (a rival halves the chance; a fumble breaks it loose).
- **Goalkeepers** stand a metre or three off the line between the ball and the goal centre, come for balls dropping
  into their area, dive at shots for goal (a save by their keeping and how far the shot is from them, held or
  parried) and catch points dropping short.
- **Puck-outs**: short to a free corner-back or wing-back about half the time one is free (13 m away at least, as
  the rule wants), else long into the middle third toward a wing.
- **Frees and 65s**: the free-taker strikes for a point when in range; 65s always; from deep in his own half a
  defender strikes it long. **Sideline cuts**: at the posts from close in about half the time, else into a
  teammate.
- **Officials**: the referee follows play on a diagonal behind it at up to 7.2 m/s, the linesmen along their lines,
  the umpires at their posts.

## What the game's matches produce

`tests/match_sim.tscn` plays AI matches headless. At the default length (14 minutes; the clock runs 5× real time in play, 2× while the ball is dead),
matches between the top counties, after tuning (21 October 2026; ten matches across the last two runs):

| | Per match (both sides) |
|---|---|
| Goals | 1.3-2.0 |
| Points | 20-23 |
| Shots | 34-38 |
| Wides | 16-17 |
| Frees | 3.5-4.5 |
| Yellow cards | about 1 |
| Black cards | 0-0.5 |
| Puck-outs | about 37-42 |

Scorelines like 1-11 v 0-7, 0-15 v 0-9, 1-15 v 1-13, 2-11 v 0-17: real hurling's shape (points far outnumber goals, a goal or
two a game), with fewer scores than 70 real minutes since the match is shorter. The play itself runs at real speed:
a full 70-minute match (Settings > Match length > 70 min) produces about the real numbers.

## Next

- Substitutions (five, and three in extra time), with tired players coming off.
- Tactics a manager picks: a sweeper (the extra defender), a two-man full-forward line, short or long puck-outs.
- Umpires who now and then call a close point wrong, and Hawk-Eye at the stadium.
