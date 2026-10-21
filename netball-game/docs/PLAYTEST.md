# Playtest: the Web build, played by touch as a first-timer would

Round two of the beta (October 2026). The Web export was played in Chromium (Playwright, touch emulation, landscape,
graphics Low) at three phone shapes: **1280 × 720** (16:9), **1600 × 720** (20:9) and **2400 × 1080** (20:9, a
large phone). Every screen was screenshotted and looked at; whole matches were played through the real touch
controls (stick, Pass, Shoot, Defend, Intercept, Switch) with short test quarters (`?qs=25`), in Quick Match, the
Nations Cup and the Club Season. The harness is `tools/playtest/play.js`; it reads the match state from a small
bridge the Web build exposes only in test runs (`?qs=`).

Findings, worst first, with what was done about each. "Test" names the automated check added so it cannot come back.

## What was wrong

| # | Severity | What the tester saw | Fixed by | Test |
|---|---|---|---|---|
| 1 | Blocker | **No pause button** in a match at any shape: it was placed from the HUD's size before the HUD had one, so it sat off screen. No way to pause, change buttons or quit a match by touch. | Anchored to the top right inside the safe area (`HUD._place_pause`). | `controls_only` checks the button is on screen and opens the pause menu |
| 2 | Major | **A first-timer cannot tell what to do.** Playing as a new player would (move, tap the big button), the tester's team scored 0 in a whole match: nothing says what the lime ring, the dashed ring, the red/green ring or the buttons mean. | The **coach** (`game/coach.gd`): a short tip the first time each thing is needed (move, pass, shoot, footwork, defend, intercept, a whistle, the areas), on for a first match, off after it, switch in Settings. | `_coach` |
| 3 | Major | **Back / Esc** did nothing in the browser; with the language list open, Android's Back quit the game. | `Game._unhandled_input` routes Esc to Back; the home screen's Back closes the language list first. | `controls_only` |
| 4 | Major | **Language list ran off the screen** at 2400 × 1080 (cards cut at the right, two names clipped), and the fit audit missed it: it skipped boxes laid out together. | The list shrinks long names and keeps its card on screen; the check mark moved to the card's corner. The fit audit now also reports any box that leaves the screen (`outside_box`). | fit audit, every language, four shapes |
| 5 | Major | **Your pass target flickered** between two team-mates every frame (a random term in the AI's choice), and the auto-pick often chose a pass the GK could reach: the tester's long lobs to the GS were intercepted again and again. | The user's target has no noise, sticks unless another is clearly better, and counts a defender's reach against a pass four times more than the AI does. | `_controls` (a scripted thumb passes, scores, and is rarely called for held ball) |
| 6 | Minor | **Keyboard hints on a touch screen**: "␣", "J", "K" under the buttons, the first drawn as a missing glyph on the Web. | Hints only when there is a keyboard and no touch screen; "Space" spelled out. | `controls_only` |
| 7 | Minor | **Interval screen half empty**: the left panel had two rows of scores and nothing else; the team-change buttons said who plays each position but not who would come on. | The teams' figures (goals/attempts, %, feeds, gains, intercepts, penalties, turnovers) under the score; each change button reads "GS  Name  ›  Bench name", greyed when no one on the bench plays it. | `_break_screen`; fit audit `match_break` |
| 8 | Minor | **Name tags printed over each other** when a defender stood on her player ("GSK", "GD/D", "WDWA"). | Overlapping tags stack, the one nearer the camera keeping its place (`HUD.declutter`). | `_tags` |
| 9 | Cosmetic | **Home screen**: the goal-circle line of the Nations Cup and How to Play thirds ran straight through their titles and text on wide phones. | Drawn faint (a third of the line's strength). | screenshot |
| 10 | Cosmetic | The licences page crashed the engine in headless test runs (a threaded text layout freed mid-layout); not seen by players, but it stopped CI runs at random. | No threaded layout in headless runs. | `_screens` |

## What the tester liked, and left alone

- The centre pass, the umpire's call banner ("Obstruction · Penalty pass to Jamaica") and the signals read clearly.
- The scoreboard, the three-second ring over the ball and the 0.9 m ring under a defender are easy to read at all
  three shapes.
- The AI v AI match behind the home screen is off on Low graphics: by design, to save battery on budget phones.

## Second pass (0.2.0-beta)

The fixes above, then the coach and the Club Season, were played again from a fresh start (`?fresh`, so the coach is
on): a Quick Match at 1280 × 720, the screen tour at 1280 × 720, and a Club Season match at 2400 × 1080 through to
the table after it.

| # | Severity | What the tester saw | Fixed by | Test |
|---|---|---|---|---|
| 11 | Major | **Esc on the home screen froze the page** in a browser: Back there quits, and quitting stops the engine on the Web. | Back on the home screen quits only on a phone (`MainMenu.quits_on_back`). | screenshot run (the tour now closes the language list with Esc and goes on) |
| 12 | Cosmetic | A table before any match showed a goal percentage of 0. | A dash until a team has played (Nations Cup and Club Season). | screenshot |
| 13 | (harness) | The match's test bridge could overwrite the result screen's report in the frame the match was freed. | The bridge reports only while the match is the current screen. | the league run reaches the result |

Confirmed working:

- **The coach** opens with how to move, then on the first loose ball "They have the ball…", then passing, shooting and
  the rest, each once, in a box between the stick and the buttons; it never covers the buttons at any shape.
- **The interval**: each team's figures, and "GS  Hannah Rowe  ›  Isla Osborne" on each change button.
- **Name tags** stack above a defender and her player instead of printing over each other.
- **The Club Season**: pick a club (crests in club colours, home country under the name), the hub with Play and
  Simulate, a match in the sports hall with the clubs' crests on the scoreboard, the result, then the table and the
  round's results. A 0–0 test match (25-second quarters) was recorded as a draw, one point each.
- The home screen's two competitions, one above the other in the left third, read clearly at every shape.

Left as they are:

- The tester's scripted thumb scored few goals in 25-second quarters: a quarter that short holds two or three
  passages of play. The scripted thumb in `_controls` (90 seconds) does score.
- The result screen's box score starts just above the buttons; it scrolls (the bar shows), as it did in 0.1.
