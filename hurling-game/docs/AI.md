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

**The clock.** A real 70-minute match has the ball in play only about 38% of the time (about 27 minutes; 2023 league
statistics): the rest is puck-outs, frees, sideline cuts, scores, cards and injuries. The game keeps the same share.
While the ball is dead the referee's watch runs in real time, and when the players are set for the restart it is moved
on to what that stoppage costs in a real match (`STOP_COST` in `game/match.gd`: about 20 s for a puck-out, 34 s for a
free, more for a penalty or a card), or to whatever keeps the ball live for 38% of the half so far, whichever is more
(the game has fewer frees than a real match and no injuries). While the ball is live the clock runs fast enough for the
whole match to take the length you picked (`live_clock_k`): 4.4× real time at 8 minutes, 2.6× at 14, 1.8× at 20, and
at 35 minutes about real time (1.08×). So **the 35-minute length is a full 70-minute match**, with the ball in play
about as long as in a real one, and it scores like one. The shorter lengths are the same game with less of it, and
score in proportion.

**The check.** `tests/score_check.tscn` plays two AI matches between top counties at each length and holds them to the
real numbers (it runs in CI). The run of 21 October 2026 (means a match, both sides):

| Length | Real minutes | Ball live (real min) | Goals | Points | Shots | Real hurling for that much play |
|---|---|---|---|---|---|---|
| 8 min | 8.7 | 6.4 | 0.0 | 10.5 | 16.5 | 0.7 goals, 10 points |
| 14 min | 15.7 | 11.3 | 1.0 | 20.0 | 28.5 | 1.2 goals, 18 points |
| 20 min | 22.4 | 16.5 | 3.0 | 24.5 | 43.0 | 1.7 goals, 26 points |
| **35 min (the full 70)** | 36.3 | 27.2 | 2.0 | 41.0 | 60.5 | **2.75 goals, 42 points, 77 shots** |

Full-length scorelines from that run and the tuning runs before it: 2-21 v 2-21, 0-20 v 0-20, 0-21 v 0-24,
0-19 v 4-20, 2-22 v 0-12. Over every match: 1.56 points a live minute (real 1.58), 0.10 goals (real 0.10), 2.4 shots
(real 2.9), 69% of shots scored (real 60%: the game's forwards shoot a little less often and a little better than
real ones). Frees about 17 a full match (real 26), puck-outs about 70 (real 66), 4-7 yellow cards.

The earlier version of this page said a 70-minute match "runs far too high (5-34 v 5-46)": that was the old 70-minute
length, which ran the clock at real time through every stoppage too, so the ball was live for about twice as long as in
a real match. It is gone; the 35-minute length replaces it.

## Next

- A few more shots and a few more misses (real 77 shots and 60% scored, the game's about 60 and 69%); more frees
  (real 26 a game) and sideline cuts (the ball rarely goes out over the sideline).
- Substitutions (five, and three in extra time), with tired players coming off.
- Tactics a manager picks: a sweeper (the extra defender), a two-man full-forward line, short or long puck-outs.
- Umpires who now and then call a close point wrong, and Hawk-Eye at the stadium.
