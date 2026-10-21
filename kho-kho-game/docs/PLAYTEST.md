# The phone playtest (0.2)

Before 0.2 the game was played as a tester plays it on a phone: the Web build in Chromium, through touch alone, in
landscape, on Low graphics. This page is what was found and what was done about it, worst first.

## How it was played

- **The build:** `godot --headless --path . --export-release "Web" build/web/index.html`, served on
  127.0.0.1:8060, opened with `?playtest&gfx=0` (Low).
- **The tester:** `tools/playtest/play.js`, Playwright driving the pre-installed Chromium with touch emulation on
  (`hasTouch`, `isMobile`) and touches sent through the DevTools protocol (`Input.dispatchTouchEvent`), so the game
  sees a touch screen, not a mouse. It plays from the home screen: Quick Match, the rules, the toss, then the turns
  — chasing it runs at a defender it may touch or up behind the next seated chaser and presses KHO and DIVE;
  defending it runs its defender away from the chaser, toward his back, and keeps off the lines. It taps "Got it"
  on the coach's cards and "Next turn" at the intervals, and takes a picture every 12 s and at every change.
- **What it reads:** with `?playtest` in the address the game publishes what is on its screen as
  `window.khoState` (`game/playtest.gd`): the screen, every button and where it is, and in a match the phase, the
  clock and score, the active chaser, your defender, the kho you can give, the defenders and the touch buttons, in
  the page's pixels. It reads the game and never changes it, and exists only in a browser build opened with the
  flag.
- **The runs:**

| Run | Screen | Rules | You | What was played |
|---|---|---|---|---|
| A | 1280 × 720 | Classic | chase, then defend | two full turns (3-minute turns), from the home screen through the toss, the coach's cards and the interval |
| B | 1600 × 720 (20:9) | Fast | defend, then chase | two full turns, the power play and dream run on |
| C | 2400 × 1080 | Classic | — | every menu: home, setup, toss, How to Play, Settings, championships and the City League |

The container draws with software GL (SwiftShader), so the game runs at about a third of real time there and its
frame rates are not a phone's. Frame rates on phones come from `tests/perf_probe.gd`'s draw-call and triangle
budgets instead (README).

## What was found, worst first, and what was done

1. **Defending, your batch was out for a late entry, batch after batch (53-2 in one turn).** While a new batch
   walked on, a thumb held on the stick took the walking-on defender over; steered anywhere but onto the field he
   never came in, and the classic rule put him out at the next kho. With the old batch out quickly too, the AI
   scored 53 in three minutes against 2 the other way. **Fixed:** walking on is the defender's own; the stick
   takes him once he is in (`match.gd _user_defender`). Test: *a new batch walks on even with your thumb held away
   from the field*.
2. **Defending, your defenders ran out of limits.** Run B (fast rules, defending first) lost 34 defenders in under
   three minutes of play, most of them "out of limits": fleeing the chaser with the stick, the tester's defender ran
   over the side line, and with the low camera angle a phone player does the same. The AI's defenders pull up at the
   line (`_keep_in`, from their stopping distance); yours did not. **Fixed:** with the assist on (Settings > Lane
   assist, on by default) your defender pulls up at the line too: his speed toward the line is braked at his full
   braking as soon as he needs it all to stop inside (`_brake_at_line`; a turn of the stick alone spent his grip on
   turning and carried him over). Off, the line is yours to watch. Test: *your defender held at the side line pulls
   up inside it*.

   Measured in `tests/match_sim.gd ... bot`, which steers your defender as the tester does, defenders your side
   lost a minute of defending:

   | | Before (0.1) | After (0.2) | Real matches |
   |---|---|---|---|
   | Fast rules | ~8, three in four out of limits | 1.3-2.2, a few out of limits | 1.3-1.6 |
   | Classic rules | ~7.7, most out of limits | 0.7-1.5, none out of limits | 1.3-1.6 |
3. **Defending, the defender you steer had no reflexes.** The AI's defenders slip a touch about 70% of the time
   (their turn against the chaser's reach); yours never did, and stood still when your thumb was off the stick.
   **Fixed:** with your thumb off the stick for half a second he runs as the AI would (the stick takes him back at
   once), and steered, a touch can still slip off him, at three-quarters of the AI's rate, with DODGE yours on
   top. Tests: *thumb off the stick for half a second: your defender runs himself*, *the stick takes him back at
   once*.
4. **Chasing, a push into the lane crawled.** The lane assist cancelled the push across the lane and left the
   chaser at about 2 m/s. **Fixed:** a push at the lane becomes a run along it at full speed, his way. Test: *the
   push at the lane runs along it, over 5 m/s*.
5. **Chasing, KHO at full speed was a 0.3 s window.** Pressed a moment early, nothing happened; a moment late, it
   was a late kho. **Fixed:** KHO pressed up to 3.5 m before the seated chaser arms the kho: his square lights, KHO
   stays lit, your chaser slows into his back and gives it. Test: *KHO pressed 3 m early at full speed gives the
   kho, no foul*.
6. **Chasing, a push the wrong way did nothing and said nothing.** **Fixed:** a gold arrow under your chaser shows
   the way he must keep; a coach tip explains it the first time.
7. **The AI's defenders hid at the far side line,** so the AI chasers ran the length of the field and khos were
   rare. **Fixed:** defenders now play the chain, as in real matches: close to the lane, beside a seated chaser
   facing away (`_chain_bias`). Khos rose to about 13 a minute, outs stayed at about 1.75 a minute (docs/AI.md).
8. **A first-time player was not told how to play.** **Added:** coach tips in all fourteen languages. The first
   turn chasing and the first turn defending stop on a card until "Got it"; the kho, the arrow, the touch and the
   dive, and a foul each get a short tip at the moment they matter. On until your first match is finished, and in
   Settings to turn on again.
9. **A touch screen was shown keyboard hints** ("Space", "J", "K") and a missing glyph on the buttons. **Fixed:**
   the hints show only without a touch screen.
10. **Low graphics:** the chalk lines broke into dashes at a distance and the ground was too dark. **Fixed:** wider
   lines (9 cm) and more ambient light on Low.
11. **The foul rule was wrong:** a turning-back foul cleared after 0.8 m the proper way. The re-check of the rules
    (docs/RULES.md) found it stands until a kho or the free zone. **Fixed**, with tests.
12. **Punjab played in the City League.** The menu tour at 2400 × 1080 found Punjab among the city sides: Pune's
    code was Punjab's (PUN). **Fixed:** Pune is PNE; a test checks every side's code is its own and that every
    league side is a city.
13. **The near umpire is large in the broadcast camera** when the play is on the near side line. Left as it is: he
    stands where a real umpire stands, and the camera keeps the play in view.

## What was looked at and found right

- **Buttons** sit under the thumbs at all three screen shapes: the joystick anywhere on the left, KHO or DODGE in
  the bottom right corner with DIVE or SWITCH inside it; none is covered by the scoreboard or the batch panel, and
  the coach's card sits under the scoreboard, clear of both thumbs.
- **The camera** keeps the active chaser and the defenders near him in view through a full turn, the pole turns
  included.
- **The menus** fit at 1280 × 720, 1600 × 720 and 2400 × 1080: nothing cut off, nothing off the screen.
- **The coach's cards** fit three lines in every language (`tests/fit_audit.gd` checks each tip).

## Doing it again

```
cd kho-kho-game
godot --headless --path . --export-release "Web" build/web/index.html
npx http-server build/web -p 8060 -s &
NODE_PATH=/opt/node-tools/node_modules node tools/playtest/play.js /tmp/pt 1280x720 classic chase 2
```

The pictures and a log land in the folder given. The tester is not a good player (it chases straight at the
nearest defender and defends by running away), which is the point: it plays as someone new to the game would.
